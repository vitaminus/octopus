require 'capybara'
require 'capybara/poltergeist'
require 'capybara/dsl'
require 'json'

module Octopus  
  class Aeroplan
    include Capybara::DSL
    Capybara.register_driver :poltergeist do |app|
      Capybara::Poltergeist::Driver.new(app, window_size: [1920, 1080])
    end
    Capybara.default_driver = :poltergeist
    Capybara.default_max_wait_time = 15

    attr_reader :from, :to, :date, :login, :password
    def initialize(from, to, date, login, password)
      @from    = from.upcase
      @to = to.upcase
      @date = date
      @login = login
      @password = password
    end

    def get_data
      t = Time.now
      data = []
      # begin
      visit "https://www4.aeroplan.com/home.do"
      page.find('.splash-btn-en').click if page.all('.splash-btn-en').size > 0
      sleep 2
      log_in
      puts page.find('span.header-name').text
      
      # click_button 'LOG IN'
      # page.find('.header-login-form-wrapper').trigger('click')# if page.all('.header-login-btn').size > 0
      # sleep 1
      click_link 'FLIGHTS'
      choose 'searchTypeTab_oneway'
      page.fill_in "city1FromOneway", with: @from
      page.fill_in "city1ToOneway", with: @to
      # TODO Сделать что-то с кликом
      # page.find(".inputField").click
      # page.fill_in "l1Oneway", with: @date
      page.select 'Business', from: "l1Oneway"
      page.save_screenshot('aeroplan_after_fill_one_way_form.png')
      # puts page.find('.header-password-help.header-login-text').text
      
      # puts page.all('.col-header-content')[1].text
      sleep 1.5
      # page.save_screenshot('aeroplan_after_login.png')
      #   page.all('.col-header-content')[1].trigger('click')
      #   sleep 2
      #   page.all('.flight-block.flight-block-fares').each do |fare|
      #     depart_date = fare.find('.flight-time.flight-time-depart .date-duration').text if fare.all('.flight-time.flight-time-depart .date-duration').size > 0
      #     depart_time = fare.find('.flight-time.flight-time-depart').text.scan(/(\d+:\d+ am)|(\d+:\d+ pm)/).flatten.compact.first
      #     origin = fare.find('.airport-code.origin-airport-mismatch-code').text if fare.all('.airport-code.origin-airport-mismatch-code').size > 0
      #     arrive_date = fare.find('.flight-time.flight-time-arrive .date-duration').text if fare.all('.flight-time.flight-time-arrive .date-duration').size > 0
      #     arrive_time = fare.find('.flight-time.flight-time-arrive').text.scan(/(\d+:\d+ am)|(\d+:\d+ pm)/).flatten.compact.first
      #     destination = fare.find('.airport-code.destination-airport-mismatch-code').text if fare.all('.airport-code.destination-airport-mismatch-code').size > 0
      #     connection = if fare.find('.connection-count').text == '1 stop'
      #         fare.find('.toggle-flight-block-details').click
      #         stops_info = fare.all('.ui-state-default.ui-corner-top')[1]['data-seat-select']
      #         stops = '1 stop'
      #         stop_time = fare.find('.width-restrictor span').text.gsub('connection','').strip
      #         {stops_info: JSON.parse(stops_info), stops: stops, stop_time: stop_time}
      #       else
      #         fare.find('.connection-count').text
      #       end

      #     duration = fare.find('.flight-duration.otp-tooltip-trigger').text

      #     economy = if fare.all('#product_MIN-ECONOMY-SURP-OR-DISP').size > 0
      #         base_price = fare.find('#product_MIN-ECONOMY-SURP-OR-DISP .pp-base-price').text
      #         additional_fare = fare.find('#product_MIN-ECONOMY-SURP-OR-DISP .pp-additional-fare').text
      #         {base_price: base_price, additional_fare: additional_fare}
      #       else
      #         'Not Available'
      #       end
      #     business_saver = if fare.all('#product_BUSINESS-SURPLUS').size > 0
      #         base_price = fare.find('#product_BUSINESS-SURPLUS .pp-base-price').text
      #         additional_fare = fare.find('#product_BUSINESS-SURPLUS .pp-additional-fare').text
      #         {base_price: base_price, additional_fare: additional_fare}
      #       else
      #         'Not Available'
      #       end
      #     business = if fare.all('#product_BUSINESS-DISPLACEMENT').size > 0
      #         base_price = fare.find('#product_BUSINESS-DISPLACEMENT .pp-base-price').text
      #         additional_fare = fare.find('#product_BUSINESS-DISPLACEMENT .pp-additional-fare').text
      #         {base_price: base_price, additional_fare: additional_fare}
      #       else
      #         'Not Available'
      #       end
      #     first_saver = if fare.all('#product_FIRST-SURPLUS').size > 0
      #         base_price = fare.find('#product_FIRST-SURPLUS .pp-base-price').text
      #         additional_fare = fare.find('#product_FIRST-SURPLUS .pp-additional-fare').text
      #         {base_price: base_price, additional_fare: additional_fare}
      #       else
      #         'Not Available'
      #       end
      #     first = if fare.all('#product_FIRST-DISPLACEMENT').size > 0
      #         base_price = fare.find('#product_FIRST-DISPLACEMENT .pp-base-price').text
      #         additional_fare = fare.find('#product_FIRST-DISPLACEMENT .pp-additional-fare').text
      #         {base_price: base_price, additional_fare: additional_fare}
      #       else
      #         'Not Available'
      #       end
      #     data << {
      #       depart_date: depart_date,
      #       depart_time: depart_time,
      #       origin: origin,
      #       destination: destination,
      #       arrive_date: arrive_date,
      #       arrive_time: arrive_time,
      #       connection: connection,
      #       duration: duration,
      #       economy: economy,
      #       business_saver: business_saver,
      #       business: business,
      #       first_saver: first_saver,
      #       first: first
      #     }
      #   end
      # rescue Exception => e
      #   puts e.message
      #   # puts e.backtrace.inspect
      #   retry
      # end
      

      
      # # page.save_screenshot('end.png')

      Capybara.reset_sessions!
      # data
      # JSON.pretty_generate(data)
      # puts 'End of script'
      puts Time.now - t
    end

    private

      def log_in
        click_button 'LOG IN'
        puts page.find('.header-password-help.header-login-text').text
        page.fill_in 'Aeroplan Number', with: @login
        page.fill_in 'Password', with: @password
        page.find(".form-login-submit").trigger('click')
      end

  end
end
