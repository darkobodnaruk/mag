#!/usr/bin/ruby

require "yaml"
require "signal_params"

# check arguments
if ARGV.length < 1
  puts "Usage: simulate_trading.rb infile"
  exit
else
  infile = ARGV[0]
end

# method to check signals
def signal_active?(attributes, buy_signals, sell_signals)
	buys = sells = 0
#	buy_signals.map{|k,v| $headers.index(k)}.each do |sig|
#		buys += 1 if attributes[sig] == v
#	end
	buy_signals.each do |k,v|								# for each signal:
		index = $headers.index(k)								# get column number of attribute by name
		buys += 1 if attributes[index] == v			# if value of attribute equals value in signal that's a buy
	end
	
#	sell_signals.map{|k,v| $headers.index(k)}.each do |sig|
#		sells += 1 if attributes[sig] == v
#	end
	sell_signals.each do |k,v|
		index = $headers.index(k)
		sells += 1 if attributes[index] == v
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

# method to check signals
def signal_active_jrip?(attributes, buy_signals, sell_signals)
	buys = sells = 0

	signals.each do |num, ruleset|
		ruleset.each do |rule|
			rule[:parts].each do |part|
				attr = part[0]
				value = part[1]
				index = $headers.index(attr)
				if attributes[index] == value
					if rule[:predicted] == "up"
						buys += 1
						break 
					elsif rule[:predicted] == "down"
						sells += 1
						break
					end
				end
			end
		end
	end
	
#	buy_signals.each do |k,v|
#		index = $headers.index(k)
#		buys += 1 if attributes[index] == v
#	end
	
	sell_signals.each do |k,v|
		index = $headers.index(k)
		sells += 1 if attributes[index] == v
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
trade_direction = 0
total_gain = 0
total_gain_history = []
min_total_gain = 0
max_total_gain = 0
trades_won = 0
trades_lost = 0
total_won_gain = 0
total_lost_gain = 0
stops_hit = 0
i = 0
t = 0

# parameters
stop_loss_amount = FUTURE_MOVE_THRESHOLD_2 / 2

# include file specifying which signals to use and on which lines to simulate
# what data to use
line_from = 5000
line_to = 9999

# names of signals to use
buy_signals = {"ka0.002-0.99" => "b", "rsi-sig-20-20" => "s", "ka0.001-0.98" => "s"}
sell_signals = {"ka0.002-0.99" => "s", "ka0.001-0.99" => "s", "ma-sig-5-20" => "b", "rsi-sig-10-5" => "s"}

entry = nil
$headers = nil

File.open(infile).each do |line|
  arr = line.split(",")
  
  # if first line, output the column we will be checking
  if arr[0] == "datum" 	
  
#  	buy_signals.each do |sig|
#  		buy_signal_indices.push(arr.index(sig)) if arr.index(sig)
#  	end
#  	sell_signals.each do |sig|
#  		sell_signal_indices.push(arr.index(sig)) if arr.index(sig)
#  	end
#  	
#  	buy_signal_indices.each {|index| puts index}
#  	sell_signal_indices.each {|index| puts index}

		$headers = arr
		
  	next
  end
  
  # confine within range
  if i < line_from
  	i += 1
  	next 
  end
  if i > line_to
  	break
  end
  
  datum = arr[0]
  close = last = arr[4].to_f
  open = arr[1].to_f
  high = arr[2].to_f
  low = arr[3].to_f
  rsisig = arr[11]

	# if not in a trade
  if !intrade
  	# do we have a signal to enter a long/short trade?
    if signal_active?(arr, buy_signals, sell_signals) == "buy"            # enter a trade (long position)
      entry = close
      intrade = true
      trade_direction = 1
      counter = LOOKAHEAD_LENGTH
      puts "#{i}: #{datum} Entering long trade @" + close.to_s
		  t = t + 1
		elsif signal_active?(arr, buy_signals, sell_signals) == "sell"       	# enter a trade (short position)
      entry = close
      intrade = true
      trade_direction = -1
      counter = LOOKAHEAD_LENGTH
      puts "#{i}: #{datum} Entering short trade @" + close.to_s
		  t = t + 1
		else
			# do nothing
		  #puts "."
	  end	  

  else # in a trade
    counter = counter - 1

		# calculate gain in pips
		gain = 10000 * (close - entry) * trade_direction      			

		# has stop loss been breached?
		if (trade_direction == 1) && (entry - low > stop_loss_amount)
			stop_loss = true 
		elsif (trade_direction == -1) && (high - entry > stop_loss_amount)
			stop_loss = true 
		end
#		puts format("%.4f", entry-low) + " " + format("%.4f", high-entry) + " " + "stop: #{stop_loss}"
	
		# if stop loss breached or max time of trade reached, exit the trade
    if counter <= 0 or stop_loss
      exit = close
      
      # calculate the gain
      #total_gain += gain
      if stop_loss
      	total_gain -= stop_loss_amount*10000
      else
      	total_gain += gain
      end
      
      min_total_gain = total_gain if total_gain < min_total_gain
      max_total_gain = total_gain if total_gain > max_total_gain
      total_gain_history << [datum, format("%.0f", total_gain)]
      
      if stop_loss
      	puts "#{i}: #{datum} Closing trade STOP-LOSS " + format("%.0f", stop_loss_amount*-10000) + ", total_gain: " + format("%.0f", total_gain)
      else
      	puts "#{i}: #{datum} Closing trade @" + exit.to_s + ", gain: " + format("%.0f", gain) + ", total_gain: " + format("%.0f", total_gain)
      end
      
      # counters
      stops_hit += 1 if stop_loss
      if gain < 0
      	trades_lost += 1 
      	total_lost_gain += gain
      end
      if gain > 0
      	trades_won += 1
      	total_won_gain += gain
      end
      
      # states
      intrade = false
	  	stop_loss = false
		else
			puts "#{i}: #{datum} gain: " + format("%.0f", gain)
    end
	  
  end
    
  
  # if rsisig = "s"
  #   puts datum + "," + close + "," + rsisig
  # end
  i = i + 1
end

puts
puts "Lines: #{line_from}-#{line_to} (#{i} total)"
puts "Trades won: #{trades_won} / #{t}, avg gain " + format("%.1f", total_won_gain/trades_won)
puts "Trades lost: #{trades_lost} / #{t}, avg gain " + format("%.1f", total_lost_gain/trades_lost)
puts "Stops hit: #{stops_hit}"
puts "Total gain: " + format("%.1f", total_gain) + " [" + format("%.1f", min_total_gain) + "..." + format("%.1f", max_total_gain) + "]"

#puts total_gain_history.map{|k,v| format("%.0f", v)}.join(",")
#total_gain_history.each{|k,v| puts "#{k},#{v}"}

f = File.new("tradecurve#{line_from}-#{line_to}.csv", "w")
total_gain_history.each{|v| f.puts "#{v[0]},#{v[1]}"}
f.close

puts "End."

################

