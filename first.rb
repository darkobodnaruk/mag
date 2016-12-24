# run with irb

require 'rubygems'
require_gem 'activerecord'
require 'pp'

class EurUsd < ActiveRecord::Base
	set_table_name "eurusd_raw"
end
ActiveRecord::Base.establish_connection(:adapter => 'mysql', :database => 'magisterij', :username => 'root')

# retrieve
first_ten = EurUsd.find :all, :limit => 10  
pp first_ten

#sort
first_ten[0].dt.class
pp first_ten.sort{|a,b| b.dt <=> a.dt}
