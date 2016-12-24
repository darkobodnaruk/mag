#!/usr/bin/ruby

h = {:one => 1, :two => 2, :three => 3}

#h = h.each do |k, v|
#	h[k] = v * 2
#	puts h[k]
#end
#
#h.each do |k, v|
#	puts v
#end

if h.key?(:one)
	puts "one"
end