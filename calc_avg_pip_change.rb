#!/usr/bin/env ruby

if ARGV.length < 2
    puts 'Usage: calc_avg_pip_change.rb infile num_lines'
    exit
else
    infile = ARGV[0]
    num_lines = ARGV[1].to_i
end

i = 0
total = 0
previous_avg = nil

File.open(infile).each do |line|
  line =~ /(.*?),(.*?),(.*?),(.*?),(.*?),(.*?),/

  i += 1

  if i == 1
    # skip header line
    next
  end
  
  if i == 2
    # calc avg & skip change calculation
    avg = ($5.to_f + $6.to_f) / 2
    previous_avg = avg
    next
  end
  
  avg = ($5.to_f + $6.to_f) / 2  
  chg = avg - previous_avg
  #puts "#{i}: #{avg} - #{previous_avg} = #{chg}"
  chg = chg * 10000
  chg = -1 * chg if chg < 0
  total += chg
  
  previous_avg = avg

  if i > num_lines
    puts 'avg change: ' + format('%.1f', total / i)
    exit
  end
  
end
