require 'capybara'
require 'capybara/poltergeist'
require 'capybara/dsl'
require 'json'

module Octopus  
  class Aeroplan
    include Capybara::DSL
    Capybara.register_driver :poltergeist do |app|
      Capybara::Poltergeist::Driver.new(app, window_size: [1920, 1080], timeout: 15, js_errors: false)
    end
    Capybara.default_driver = :poltergeist
    Capybara.default_max_wait_time = 15

    attr_reader :from, :to, :date, :login, :password
    def initialize(from, to, date, login, password)
      @from    = from.upcase
      @to = to.upcase
      @date = date #DateTime.parse(date).strftime("%a, %b%e, %Y")
      @login = login
      @password = password
    end

    def get_data
      t = Time.now
      data = []
      begin
        visit "https://www4.aeroplan.com/home.do"
        return "Aeroplan currently undergoing routine maintenance of the site" if page.all(".grey-hline-maintenance").size > 0
        page.find('.splash-btn-en').click if page.all('.splash-btn-en').size > 0
        sleep 2
        log_in
        # page.save_screenshot('error.png')
        page.find('span.header-name').text
        
        click_link 'FLIGHTS'
        choose 'searchTypeTab_oneway'
        sleep 0.5
        fill_in "city1FromOneway", with: @from
        fill_in "city1ToOneway", with: @to
        page.find(".inputField").click

        until page.find('#month_year_display_1').text.include? DateTime.parse(@date).strftime("%B") do
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
          depart_time = fare.find('.from').text.scan(/(\d+:\d+)/).flatten.compact.first
          origin = fare.find('.from').text.scan(/([A-Z]+)/).flatten.compact.first if fare.all('.from').size > 0
          arrive_time = fare.find('.to').text.scan(/(\d+:\d+)/).flatten.compact.first
          destination = fare.find('.to').text.scan(/([A-Z]+)/).flatten.compact.first if fare.all('.to').size > 0
          stops = fare.find('.stops').text
          full_duration = fare.find('.duration').text
          miles = fare.find('.miles').text
          fare.find('.detailsLink').click
          sleep 1
          airline = fare.all('.middleColumn .line')[0].text
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
          first_segment =
            {
              airline: airline_first,
              flight_number: flight_number,
              departs:
                {
                  date: date_first,
                  time: time_first,
                  airport: airport_first,
                },
              arrives:
                {
                  date: date_second,
                  time: time_second,
                  airport: airport_second,
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
            second_segment = 
              {
                airline: airline_second,
                flight_number: flight_number,
                departs:
                  {
                    date: date_first,
                    time: time_first,
                    airport: airport_first,
                  },
                arrives:
                  {
                    date: date_second,
                    time: time_second,
                    airport: airport_second,
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
                third_segment = 
                  {
                    airline: airline_second,
                    flight_number: flight_number,
                    departs:
                      {
                        date: date_first,
                        time: time_first,
                        airport: airport_first,
                      },
                    arrives:
                      {
                        date: date_second,
                        time: time_second,
                        airport: airport_second,
                      },
                    cabin: cabin,
                    bookclass: bookclass,
                    aircraft: aircraft,
                    duration: duration
                  }
              end
          end
          
          connection =
            case stops 
            when 'Direct'
              { stops: stops, first_segment: first_segment }
            when '1 Stop(s)'
              {
                stops: stops,
                first_segment: first_segment,
                connection_time: connection_time,
                second_segment: second_segment
              }
            when '2 Stop(s)'
              {
                stops: stops,
                first_segment: first_segment,
                connection_time: connection_time,
                second_segment: second_segment,
                third_segment: third_segment
              }
            end
            
          data << {
            # depart_date: depart_date,
            depart_time: depart_time,
            origin: origin,
            destination: destination,
            # arrive_date: arrive_date,
            arrive_time: arrive_time,
            connection: connection,
            duration: full_duration,
            miles: miles
          }
        end
      rescue Exception => e
        puts e.message
        # puts e.backtrace.inspect
        Capybara.reset_sessions!
        # puts "Please try again"
        retry
      end

      Capybara.reset_sessions!
      puts Time.now - t
      data#.present? ? data : "Please try again"
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
        day = DateTime.parse(@date).strftime("%e").to_i
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
