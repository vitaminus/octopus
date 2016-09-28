require "octopus/version"
require "octopus/united"
require "octopus/aeroplan"

module Octopus

  def self.take(klass_name, from, to, departure, params=nil)
    return { errors: "Wrong date. Please enter date => #{Time.now.strftime('%F')}" } if DateTime.parse(departure).strftime('%F') < Time.now.strftime('%F')
    begin
      const_get(klass_name.capitalize).new(from, to, departure).get_data
    rescue Exception => e
      puts e.message
      return { message: "#{klass_name.capitalize} currently switched off." }
    end
  end

end
