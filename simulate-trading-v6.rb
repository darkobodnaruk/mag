#!/usr/bin/ruby

require 'yaml'
require 'parse_jrip.rb'
require 'pp'

t1 = Time.now

debug = false
srand

# check arguments
if ARGV.length < 5
  puts "Usage: simulate_trading.rb signals_file jrip_signals_file line_from line_to ex_per_ruleset"
  exit
else
  infile = ARGV[0]
  signals_file_jrip = ARGV[1]
  line_from = ARGV[2].to_i
  line_to = ARGV[3].to_i
  num_examples_per_ruleset = ARGV[4].to_i
  
	# include file specifying which signals to use and on which lines to simulate
	# what data to use
	#line_from = 1000
	#line_to = 19999  
  #signals_file_jrip = '../testdata/GBPUSD-60-numclass-only/W-JRip.res'
  #num_examples_per_ruleset = 1000
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
def signal_active_jrip?(attributes, ruleset)
	num_parts_true = 0
	result = nil
	
	ruleset.each do |rule|
		
		if rule[:parts] != []
			# normal rule
			rule[:parts].each do |part|
				attr = part[0]
				value = part[1]
				index = $headers.index(attr)
				num_parts_true += 1 if attributes[index] == value
			end
			if num_parts_true == rule[:parts].size
				result = (rule[:predicted] == 'up') ? "buy" : "sell"
				break
			end
		else		
			result = (rule[:predicted] == 'up') ? "buy" : "sell"
			break
		end
		
	end
	
	return result
	
#	if buys > sells
#		#puts "#{buys} buys"
#		return "buy", buys
#	elsif sells > buys
#		#puts "#{sells} sells"
#		return "sell", sells
#	else
#		return "hold", buys
#	end
end

def signal_active_random?(attributes, ruleset)
	r = rand(3)
	
  if r == 0
    return "buy", 1
  elsif r == 1
  	return "hold", 1
  else
  	return "sell", 1
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
max_drawdown = 0
trades_won = 0
trades_lost = 0
total_won_gain = 0
total_lost_gain = 0
num_buys = 0
num_sells = 0
num_holds = 0
stops_hit = 0
i = 1
t = 0

# parameters
#STOP_LOSS = FUTURE_MOVE_THRESHOLD_2 / 2

STOP_LOSS = 0.0005
LOOKAHEAD_LENGTH = 1


# names of signals to use
#buy_signals = {"ka0.002-0.99" => "b", "rsi-sig-20-20" => "s", "ka0.001-0.98" => "s"}
#sell_signals = {"ka0.002-0.99" => "s", "ka0.001-0.99" => "s", "ma-sig-5-20" => "b", "rsi-sig-10-5" => "s"}
signals = parse_jrip(signals_file_jrip)

entry = nil
$headers = nil

puts "i\tdatum\t\topen\thigh\tlow\tclose_bid\tclose_ask\taction\tgain\ttot_gain\tmax_drawdown"

