#!/usr/bin/ruby

# removes the first n values from a CSV file
n = 5A

$stdin.each { |line|
  if line =~ /(.*?,){#{n}}(.*)/
		puts $2
	end
}