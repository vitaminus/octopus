require 'capybara'
require 'capybara/poltergeist'
require 'capybara/dsl'
require 'json'

module Octopus  
  class United
    include Capybara::DSL
    Capybara.default_driver = :poltergeist
    Capybara.default_wait_time = 25

    attr_reader :from, :to, :date
    def initialize(from, to, date)
      @from    = from.upcase
      @to = to.upcase
      @date = date
    end

    def get_data
      t = Time.now
      data = []
      begin
        visit "https://www.united.com/ual/en/us/flight-search/book-a-flight/results/awd?f=#{@from}&t=#{@to}&d=#{@date}&tt=1&st=bestmatches&at=1&cbm=-1&cbm2=-1&sc=7&px=1&taxng=1&idx=1"
        page.find('.language-region-change').click if page.all('.language-region-change').size > 0
        page.find('.flight-result-list')
        # puts page.all('.col-header-content')[1].text
        # sleep 1.5
        # page.save_screenshot('error.png')
        page.all('.col-header-content')[1].trigger('click')
        sleep 2
        page.all('.flight-block.flight-block-fares').each do |fare|
          depart_date = fare.find('.flight-time.flight-time-depart .date-duration').text if fare.all('.flight-time.flight-time-depart .date-duration').size > 0
          depart_time = fare.find('.flight-time.flight-time-depart').text.scan(/(\d+:\d+ am)|(\d+:\d+ pm)/).flatten.compact.first
          origin = fare.find('.airport-code.origin-airport-mismatch-code').text if fare.all('.airport-code.origin-airport-mismatch-code').size > 0
          arrive_date = fare.find('.flight-time.flight-time-arrive .date-duration').text if fare.all('.flight-time.flight-time-arrive .date-duration').size > 0
          arrive_time = fare.find('.flight-time.flight-time-arrive').text.scan(/(\d+:\d+ am)|(\d+:\d+ pm)/).flatten.compact.first
          destination = fare.find('.airport-code.destination-airport-mismatch-code').text if fare.all('.airport-code.destination-airport-mismatch-code').size > 0
          connection = if fare.find('.connection-count').text == '1 stop'
              fare.find('.toggle-flight-block-details').click
              stops_info = fare.all('.ui-state-default.ui-corner-top')[1]['data-seat-select']
              stops = '1 stop'
              stop_time = fare.find('.width-restrictor span').text.gsub('connection','').strip
              {stops_info: JSON.parse(stops_info), stops: stops, stop_time: stop_time}
            else
              fare.find('.connection-count').text
            end

          duration = fare.find('.flight-duration.otp-tooltip-trigger').text

          economy = if fare.all('#product_MIN-ECONOMY-SURP-OR-DISP').size > 0
              base_price = fare.find('#product_MIN-ECONOMY-SURP-OR-DISP .pp-base-price').text
              additional_fare = fare.find('#product_MIN-ECONOMY-SURP-OR-DISP .pp-additional-fare').text
              {base_price: base_price, additional_fare: additional_fare}
            else
              'Not Available'
            end
          business_saver = if fare.all('#product_BUSINESS-SURPLUS').size > 0
              base_price = fare.find('#product_BUSINESS-SURPLUS .pp-base-price').text
              additional_fare = fare.find('#product_BUSINESS-SURPLUS .pp-additional-fare').text
              {base_price: base_price, additional_fare: additional_fare}
            else
              'Not Available'
            end
          business = if fare.all('#product_BUSINESS-DISPLACEMENT').size > 0
              base_price = fare.find('#product_BUSINESS-DISPLACEMENT .pp-base-price').text
              additional_fare = fare.find('#product_BUSINESS-DISPLACEMENT .pp-additional-fare').text
              {base_price: base_price, additional_fare: additional_fare}
            else
              'Not Available'
            end
          first_saver = if fare.all('#product_FIRST-SURPLUS').size > 0
              base_price = fare.find('#product_FIRST-SURPLUS .pp-base-price').text
              additional_fare = fare.find('#product_FIRST-SURPLUS .pp-additional-fare').text
              {base_price: base_price, additional_fare: additional_fare}
            else
              'Not Available'
            end
          first = if fare.all('#product_FIRST-DISPLACEMENT').size > 0
              base_price = fare.find('#product_FIRST-DISPLACEMENT .pp-base-price').text
              additional_fare = fare.find('#product_FIRST-DISPLACEMENT .pp-additional-fare').text
              {base_price: base_price, additional_fare: additional_fare}
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
        rescue Exception => e
          puts e.message
          puts e.backtrace.inspect
          retry
        end
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
