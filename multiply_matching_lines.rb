#!/usr/bin/ruby

# multiplies each line containing 'term' 'n' times
term = /going/
n = ARGV[0] ? ARGV[0].to_i : 10

$stdin.each { |line|
	if line =~ term
	  1.upto(n) { puts line }
  else
    puts line
	end
}