File.open(infile).each do |line|
  arr = line.split(',')
  
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
  if i > line_to && line_to != -1
  	break
  end
  
  datum = arr[0]
  open = arr[1].to_f
  high = arr[2].to_f
  low = arr[3].to_f
  close_bid = arr[4].to_f
  close_ask = arr[5].to_f
  rsisig = arr[11]
  
  #logline = "#{i};#{datum};#{open};#{high};#{low};#{close}"
  logline = {:i => i, :datum => datum, :open => open, :high => high, :low => low, :close_bid => close_bid, :close_ask => close_ask, :gain => '', :max_drawdown => '0'}
  
  ruleset_num = ((i - 1) / num_examples_per_ruleset).to_s

	# if not in a trade
  if !intrade
  	# do we have a signal to enter a long/short trade?
  	ruleset = signals[ruleset_num]
  	break if ruleset == nil
  	signal = signal_active_jrip?(arr, ruleset)
    
    #debug
    if debug && i == 3500
    	pp signals[ruleset_num]
    	exit
  	end
    #/debug
    
    if signal == "buy"            # enter a trade (long position)
    	num_buys += 1
      entry = close_ask
      intrade = true
      trade_direction = 1
      counter = LOOKAHEAD_LENGTH
    	logline[:action] = 'long'
    	logline[:total_gain] = format("%.0f", total_gain)
		  t = t + 1
		elsif signal == "sell"       	# enter a trade (short position)
			num_sells += 1
      entry = close_bid
      intrade = true
      trade_direction = -1
      counter = LOOKAHEAD_LENGTH
    	logline[:action] = 'short'
    	logline[:total_gain] = format("%.0f", total_gain)
		  t = t + 1
		else
			num_holds += 1
			# do nothing
		  logline[:action] = ''
    	logline[:total_gain] = format("%.0f", total_gain)
	  end

  else # in a trade
    counter = counter - 1

		# calculate gain in pips
		#gain = 10000 * (close - entry) * trade_direction
		if trade_direction == 1
			gain = 10000 * (close_bid - entry)
		else
			gain = 10000 * (entry - close_ask)
		end
		
		# has stop loss been breached?
		if (trade_direction == 1) && (entry - low > STOP_LOSS)
			stop_loss = true 
		elsif (trade_direction == -1) && (high - entry > STOP_LOSS)
			stop_loss = true 
		end
	
		# exit the trade if stop loss breached or time-out
    if counter <= 0 or stop_loss
      #exit = close
      
      # calculate the gain
      if stop_loss
      	total_gain -= STOP_LOSS * 10000
      else
      	total_gain += gain
      end
      
      min_total_gain = total_gain if total_gain < min_total_gain
      max_total_gain = total_gain if total_gain > max_total_gain
      total_gain_history << [datum, format("%.0f", total_gain)]
      
      max_drawdown = (max_total_gain - total_gain) if (max_total_gain - total_gain) > max_drawdown
      logline[:max_drawdown] = format("%.0f", max_drawdown)
      
      if stop_loss
      	logline[:action] = 'stop'
      	logline[:gain] = format("%.0f", STOP_LOSS*-10000)
    		logline[:total_gain] = format("%.0f", total_gain)
      else
      	logline[:action] = 'exit'
      	logline[:gain] = format("%.0f", gain)
    		logline[:total_gain] = format("%.0f", total_gain)
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
      logline[:action] = '.'
      logline[:gain] = format("%.0f", gain)
    	logline[:total_gain] = format("%.0f", total_gain)
    end
	  
  end
 	
 	# output line
  puts logline[:i].to_s + "\t" + logline[:datum].to_s + "\t" \
  			+ logline[:open].to_s + "\t" + logline[:high].to_s + "\t" + logline[:low].to_s \
  			+ "\t" + logline[:close_bid].to_s + "\t" + logline[:close_ask].to_s \
  			+ "\t" + logline[:action] + "\t" + logline[:gain] + "\t" + logline[:total_gain] + "\t" + logline[:max_drawdown]
  
  i = i + 1
end

puts
puts "Lines: #{line_from}-#{line_to} (#{i} total)"
puts "Buys: #{num_buys} Sells: #{num_sells} Holds: #{num_holds}"
puts "Trades won: #{trades_won} / #{t} (" + format("%.0f", 100*trades_won/t) + "%), avg gain " + format("%.1f", total_won_gain/trades_won)
puts "Trades lost: #{trades_lost} / #{t} (" + format("%.0f", 100*trades_lost/t) + "%), avg gain " + format("%.1f", total_lost_gain/trades_lost)
puts "Max drawdown: " + format("%.1f", max_drawdown)
puts "Stops hit: #{stops_hit}"
puts "Total gain: " + format("%.1f", total_gain) + " [" + format("%.1f", min_total_gain) + "..." + format("%.1f", max_total_gain) + "]"

#puts total_gain_history.map{|k,v| format("%.0f", v)}.join(",")
#total_gain_history.each{|k,v| puts "#{k},#{v}"}

f = File.new("tradecurve_#{line_from}_#{line_to}.csv", "w")
total_gain_history.each{|v| f.puts "#{v[0]},#{v[1]}"}
f.close

puts 'End. Running time: ' + (Time.now - t1).to_s

################