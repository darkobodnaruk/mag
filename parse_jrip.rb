#!/usr/bin/ruby

require 'pp'

def parse_jrip(filename)
	alltext = File.open(filename).read
	rulesets = alltext.scan(/Results of ResultWriter 'ResultWriter'.*?Number of Rules : \d*/m)
	signals = {}
	rulesets.each do |ruleset|
		num = ruleset.match(/Results of ResultWriter 'ResultWriter' \[(\d.*)\]/)
		num = num[1]
		rules = ruleset.scan(/^(.*?) => (.*?)=(.*) \((.*?)\/(.*?)\)/)
		
		signals[num] = []
		
		rules.each do |rule|
			conditions = rule[0]
			
			condition_parts = conditions.scan(/\((.*?) = (.*?)\)/)
			rule = { :parts => nil, :predicted => rule[2], :num_all => rule[3], :num_correct => rule[4] }
			rule[:parts] = condition_parts
			signals[num] << rule
		end
		
#		puts "dare"
#		pp rules
#		exit
	end
	
	return signals
end

#require 'pp'
#
#if ARGV.length < 1
#  puts "Usage: simulate_trading.rb infile"
#  exit
#else
#  infile = ARGV[0]
#  pp parse_jrip(infile)
#end