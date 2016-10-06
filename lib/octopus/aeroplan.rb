require 'capybara'
require 'capybara/poltergeist'
require 'capybara/dsl'
require 'json'

module Octopus  
  class Aeroplan
    include Capybara::DSL
    Capybara.register_driver :poltergeist do |app|
      Capybara::Poltergeist::Driver.new(app, window_size: [1920, 1080], timeout: 12, js_errors: false, phantomjs_options: ['--ignore-ssl-errors=yes', '--local-to-remote-url-access=yes'])
    end
    Capybara.default_driver = :poltergeist
    Capybara.javascript_driver = :poltergeist
    Capybara.default_max_wait_time = 20

    attr_reader :from, :to, :departure
    def initialize(from, to, departure)
      @from    = from.upcase
      @to = to.upcase
      @departure = departure #DateTime.parse(date).strftime("%a, %b%e, %Y")
      @login = '970001715'
      @password = '123A45b7C'
    end

    def get_data
      t = Time.now
      data = []
      i = 0
      begin
        visit "https://www4.aeroplan.com"
        if page.all(".grey-hline-maintenance").size > 0
          Capybara.reset_sessions!
          return "Aeroplan currently undergoing routine maintenance of the site"
        end
        page.find('.splash-btn-en').click if page.all('.splash-btn-en').size > 0
        sleep 2
        
        begin
          log_in
        rescue Exception => e
          Capybara.reset_sessions!
          return 'The Aeroplan Number and/or password you entered does not match'
        end
        sleep 2
        click_link 'FLIGHTS'
        sleep 2
        choose 'searchTypeTab_oneway'
        sleep 0.5
        fill_in "city1FromOneway", with: @from
        fill_in "city1ToOneway", with: @to
        page.find(".inputField").click

        until page.find('#month_year_display_1').text.include? DateTime.parse(@departure).strftime("%B") do
          page.find('.cal-arrow-next').click
        end
        select_date
        # page.save_screenshot('error1.png')
        page.select 'Business', from: "OnewayCabin"
        page.find('.innerButton').click
        sleep 2
        if page.all('.alertContainer').size > 0 && page.all('.alertContainer')[0].text.include?('No results were found')
          return 'No results were found'
        end
        page.find('#classic-business0')
        # page.save_screenshot('aeroplan_after_fill_one_way_form.png')
        page.all('.flightRow ').each do |fare|
          segments = []
          depart_time = fare.find('.from').text.scan(/(\d+:\d+)/).flatten.compact.first
          origin = fare.find('.from').text.scan(/([A-Z]+)/).flatten.compact.first if fare.all('.from').size > 0
          arrive_time = fare.find('.to').text.scan(/(\d+:\d+)/).flatten.compact.first
          destination = fare.find('.to').text.scan(/([A-Z]+)/).flatten.compact.first if fare.all('.to').size > 0
          stops = fare.find('.stops').text
          # full_duration = fare.find('.duration').text
          miles = fare.find('.miles').text
          fare.find('.detailsLink').click
          sleep 1
          airline = fare.all('.middleColumn .line')[0].text
          puts airline
          airline_first = airline.gsub(/([A-Z]+\d+)/,'').strip
          flight_number = airline.scan(/([A-Z]+\d+)/).flatten.compact.first

          date_first = fare.all('.middleColumn .line .date')[0].text
          time_first = fare.all('.middleColumn .line .time')[0].text

          airport_first = fare.all('.middleColumn .line .airport')[0].text

          date_second = fare.all('.middleColumn .line .date')[1].text
          time_second = fare.all('.middleColumn .line .time')[1].text

          airport_second = fare.all('.middleColumn .line .airport')[1].text

          cabin = fare.all('.middleColumn .cabin div')[0].text
          bookclass = fare.all('.middleColumn .bookclass')[0].text
          aircraft = fare.all('.middleColumn .aircraft')[0].text
          duration = fare.all('.middleColumn .duration b')[0].text
          segments <<
            {
              from: airport_first,
              to: airport_second,
              airline: airline_first,
              flight_number: flight_number,
              departs:
                {
                  date: date_first,
                  time: time_first,
                },
              arrives:
                {
                  date: date_second,
                  time: time_second,
                },
              cabin: cabin,
              bookclass: bookclass,
              aircraft: aircraft,
              duration: duration
            }

          connection_time =
            if fare.all('.connection span.bold').size > 0 && stops == '1 Stop(s)'
              fare.find('.connection span.bold').text
            else
              if fare.all('.connection span.bold').size > 0
                first_conn = fare.all('.connection span.bold')[0].text
                second_conn = fare.all('.connection span.bold')[1].text
                {first_conn: first_conn, second_conn: second_conn}
              end
            end

          unless stops == 'Direct'
            airline = fare.all('.middleColumn .line')[4].text
            airline_second = airline.gsub(/([A-Z]+\d+)/,'').strip
            flight_number = airline.scan(/([A-Z]+\d+)/).flatten.compact.first
            date_first = fare.all('.middleColumn .line .date')[2].text
            time_first = fare.all('.middleColumn .line .time')[2].text
            airport_first = fare.all('.middleColumn .line .airport')[2].text
            date_second = fare.all('.middleColumn .line .date')[3].text
            time_second = fare.all('.middleColumn .line .time')[3].text
            airport_second = fare.all('.middleColumn .line .airport')[3].text
            cabin = fare.all('.middleColumn .cabin div')[1].text
            bookclass = fare.all('.middleColumn .bookclass')[1].text
            aircraft = fare.all('.middleColumn .aircraft')[1].text
            duration = fare.all('.middleColumn .duration b')[1].text
            segments <<
              {
                from: airport_first,
                to: airport_second,
                airline: airline_second,
                flight_number: flight_number,
                departs:
                  {
                    date: date_first,
                    time: time_first,
                    # airport: airport_first,
                  },
                arrives:
                  {
                    date: date_second,
                    time: time_second,
                    # airport: airport_second,
                  },
                cabin: cabin,
                bookclass: bookclass,
                aircraft: aircraft,
                duration: duration
              }
              if stops == '2 Stop(s)'
                airline = fare.all('.middleColumn .line')[8].text
                airline_second = airline.gsub(/([A-Z]+\d+)/,'').strip
                flight_number = airline.scan(/([A-Z]+\d+)/).flatten.compact.first
                # puts airline
                date_first = fare.all('.middleColumn .line .date')[4].text
                time_first = fare.all('.middleColumn .line .time')[4].text
                airport_first = fare.all('.middleColumn .line .airport')[4].text
                date_second = fare.all('.middleColumn .line .date')[5].text
                time_second = fare.all('.middleColumn .line .time')[5].text
                airport_second = fare.all('.middleColumn .line .airport')[5].text
                cabin = fare.all('.middleColumn .cabin div')[2].text
                bookclass = fare.all('.middleColumn .bookclass')[2].text
                aircraft = fare.all('.middleColumn .aircraft')[2].text
                duration = fare.all('.middleColumn .duration b')[2].text
                segments << 
                  {
                    from: airport_first,
                    to: airport_second,
                    airline: airline_second,
                    flight_number: flight_number,
                    departs:
                      {
                        date: date_first,
                        time: time_first,
                        # airport: airport_first,
                      },
                    arrives:
                      {
                        date: date_second,
                        time: time_second,
                        # airport: airport_second,
                      },
                    cabin: cabin,
                    bookclass: bookclass,
                    aircraft: aircraft,
                    duration: duration
                  }
              end
          end
          
          # connection =
          #   case stops 
          #   when 'Direct'
          #     { stops: stops, first_segment: first_segment }
          #   when '1 Stop(s)'
          #     {
          #       stops: stops,
          #       first_segment: first_segment,
          #       connection_time: connection_time,
          #       second_segment: second_segment
          #     }
          #   when '2 Stop(s)'
          #     {
          #       stops: stops,
          #       first_segment: first_segment,
          #       connection_time: connection_time,
          #       second_segment: second_segment,
          #       third_segment: third_segment
          #     }
          #   end
          data << 
            {
              from: origin,
              to: destination,
              departure: depart_time,
              arrival: arrive_time,
              duration: duration,
              miles: miles,
              segments: segments,
            }
          # data << {
          #   # depart_date: depart_date,
          #   depart_time: depart_time,
          #   origin: origin,
          #   destination: destination,
          #   # arrive_date: arrive_date,
          #   arrive_time: arrive_time,
          #   # connection: connection,
          #   # duration: full_duration,
          #   miles: miles
          # }
        end
      rescue Exception => e
        i += 1
        puts e.message
        # puts e.backtrace.inspect
        # puts Time.now - t
        # if e.message.include?("failed to reach server, check DNS and/or server status")
        #   return 'aeroplan.com failed to reach server'
        # end
        Capybara.reset_sessions!
        if i < 3
          retry
        else
          return {errors: "Something went wrong. Please try again later."}
        end
      end

      Capybara.reset_sessions!
      puts Time.now - t
      {
        from: @from,
        to: @to,
        departure: @departure,
        flights: data
      }
      #.present? ? data : "Please try again"
      # puts JSON.pretty_generate(data)
    end

    private

      def log_in
        click_button 'LOG IN'
        page.fill_in 'Aeroplan Number', with: @login
        page.fill_in 'Password', with: @password
        page.find(".form-login-submit").trigger('click')
      end

      def select_date
        calendar = page.find("#adrcalendar_widget")
        day = DateTime.parse(@departure).strftime("%e").to_i
        current_day = Time.now.strftime("%e").to_i
        # sleep 2
        if day == current_day && calendar.all('.currentSelection').size > 0
          calendar.find('.currentSelection').click
        elsif calendar.all('.forbiddenDay').size > 0
          forbidden_days = calendar.all('.forbiddenDay').size + 1
          calendar.all('.calendarDay')[day - forbidden_days - 1].click
        else
          calendar.all('.calendarDay')[day - 1].click
        end
      end

  end
end
