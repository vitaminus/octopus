require 'capybara'
require 'capybara/poltergeist'
require 'capybara/dsl'
require 'json'

module Octopus  
  class United
    include Capybara::DSL
    Capybara.register_driver :poltergeist do |app|
      Capybara::Poltergeist::Driver.new(app, window_size: [1920, 1080], timeout: 20, js_errors: false)
    end
    Capybara.default_driver = :poltergeist
    Capybara.default_max_wait_time = 25

    attr_reader :from, :to, :departure
    def initialize(from, to, departure)
      @from    = from.upcase
      @to = to.upcase
      @departure = departure
    end

    def get_data
      t = Time.now
      data = []
      begin
        visit "https://www.united.com/ual/en/us/flight-search/book-a-flight/results/awd?f=#{@from}&t=#{@to}&d=#{@departure}&tt=1&st=bestmatches&at=1&cbm=-1&cbm2=-1&sc=7&px=1&taxng=1&idx=1"
        page.find('.language-region-change').click if page.all('.language-region-change').size > 0
        page.find('.flight-result-list')
        # puts page.all('.col-header-content')[1].text
        sleep 1.5
        # page.save_screenshot('error.png')
        page.all('.col-header-content')[1].trigger('click')
        sleep 2
        page.all('.flight-block.flight-block-fares').each do |fare|
          if fare.all('#product_BUSINESS-SURPLUS').size > 0
            depart_date = fare.find('.flight-time.flight-time-depart .date-duration').text if fare.all('.flight-time.flight-time-depart .date-duration').size > 0
            depart_time = fare.find('.flight-time.flight-time-depart').text.scan(/(\d+:\d+ am)|(\d+:\d+ pm)/).flatten.compact.first
            origin = fare.find('.airport-code.origin-airport-mismatch-code').text if fare.all('.airport-code.origin-airport-mismatch-code').size > 0
            arrive_date = fare.find('.flight-time.flight-time-arrive .date-duration').text if fare.all('.flight-time.flight-time-arrive .date-duration').size > 0
            arrive_time = fare.find('.flight-time.flight-time-arrive').text.scan(/(\d+:\d+ am)|(\d+:\d+ pm)/).flatten.compact.first
            destination = fare.find('.airport-code.destination-airport-mismatch-code').text if fare.all('.airport-code.destination-airport-mismatch-code').size > 0
            duration = fare.find('.flight-duration.otp-tooltip-trigger').text
            stops = fare.find('.connection-count').text
            sleep 0.5
            fare.find('.toggle-flight-block-details').click
             
            if stops == 'Nonstop'
              airline = fare.all('.carrier-icon')[0]['title']
              # orig_dist = fare.all('.segment-orig-dest')[0].text
              equipment = fare.all('.segment-flight-equipment')[0].text
              flight_number = equipment.scan(/([A-Z]+ \d+)/).flatten.compact.first
              aircraft = equipment.gsub(/([A-Z]+ \d+ \| )/, '')
              first_segment =
                {
                  airline: airline,
                  flight_number: flight_number,
                  departs:
                    {
                      date: depart_date,
                      time: depart_time,
                      airport: origin,
                    },
                  arrives:
                    {
                      date: arrive_date,
                      time: arrive_time,
                      airport: destination,
                    },
                  cabin: nil,
                  bookclass: nil,
                  aircraft: aircraft,
                  duration: duration
                }
            else
              first_segment_times = fare.all('.segment-times')[0].text
              first_depart_time = first_segment_times.scan(/(\d+:\d+ am|\d+:\d+ pm)/).flatten.compact.first
              first_arrive_time = first_segment_times.scan(/(\d+:\d+ am|\d+:\d+ pm)/).flatten.compact.last
              segment_orig_dest = fare.all('.segment-orig-dest')[0].text
              first_origin = segment_orig_dest.scan(/(.+ to)/).flatten.compact.first.gsub(' to', '')
              first_destination = segment_orig_dest.scan(/(to .+)/).flatten.compact.first.gsub('to ', '')
              first_duration = first_segment_times.scan(/(\d+h \d+m)|(\d+h)/).flatten.compact.first
              first_airline = fare.all('.carrier-icon')[0]['title'] if fare.all('.carrier-icon').size > 0
              equipment = fare.all('.segment-flight-equipment')[0].text
              first_flight_number = equipment.scan(/([A-Z]+ \d+)/).flatten.compact.first
              first_aircraft = equipment.gsub(/([A-Z]+ \d+ \| )/, '')
              first_segment =
                {
                  airline: first_airline,
                  flight_number: first_flight_number,
                  departs:
                    {
                      date: nil,
                      time: first_depart_time,
                      airport: first_origin,
                    },
                  arrives:
                    {
                      date: nil,
                      time: first_arrive_time,
                      airport: first_destination,
                    },
                  cabin: nil,
                  bookclass: nil,
                  aircraft: first_aircraft,
                  duration: first_duration
                }
            end
            

            connections_size = fare.all('.width-restrictor span').size
            connection_time =
              if (connections_size > 0 && stops == '1 stop') || (connections_size == 1 && stops == '2 stops')
                fare.all('.width-restrictor span')[0].text.gsub('connection','').strip
              else
                if connections_size > 0 && stops == '2 stops'
                  first_conn = fare.all('.width-restrictor span')[0].text.gsub('connection','').strip
                  second_conn = fare.all('.width-restrictor span')[1].text.gsub('connection','').strip
                  {first_conn: first_conn, second_conn: second_conn}
                end
              end

            unless stops == 'Nonstop'
              second_segment_times = fare.all('.segment-times')[1].text
              second_depart_time = second_segment_times.scan(/(\d+:\d+ am|\d+:\d+ pm)/).flatten.compact.first
              second_arrive_time = second_segment_times.scan(/(\d+:\d+ am|\d+:\d+ pm)/).flatten.compact.last
              segment_orig_dest = fare.all('.segment-orig-dest')[1].text
              second_origin = segment_orig_dest.scan(/(.+ to)/).flatten.compact.first.gsub(' to', '')
              second_destination = segment_orig_dest.scan(/(to .+)/).flatten.compact.first.gsub('to ', '')
              second_duration = second_segment_times.scan(/(\d+h \d+m)|(\d+h)/).flatten.compact.first
              second_airline = fare.all('.carrier-icon')[1]['title'] if fare.all('.carrier-icon').size == 2
              equipment = fare.all('.segment-flight-equipment')[1].text
              second_flight_number = equipment.scan(/([A-Z]+ \d+)/).flatten.compact.first
              second_aircraft = equipment.gsub(/([A-Z]+ \d+ \| )/, '')
              second_segment =
                {
                  airline: second_airline,
                  flight_number: second_flight_number,
                  departs:
                    {
                      date: nil,
                      time: second_depart_time,
                      airport: second_origin,
                    },
                  arrives:
                    {
                      date: nil,
                      time: second_arrive_time,
                      airport: second_destination,
                    },
                  cabin: nil,
                  bookclass: nil,
                  aircraft: second_aircraft,
                  duration: second_duration
                }
                if stops == '2 stops' && fare.all('.carrier-icon').size > 2
                  third_segment_times = fare.all('.segment-times')[2].text
                  third_depart_time = third_segment_times.scan(/(\d+:\d+ am|\d+:\d+ pm)/).flatten.compact.first
                  third_arrive_time = third_segment_times.scan(/(\d+:\d+ am|\d+:\d+ pm)/).flatten.compact.last
                  segment_orig_dest = fare.all('.segment-orig-dest')[2].text
                  third_origin = segment_orig_dest.scan(/(.+ to)/).flatten.compact.first.gsub(' to', '')
                  third_destination = segment_orig_dest.scan(/(to .+)/).flatten.compact.first.gsub('to ', '')
                  third_duration = third_segment_times.scan(/(\d+h \d+m)|(\d+h)/).flatten.compact.first
                  third_airline = fare.all('.carrier-icon')[2]['title'] if fare.all('.carrier-icon').size == 3
                  # orig_dist = fare.all('.segment-orig-dest')[2].text
                  equipment = fare.all('.segment-flight-equipment')[2].text
                  third_flight_number = equipment.scan(/([A-Z]+ \d+)/).flatten.compact.first
                  third_aircraft = equipment.gsub(/([A-Z]+ \d+ \| )/, '')
                  third_segment =
                    {
                      airline: third_airline,
                      flight_number: third_flight_number,
                      departs:
                        {
                          date: nil,
                          time: third_depart_time,
                          airport: third_origin,
                        },
                      arrives:
                        {
                          date: nil,
                          time: third_arrive_time,
                          airport: third_destination,
                        },
                      cabin: nil,
                      bookclass: nil,
                      aircraft: third_aircraft,
                      duration: third_duration
                    }
                end
            end

            # connection =
            #   if fare.find('.connection-count').text == '1 stop'
            #     fare.find('.toggle-flight-block-details').click
            #     # orig_dist = fare.find()
            #     # stops_info = fare.all('.ui-state-default.ui-corner-top')[1]['data-seat-select']
            #     stops = '1 stop'
            #     stop_time = fare.find('.width-restrictor span').text.gsub('connection','').strip
            #     {stops: stops, stop_time: stop_time}
            #   elsif fare.find('.connection-count').text == '2 stops'
            #     fare.find('.toggle-flight-block-details').click
            #     # stops_info = fare.all('.ui-state-default.ui-corner-top')[1]['data-seat-select']
            #     stops = '2 stops'
            #     first_stop_time = fare.all('.width-restrictor span')[0].text.gsub('connection','').strip
            #     second_stop_time = fare.all('.width-restrictor span')[1].text.gsub('connection','').strip if fare.all('.width-restrictor span').size > 1
            #     {stops: stops, first_stop_time: first_stop_time, second_stop_time: second_stop_time}
            #   else
            #     fare.find('.connection-count').text
            #   end

            connection =
              case stops
              when 'Nonstop'
                { stops: stops, first_segment: first_segment }
              when '1 stop'
                {
                  stops: stops,
                  first_segment: first_segment,
                  connection_time: connection_time,
                  second_segment: second_segment
                }
              when '2 stops'
                {
                  stops: stops,
                  first_segment: first_segment,
                  connection_time: connection_time,
                  second_segment: second_segment,
                  third_segment: third_segment
                }
              else

              end
            

            economy = if fare.all('#product_MIN-ECONOMY-SURP-OR-DISP').size > 0
                miles = fare.find('#product_MIN-ECONOMY-SURP-OR-DISP .pp-base-price').text
                taxes = fare.find('#product_MIN-ECONOMY-SURP-OR-DISP .pp-additional-fare').text
                {miles: miles, taxes: taxes}
              else
                'Not Available'
              end
            business_saver = if fare.all('#product_BUSINESS-SURPLUS').size > 0
                miles = fare.find('#product_BUSINESS-SURPLUS .pp-base-price').text
                taxes = fare.find('#product_BUSINESS-SURPLUS .pp-additional-fare').text
                {miles: miles, taxes: taxes}
              else
                'Not Available'
              end
            business = if fare.all('#product_BUSINESS-DISPLACEMENT').size > 0
                miles = fare.find('#product_BUSINESS-DISPLACEMENT .pp-base-price').text
                taxes = fare.find('#product_BUSINESS-DISPLACEMENT .pp-additional-fare').text
                {miles: miles, taxes: taxes}
              else
                'Not Available'
              end
            first_saver = if fare.all('#product_FIRST-SURPLUS').size > 0
                miles = fare.find('#product_FIRST-SURPLUS .pp-base-price').text
                taxes = fare.find('#product_FIRST-SURPLUS .pp-additional-fare').text
                {miles: miles, taxes: taxes}
              else
                'Not Available'
              end
            first = if fare.all('#product_FIRST-DISPLACEMENT').size > 0
                miles = fare.find('#product_FIRST-DISPLACEMENT .pp-base-price').text
                taxes = fare.find('#product_FIRST-DISPLACEMENT .pp-additional-fare').text
                {miles: miles, taxes: taxes}
              else
                'Not Available'
              end
            data << {
              depart_date: depart_date,
              depart_time: depart_time,
              origin: origin,
              destination: destination,
              arrive_date: arrive_date,
              arrive_time: arrive_time,
              connection: connection,
              duration: duration,
              economy: economy,
              business_saver: business_saver,
              business: business,
              first_saver: first_saver,
              first: first
            }
          end
        end
      rescue Exception => e
        puts e.message
        # puts e.backtrace.inspect
        if e.message.include?("failed to reach server, check DNS and/or server status")
          return 'united.com failed to reach server'
        end
        Capybara.reset_sessions!
        retry
      end
      

      
      # page.save_screenshot('end.png')

      Capybara.reset_sessions!
      data
      # JSON.pretty_generate(data)
      # puts 'End of script'
      # puts Time.now - t
    end

  end
end
