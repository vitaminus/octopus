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
        return { errors: "Wrong date. Please enter date => #{Time.now.strftime('%F')}" } if DateTime.parse(@departure).strftime('%F') < Time.now.strftime('%F')
        visit "https://www.united.com/ual/en/us/flight-search/book-a-flight/results/awd?f=#{@from}&t=#{@to}&d=#{@departure}&tt=1&st=bestmatches&at=1&cbm=-1&cbm2=-1&sc=7&px=1&taxng=1&idx=1"
        page.find('.language-region-change').click if page.all('.language-region-change').size > 0
        page.find('.flight-result-list')
        sleep 1.5
        page.all('.col-header-content')[1].trigger('click')
        sleep 2
        page.all('.flight-block.flight-block-fares').each do |fare|
          if fare.all('#product_BUSINESS-SURPLUS').size > 0
            segments = []
            depart_date = DateTime.parse(fare.find('.flight-time.flight-time-depart .date-duration').text).strftime('%F') if fare.all('.flight-time.flight-time-depart .date-duration').size > 0
            depart_time = fare.find('.flight-time.flight-time-depart').text.scan(/(\d+:\d+ am)|(\d+:\d+ pm)/).flatten.compact.first
            departure = date_time(depart_date, depart_time)
            origin = fare.find('.airport-code.origin-airport-mismatch-code').text if fare.all('.airport-code.origin-airport-mismatch-code').size > 0
            arrive_date = DateTime.parse(fare.find('.flight-time.flight-time-arrive .date-duration').text).strftime('%F') if fare.all('.flight-time.flight-time-arrive .date-duration').size > 0
            arrive_time = fare.find('.flight-time.flight-time-arrive').text.scan(/(\d+:\d+ am)|(\d+:\d+ pm)/).flatten.compact.first
            arrival = date_time(arrive_date, arrive_time)
            puts arrival
            destination = fare.find('.airport-code.destination-airport-mismatch-code').text if fare.all('.airport-code.destination-airport-mismatch-code').size > 0
            duration = convert_to_minutes(fare.find('.flight-duration.otp-tooltip-trigger').text)
            stops = fare.find('.connection-count').text
            sleep 0.5
            fare.find('.toggle-flight-block-details').trigger('click')
             
            if stops == 'Nonstop'
              airline = fare.all('.carrier-icon')[0]['title']
              equipment = fare.all('.segment-flight-equipment')[0].text
              flight_number = get_flight_number equipment
              carrier = get_carrier equipment
              aircraft = get_aircraft equipment
              segments << {
                  from: origin,
                  to: destination,
                  departure: departure,
                  arrival: arrival,
                  duration: duration,
                  airline: airline,
                  carrier: carrier,
                  number: flight_number,
                  aircraft: aircraft,
                  cabin: nil,
                  bookclass: nil
                }
            else
              first_segment_times = fare.all('.segment-times')[0].text
              first_depart_time = first_segment_times.scan(/(\d+:\d+ am|\d+:\d+ pm)/).flatten.compact.first
              first_arrive_time = first_segment_times.scan(/(\d+:\d+ am|\d+:\d+ pm)/).flatten.compact.last
              segment_orig_dest = fare.all('.segment-orig-dest')[0].text
              first_origin = segment_orig_dest.scan(/(.+ to)/).flatten.compact.first.gsub(' to', '')
              first_destination = segment_orig_dest.scan(/(to .+)/).flatten.compact.first.gsub('to ', '')
              first_duration = convert_to_minutes(first_segment_times.scan(/(\d+h \d+m)|(\d+h)|(\d+m)/).flatten.compact.first)
              first_airline = fare.all('.carrier-icon')[0]['title'] if fare.all('.carrier-icon').size > 0
              equipment = fare.all('.segment-flight-equipment')[0].text
              first_flight_number = get_flight_number equipment
              first_carrier = get_carrier equipment
              first_aircraft = get_aircraft equipment
              segments << {
                  from: first_origin,
                  to: first_destination,
                  departure: first_depart_time,
                  arrival: first_arrive_time,
                  duration: first_duration,
                  airline: first_airline,
                  carrier: first_carrier,
                  number: first_flight_number,
                  aircraft: first_aircraft,
                  cabin: nil,
                  bookclass: nil
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
              second_duration = convert_to_minutes(second_segment_times.scan(/(\d+h \d+m)|(\d+h)|(\d+m)/).flatten.compact.first)
              second_airline = fare.all('.carrier-icon')[1]['title'] if fare.all('.carrier-icon').size == 2
              equipment = fare.all('.segment-flight-equipment')[1].text
              second_flight_number = get_flight_number equipment
              second_carrier = get_carrier equipment
              second_aircraft = get_aircraft equipment
              segments << {
                  from: second_origin,
                  to: second_destination,
                  departure: second_depart_time,
                  arrival: second_arrive_time,
                  duration: second_duration,
                  airline: second_airline,
                  carrier: second_carrier,
                  number: second_flight_number,
                  aircraft: second_aircraft,
                  cabin: nil,
                  bookclass: nil
                }
                if stops == '2 stops' && fare.all('.width-restrictor').size > 1
                  third_segment_times = fare.all('.segment-times')[2].text
                  third_depart_time = third_segment_times.scan(/(\d+:\d+ am|\d+:\d+ pm)/).flatten.compact.first
                  third_arrive_time = third_segment_times.scan(/(\d+:\d+ am|\d+:\d+ pm)/).flatten.compact.last
                  segment_orig_dest = fare.all('.segment-orig-dest')[2].text
                  third_origin = segment_orig_dest.scan(/(.+ to)/).flatten.compact.first.gsub(' to', '')
                  third_destination = segment_orig_dest.scan(/(to .+)/).flatten.compact.first.gsub('to ', '')
                  third_duration = convert_to_minutes(third_segment_times.scan(/(\d+h \d+m)|(\d+h)|(\d+m)/).flatten.compact.first)
                  third_airline = fare.all('.carrier-icon')[2]['title'] if fare.all('.carrier-icon').size == 3
                  equipment = fare.all('.segment-flight-equipment')[2].text
                  third_flight_number = equipment.scan(/([A-Z]+ \d+)/).flatten.compact.first
                  third_aircraft = equipment.gsub(/([A-Z]+ \d+ \| )/, '')
                  segments << {
                      from: third_origin,
                      to: third_destination,
                      departure:
                        {
                          date: nil,
                          time: third_depart_time,
                        },
                      arrival:
                        {
                          date: nil,
                          time: third_arrive_time,
                        },
                      duration: third_duration,
                      carrier: third_airline,
                      number: third_flight_number,
                      aircraft: third_aircraft,
                      cabin: nil,
                      bookclass: nil
                    }
                end
            end
            # TODO add connection_time to segments
            # connection =
            #   case stops
            #   when 'Nonstop'
            #     { stops: stops, segments: segments }
            #   when '1 stop'
            #     {
            #       stops: stops,
            #       segments: segments,
            #       connection_time: connection_time
            #     }
            #   when '2 stops'
            #     {
            #       stops: stops,
            #       segments: segments,
            #       connection_time: connection_time
            #     }
            #   else

            #   end
            

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
              from: origin,
              to: destination,
              departure: departure,
              arrival: arrival,
              duration: duration,
              segments: segments,
              cabins: {
                economy: economy,
                business_saver: business_saver,
                business: business,
                first_saver: first_saver,
                first: first
              }              
            }
          end
        end
      rescue Exception => e
        puts e.message
        puts e.backtrace.inspect
        Capybara.reset_sessions!
        retry
      end
      
      Capybara.reset_sessions!
      return { message: 'For this date not available saver business flights.' } if data.empty?
      {
        from: @from,
        to: @to,
        departure: @departure,
        flights: data
      }
    end

    private

      def date_time(date, time)
        if date
          "#{date}T#{time}"
        else
          "#{@departure}T#{time}"
        end
      end

      def get_flight_number eq
        eq.scan(/(\d+)/).flatten.compact.first
      end

      def get_carrier eq
        eq.scan(/([A-Z]+)/).flatten.compact.first
      end

      def get_aircraft eq
        eq.gsub(/([A-Z]+ \d+ \| )/, '')
      end

      def convert_to_minutes time
        if time.include?('h')
          t = DateTime.parse(time)
          t.hour*60 + t.min
        else
          time.gsub(/m/, '').to_i
        end
      end

  end
end
