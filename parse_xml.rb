#http://developer.yahoo.com/ruby/ruby-xml.html

require 'rubygems'
require 'xmlsimple'

xml_data = File.open 'D:\dropbox\My Dropbox\magisterij\testdata\EURUSD-30\W-BFTree_EURUSD30.mod'
data = XmlSimple.xml_in(xml_data)

data['Result'].each do |item|
	
end
