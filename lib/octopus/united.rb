require 'capybara'
require 'capybara/poltergeist'
require 'capybara/dsl'

module Octopus  
  class United
    include Capybara::DSL
    Capybara.default_driver = :poltergeist
    Capybara.default_max_wait_time = 8

    attr_reader :from, :to, :date
    def initialize(from, to, date)
      @from    = from.upcase
      @to = to.upcase
      @date = date
    end

    def get_data
      visit "https://www.united.com/ual/en/us/flight-search/book-a-flight/results/awd?f=#{@from}&t=#{@to}&d=2016-08-23&tt=1&st=bestmatches&at=1&act=1&cbm=-1&cbm2=-1&sc=7&px=1&taxng=1&idx=1"
      puts page.find('#fl-results')
      # return { state: '4' } unless first('#myalaskaair')
      # within('#myalaskaair') do
      #   fill_in 'FormUserControl$_signInProfile$_userIdControl$_userId', with: @login
      #   fill_in 'FormUserControl$_signInProfile$_passwordControl$_password', with: @password
      #   click_button 'FormUserControl__signIn'
      # end
      # if first(".errorText")
      #   {
      #     state: '2',
      #     message: 'Incorrect login or password',
      #     error_message: first(".errorText").text
      #   }
      # else
      #   points
      # end
    end

  end
end
