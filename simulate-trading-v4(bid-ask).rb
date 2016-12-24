#!/usr/bin/ruby

require "yaml"
require "signal_params"

def makedate(datestring)
	dd,tt = datestring.split(" ")
	d,m,y = dd.split("/")
	h,min,s = tt.split(":")
	
	d = d.to_i
	m = m.to_i
	y = y.to_i + 2000
	h = h.to_i
	min = min.to_i
	s = s.to_i
	
	return DateTime.civil(y,m,d,h,min,s)
end

# check arguments
if ARGV.length != 2
  puts "Usage: simulate_trading.rb prices-file signals-file"
  exit
else
  pricesfile = ARGV[0]
  signalsfile = ARGV[1]
end

# method to check signals
def signal_active?(attributes, buy_signals, sell_signals)
	buys = sells = 0
	buy_signals.map{|s| $headers.index(s)}.each do |sig|
		buys += 1 if attributes[sig] == "b"
	end
	sell_signals.map{|s| $headers.index(s)}.each do |sig|
		sells += 1 if attributes[sig] == "s"
	end
	if buys > sells
		puts "#{buys} buys"
		return "buy"
	elsif sells > buys
		puts "#{sells} sells"
		return "sell"
	else
		return "hold"
	end
end

# config file
Config = YAML.load_file('config.yaml')

# state variables
intrade = false
stop_loss = false

# counters
counter = 0
trade_exit_time = nil
trade_direction = 0
total_gain = 0
min_total_gain = 0
max_total_gain = 0
trades_won = 0
trades_lost = 0
stops_hit = 0
i = 0
t = 0

# parameters
stop_loss_amount = 30
max_trade_length_in_minutes = 240

# what data to use
line_from = 0
line_to = 200000000

# names of signals to use
buy_signals = %w{ ka0.002-0.99 roc15 }
sell_signals = %w{ ka0.002-0.99 }
buy_signal_indices = []
sell_signal_indices = []

entry = nil
$headers = nil

signals = File.open(signalsfile)
# first line are headers
$headers = signals.readline.split(",")
#puts "headers: #{$headers}"
# second line are first signals
next_signals = signals.readline.split(",")
#puts "nextsigs: #{next_signals}"
#next_signals_date = next_signals[0].to_datetime
#next_signals_date = ParseDate.parsedate(next_signals[0]).to_date
next_signals_date = makedate(next_signals[0])
#puts next_signals[0]
#puts next_signals_date
#exit
ii = 1

File.open(pricesfile).each do |line|
  arr = line.split(",")
  
  # if first line, save array of column names
#  if arr[0] == "datum" 	
#		$headers = arr
#  	next
#  end
 
  # confine within range
  if i < line_from
  	i += 1
  	next 
  end
  if i > line_to  
  	i += 1
  	next 
  end
  
  datum = makedate(arr[0])
  bid = arr[1].to_f
  ask = arr[2].to_f
  #close = last = arr[4].to_f

	# debugging
	if i % 10000 == 0
		puts "i:#{i} ii:#{ii} datum:#{datum} next_signals_date:#{next_signals_date}"
	end


	# always be waiting for the next signal: if date in pricesfile > date in signals_file, advance signals_file
	begin
		while datum > next_signals_date
			ii += 1
			puts "advancing signals_file to line #{ii}"
			next_signals = signals.readline.split(",")
			next_signals_date = makedate(next_signals[0])
		end
	rescue
		signals.close
	end
  if intrade 	# in a trade
    counter = counter - 1

		# calculate gain in pips
		gain = 10000 * (bid - entry) * trade_direction      			

		# has stop loss been breached?	
		stop_loss = true if gain < -1 * stop_loss_amount
	
		# if stop loss breached or max time of trade reached, exit the trade
    #if counter <= 0 or stop_loss
    if datum >= trade_exit_time or stop_loss
      exit = bid
      
      # calculate the gain
      total_gain += gain
      min_total_gain = total_gain if total_gain < min_total_gain
      max_total_gain = total_gain if total_gain > max_total_gain
      
      puts "#{i}: #{datum} Closing trade @" + exit.to_s + (stop_loss ? " stop loss!" : "") + ", gain:" + format("%.0f", gain) + ", total_gain: " + format("%.0f", total_gain)
      
      # counters
      stops_hit += 1 if stop_loss
      trades_lost += 1 if gain > 0
      trades_won += 1 if gain < 0
      
      # states
      intrade = false
	  	stop_loss = false
		else
			puts "#{i}: #{datum} gain: " + format("%.0f", gain) if i % 1000 == 0
    end
  
  else 	# not in a trade
	  
  	# do we have a signal to enter a long/short trade?
    if datum >= next_signals_date && signal_active?(next_signals, buy_signals, sell_signals) == "buy"     	# enter a trade (long position)
      entry = ask
      intrade = true
      trade_direction = 1
      #counter = LOOKAHEAD_LENGTH
      trade_exit_time = datum + max_trade_length_in_minutes*60
      puts "#{i}: #{datum} Entering long trade @" + ask.to_s
		  t = t + 1
		elsif datum >= next_signals_date && signal_active?(next_signals, buy_signals, sell_signals) == "sell"		# enter a trade (short position)
      entry = ask
      intrade = true
      trade_direction = -1
      #counter = LOOKAHEAD_LENGTH
      trade_exit_time = datum + max_trade_length_in_minutes*60
      puts "#{i}: #{datum} Entering short trade @" + ask.to_s
		  t = t + 1
		else
			# do nothing
		  #puts "."
	  end	  
	  
  end
    
  
  i = i + 1
end

signals.close

puts
puts "Lines: #{line_from}-#{line_to} (#{i} total)"
puts "Trades won: #{trades_won} / #{t}"
puts "Trades lost: #{trades_lost} / #{t}"
puts "Total gain: " + format("%.1f", total_gain) + " [" + format("%.1f", min_total_gain) + "..." + format("%.1f", max_total_gain) + "]"
puts "End."

################

