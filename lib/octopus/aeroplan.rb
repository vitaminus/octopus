require 'capybara'
require 'capybara/poltergeist'
require 'capybara/dsl'
require 'json'

module Octopus  
  class Aeroplan
    include Capybara::DSL
    Capybara.register_driver :poltergeist do |app|
      Capybara::Poltergeist::Driver.new(app, window_size: [1920, 1080], timeout: 15, js_errors: false, phantomjs_options: ['--ignore-ssl-errors=yes', '--local-to-remote-url-access=yes'])
    end
    Capybara.default_driver = :poltergeist
    Capybara.javascript_driver = :poltergeist
    Capybara.default_max_wait_time = 20

    attr_reader :from, :to, :departure
    def initialize(from, to, departure)
      @from    = from.upcase
      @to = to.upcase
      @departure = departure
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
          return { errors: "Aeroplan currently undergoing routine maintenance of the site" }
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
        page.select 'Business', from: "OnewayCabin"
        page.find('.innerButton').click
        sleep 2
        if page.all('.alertContainer').size > 0 && page.all('.alertContainer')[0].text.include?('No results were found')
          return { errors: 'No results were found' }
        end
        page.find('#classic-business0')
        page.all('.flightRow ').each do |fare|
          segments = []
          depart_time   = DateTime.parse(fare.find('.from').text.scan(/(\d+:\d+)/).flatten.compact.first).strftime('%H:%M:%S')
          origin        = fare.find('.from').text.scan(/([A-Z]+)/).flatten.compact.first if fare.all('.from').size > 0
          arrive_time   = DateTime.parse(fare.find('.to').text.scan(/(\d+:\d+)/).flatten.compact.first).strftime('%H:%M:%S')
          destination   = fare.find('.to').text.scan(/([A-Z]+)/).flatten.compact.first if fare.all('.to').size > 0
          stops         = fare.find('.stops').text
          # puts fare.find('.duration').text
          full_duration = convert_full_duration fare.find('.duration').text
          miles         = fare.find('.miles').text
          fare.find('.detailsLink').click
          sleep 1
          airline        = fare.all('.middleColumn .line')[0].text
          flight_number  = get_flight_number airline
          carrier        = get_carrier airline
          date_first     = fare.all('.middleColumn .line .date')[0].text
          time_first     = fare.all('.middleColumn .line .time')[0].text
          departure_first = split_date(date_first, time_first)
          airport_first  = get_airport fare.all('.middleColumn .line .airport')[0].text
          date_second    = fare.all('.middleColumn .line .date')[1].text
          time_second    = fare.all('.middleColumn .line .time')[1].text
          arrival_first  = split_date(date_second, time_second)
          airport_second = get_airport fare.all('.middleColumn .line .airport')[1].text
          cabin          = fare.all('.middleColumn .cabin div')[0].text
          bookclass      = fare.all('.middleColumn .bookclass')[0].text
          aircraft       = fare.all('.middleColumn .aircraft')[0].text
          duration       = convert_to_minutes DateTime.parse(fare.all('.middleColumn .duration b')[0].text).strftime('%Hh %Mmin')
          segments <<
            {
              from: airport_first,
              to: airport_second,
              departure: departure_first,
              arrival: arrival_first,
              duration: duration,
              number: flight_number,
              carrier: carrier,
              operated_by: carrier,
              aircraft: aircraft,
              cabin: cabin,
              bookclass: bookclass
            }

          connection_time =
            if fare.all('.connection span.bold').size > 0 && stops == '1 Stop(s)'
              convert_to_minutes fare.find('.connection span.bold').text
            else
              if fare.all('.connection span.bold').size > 0
                first_conn  = convert_to_minutes fare.all('.connection span.bold')[0].text
                second_conn = convert_to_minutes fare.all('.connection span.bold')[1].text
                {first_conn: first_conn, second_conn: second_conn}
              end
            end

          unless stops == 'Direct'
            airline        = fare.all('.middleColumn .line')[4].text
            flight_number  = get_flight_number airline
            carrier        = get_carrier airline
            date_first     = fare.all('.middleColumn .line .date')[2].text
            time_first     = fare.all('.middleColumn .line .time')[2].text
            departure_first = split_date(date_first, time_first)
            airport_first  = get_airport fare.all('.middleColumn .line .airport')[2].text
            date_second    = fare.all('.middleColumn .line .date')[3].text
            time_second    = fare.all('.middleColumn .line .time')[3].text
            arrival_first  = split_date(date_second, time_second)
            airport_second = get_airport fare.all('.middleColumn .line .airport')[3].text
            cabin          = fare.all('.middleColumn .cabin div')[1].text
            bookclass      = fare.all('.middleColumn .bookclass')[1].text
            aircraft       = fare.all('.middleColumn .aircraft')[1].text
            duration       = convert_to_minutes DateTime.parse(fare.all('.middleColumn .duration b')[1].text).strftime('%Hh %Mmin')
            segments <<
              {
                from: airport_first,
                to: airport_second,
                departure: departure_first,
                arrival: arrival_first,
                duration: duration,
                number: flight_number,
                carrier: carrier,
                operated_by: carrier,
                aircraft: aircraft,
                stopover: connection_time,
                cabin: cabin,
                bookclass: bookclass
              }
              if stops == '2 Stop(s)'
                airline        = fare.all('.middleColumn .line')[8].text
                flight_number  = get_flight_number airline
                carrier        = get_carrier airline
                date_first     = fare.all('.middleColumn .line .date')[4].text
                time_first     = fare.all('.middleColumn .line .time')[4].text
                departure_first = split_date(date_first, time_first)
                airport_first  = get_airport fare.all('.middleColumn .line .airport')[4].text
                date_second    = fare.all('.middleColumn .line .date')[5].text
                time_second    = fare.all('.middleColumn .line .time')[5].text
                arrival_first  = split_date(date_second, time_second)
                airport_second = get_airport fare.all('.middleColumn .line .airport')[5].text
                cabin          = fare.all('.middleColumn .cabin div')[2].text
                bookclass      = fare.all('.middleColumn .bookclass')[2].text
                aircraft       = fare.all('.middleColumn .aircraft')[2].text
                duration       = convert_to_minutes DateTime.parse(fare.all('.middleColumn .duration b')[2].text).strftime('%Hh %Mmin')
                segments << 
                  {
                    from: airport_first,
                    to: airport_second,
                    departure: departure_first,
                    arrival: arrival_first,
                    duration: duration,
                    number: flight_number,
                    carrier: carrier,
                    operated_by: carrier,
                    aircraft: aircraft,
                    cabin: cabin,
                    bookclass: bookclass
                  }
              end
          end

          data << 
            {
              from: origin,
              to: destination,
              departure: depart_time,
              arrival: arrive_time,
              duration: full_duration,
              miles: miles,
              segments: segments,
            }
        end
      rescue Exception => e
        i += 1
        puts e.message
        # puts e.backtrace.inspect
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
        if day == current_day && calendar.all('.currentSelection').size > 0
          calendar.find('.currentSelection').click
        elsif calendar.all('.forbiddenDay').size > 0
          forbidden_days = calendar.all('.forbiddenDay').size + 1
          calendar.all('.calendarDay')[day - forbidden_days - 1].click
        else
          calendar.all('.calendarDay')[day - 1].click
        end
      end

      def date_time(date, time)
        if date
          "#{date}T#{time}"
        else
          "#{@departure}T#{time}"
        end
      end

      def split_date(date, time)
        DateTime.parse("#{date} #{time}").strftime('%FT%H:%M:%S')
      end

      def get_flight_number eq
        eq.scan(/(\d+)/).flatten.compact.first
      end

      def get_carrier eq
        eq.scan(/([A-Z]+\d+)/).flatten.compact.first.gsub(/\d+/, '')
      end

      def get_airport(orig_dest)
        orig_dest.scan(/([A-Z]{3})/).flatten.compact.first
      end

      def convert_to_minutes time
        if time.include?('h') && time.include?('min')
          t = DateTime.parse(time)
          t.hour*60 + t.min
        elsif time.include?('h') && !time.include?('min')
          t = DateTime.parse(time)
          t.hour*60
        else
          time.gsub(/min/, '').to_i
        end
      end

      def convert_full_duration time
        h = time.scan(/(\d+h)/).flatten.compact.first.gsub(/h/, '').to_i
        m = time.scan(/(\d+min)/).flatten.compact.first.gsub(/min/, '').to_i
        h*60 + m
      end

  end
end
