#!/usr/bin/ruby

# load some standard stuff
require 'yaml'
require 'pp'
require 'getoptlong'

# load from the same directory as this file
require File.join(File.dirname(__FILE__), 'parse_jrip' )

# config file (from the same directory as this file)
#Config = File.join(File.dirname(__FILE__), 'config.yaml' )


#EXIT_STRATEGY = :trailing_stop_loss
EXIT_STRATEGY = :fixed
TRADE_WITHOUT_COSTS = false

# check command-line arguments
if ARGV.length < 5
    puts "Usage: simulate_trading.rb signals_file jrip_signals_file line_from line_to ex_per_ruleset"
    exit
else
    infile = ARGV[0]
    signals_file_jrip = ARGV[1]
    line_from = ARGV[2].to_i
    line_to = ARGV[3].to_i
    num_examples_per_ruleset = ARGV[4].to_i
    equity_curve_logfile = ARGV[5]
    STOP_LOSS = ARGV[6] ? ARGV[6].to_f : 0.0020
    TRAILING_STOP_LOSS = ARGV[7] ? ARGV[7].to_f : 0.0040
  
    # include file specifying which signals to use and on which lines to simulate
    # what data to use
    #line_from = 1000
    #line_to = 19999  
    #signals_file_jrip = '../testdata/GBPUSD-60-numclass-only/W-JRip.res'
    #num_examples_per_ruleset = 1000
end

#opts = GetoptLong.new(
#    [ '--pricesfile', GetoptLong::REQUIRED_ARGUMENT ],
#    [ '--signalsfile', GetoptLong::REQUIRED_ARGUMENT ],
#    [ '--linefrom', GetoptLong::REQUIRED_ARGUMENT ],
#    [ '--lineto', GetoptLong::REQUIRED_ARGUMENT ],
#    [ '--testwindowsize', GetoptLong::REQUIRED_ARGUMENT ],
#    [ '--stoploss', GetoptLong::REQUIRED_ARGUMENT ],
#    [ '--trailingstoploss', GetoptLong::REQUIRED_ARGUMENT ]
#)
#pp opts
#puts 'ende'
#exit
#
#opts.each do |opt, arg|
#    case opt
#    when '--pricesfile'
#        infile = arg
#        puts arg
#    when '--signalsfile'
#        signals_file_jrip = arg
#        puts arg
#    when '--linefrom'
#        line_from = arg.to_i
#        puts arg
#    when '--lineto'
#        line_to = arg
#        puts arg
#    when 'testwindowsize'
#        num_examples_per_ruleset = arg
#        puts arg
#    when '--stoploss'
#        STOP_LOSS = arg.to_i
#        puts arg
#    when '--trailingstoploss'
#        TRAILING_STOP_LOSS = arg.to_i
#        puts arg
#    end
#end


t1 = Time.now
debug = true
srand

# method to check signals
def signal_active?(attributes, buy_signals, sell_signals)
	buys = sells = 0
	buy_signals.each do |k,v|								# for each signal:
		index = $headers.index(k)								# get column number of attribute by name
		buys += 1 if attributes[index] == v                     # if value of attribute equals value in signal that's a buy
	end
	
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

# method to check signals from JRip classifier
def signal_active_jrip?(attributes, ruleset, debug = false)
	#num_parts_true = 0
	result = nil
	
	ruleset.each do |rule|
		# without this correction it works great :)
		num_parts_true = 0
		
		if rule[:parts] != []
			# normal rule
			rule[:parts].each do |part|
				attr = part[0]
				value = part[1]
				index = $headers.index(attr)
				num_parts_true += 1 if attributes[index] == value
				puts attr + ': ' + value + ' vs ' + attributes[index] if debug
			end
			puts '---' if debug
			if num_parts_true == rule[:parts].size
				result = rule[:predicted]
				puts 'matching rule: ' + rule.pretty_inspect.gsub(/\n/, ' ') if debug
				break
			end
			
		else
            # 'else' rule
			result = rule[:predicted]			
			break
		end
		
	end
	
	return result
	
end

# method to generate random signals (for testing purposes)
def signal_active_random?(attributes, ruleset, debug = false)
	r = rand(3)
	
  if r == 0
    return "buy"
  elsif r == 1
  	return "hold"
  else
  	return "sell"
  end
end

# state variables
intrade = false
stop_loss = false

# counters
gain = 0
trade_direction = 0
total_gain = 0
total_gain_history = []
min_total_gain = 0
max_total_gain = 0
max_drawdown = 0
max_trade_gain = 0
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

# parse the signals file
signals = parse_jrip(signals_file_jrip)

entry = nil
$headers = nil

# header line
puts "i\tdatum\topen\thigh\tlow\tclose_bid\tclose_ask\taction\tgain\ttot_gain\tmax_drawdown"

# work the input file line by line
File.open(infile).each do |line|
    arr = line.split(',')
    
    # if first line, output the column we will be checking
    if arr[0] == "datum" 	
        $headers = arr
        next
    end
    
    # confine within range (for debug purposes)
    if i < line_from
        i += 1
        next 
    end
    
    if i > line_to && line_to != -1
        break
    end
    
    if debug && i % 50 == 1
        debug_line = true
    end
    
    if i % 5000 == 0
        puts i
    end
    
    datum 		= arr[0]
    open 		= arr[1].to_f
    high 		= arr[2].to_f
    low 		= arr[3].to_f
    close_bid   = arr[4].to_f
    close_ask   = arr[5].to_f
    rsisig 		= arr[11]
  
    logline = {:i => i, :datum => datum, :open => open, :high => high, :low => low, :close_bid => close_bid, :close_ask => close_ask, :gain => '', :max_drawdown => '0', :ruleset => ''}
  
    ruleset_num = ((i - line_from) / num_examples_per_ruleset + 1).to_s
	# do we have a signal to enter a long/short trade?
	ruleset = signals[ruleset_num]
	if ruleset == nil
        puts 'Out of rules at ruleset_num ' + ruleset_num + '!'
        break
	end
	
	# calculate trading signal on current attributes
    #signal = signal_active_jrip?(arr, ruleset, debug_line)
	#signal = signal_active_jrip?(arr, ruleset, false)
	signal = signal_active_random?(arr, ruleset, false)

    if debug_line
        logline[:ruleset] = ruleset.pretty_inspect.gsub(/\n/, ' ') + "\t" + arr.to_s
        #pp ruleset
    end

    # if not in a trade
    if !intrade
        #debug
        #if debug && i == 3500
        #    pp signals[ruleset_num]
        #    exit
        #end
        #/debug
        
        if signal == 'buy'            # enter a trade (long position)
            num_buys += 1
            entry = TRADE_WITHOUT_COSTS ? (close_bid + close_ask) / 2 : close_ask
            intrade = true
            trade_direction = 1
            max_trade_gain = 0
            logline[:action] = signal
            logline[:total_gain] = format('%.0f', total_gain * 10000)
            t = t + 1
        elsif signal == 'sell'       	# enter a trade (short position)
            num_sells += 1
            entry = TRADE_WITHOUT_COSTS ? (close_bid + close_ask) / 2 : close_bid
            intrade = true
            trade_direction = -1
            max_trade_gain = 0
            logline[:action] = signal
            logline[:total_gain] = format('%.0f', total_gain * 10000)
            t = t + 1
        else
            num_holds += 1
            # do nothing
            logline[:action] = ''
            logline[:total_gain] = format('%.0f', total_gain * 10000)
        end
        
    else # in a trade
        
        if EXIT_STRATEGY == :trailing_stop_loss
            
            # Exit strategy 1: exit on stop, trailing stop or signal reversal
            # calculate gain and possible stop loss breaches
            previous_gain = gain
            stop_loss = trailing_stop_loss = signal_reversal = false
            
            if trade_direction == 1
                gain = (TRADE_WITHOUT_COSTS ? (close_bid + close_ask) / 2 : close_bid) - entry
                trailing_stop_loss = true if low < (entry + max_trade_gain - TRAILING_STOP_LOSS)
                stop_loss = true if (entry - low) > STOP_LOSS
                signal_reversal = true if signal == 'sell'
            else
                gain = entry - (TRADE_WITHOUT_COSTS ? (close_bid + close_ask) / 2 : close_ask)
                trailing_stop_loss = true if high > (entry - max_trade_gain + TRAILING_STOP_LOSS)
                stop_loss = true if (high - entry) > STOP_LOSS
                signal_reversal = true if signal == 'buy'
            end
            
            # exit the trade if (trailing) stop loss breached or signal is reversed
            if stop_loss || trailing_stop_loss || signal_reversal
                
                # add gain to total gain
                if stop_loss && trailing_stop_loss
                    if -1 * STOP_LOSS > max_trade_gain - TRAILING_STOP_LOSS
                        total_gain -= STOP_LOSS
                    else
                        total_gain += max_trade_gain - TRAILING_STOP_LOSS
                    end
                elsif stop_loss
                    total_gain -= STOP_LOSS
                elsif trailing_stop_loss
                    total_gain += max_trade_gain - TRAILING_STOP_LOSS
                elsif signal_reversal
                    total_gain += gain
                end
                
                min_total_gain = total_gain if total_gain < min_total_gain
                max_total_gain = total_gain if total_gain > max_total_gain
                total_gain_history << [datum, format('%.0f', total_gain * 10000)]
                
                max_drawdown = (max_total_gain - total_gain) if (max_total_gain - total_gain) > max_drawdown
                logline[:max_drawdown] = format('%.0f', max_drawdown)
              
                if stop_loss
                    logline[:action] = 'stop'
                    logline[:gain] = format('%.0f', STOP_LOSS*-10000)
                    logline[:total_gain] = format('%.0f', total_gain * 10000)
                elsif trailing_stop_loss
                    logline[:action] = 'trstop:' + format('%.0f', max_trade_gain*10000)
                    logline[:gain] = format('%.0f', gain*10000)
                    logline[:total_gain] = format('%.0f', total_gain * 10000)    	
                else
                    logline[:action] = 'exit'
                    logline[:gain] = format('%.0f', gain*10000)
                    logline[:total_gain] = format('%.0f', total_gain * 10000)
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
                max_trade_gain = gain if gain > max_trade_gain
                logline[:action] = '||' + signal[0..0]
                logline[:gain] = format('%.0f', gain*10000)
                logline[:total_gain] = format('%.0f', total_gain * 10000)
            end
            # End of exit strategy 1
            
        elsif EXIT_STRATEGY == :fixed
            
            # Exit strategy 2: exit immediately (hold period == 1)
            if trade_direction == 1
                gain = close_bid - entry
            else
                gain = entry - close_ask
            end
            
            total_gain += gain
            if gain < 0
                trades_lost += 1 
                total_lost_gain += gain
            end
            if gain > 0
                trades_won += 1
                total_won_gain += gain
            end
            
            min_total_gain = total_gain if total_gain < min_total_gain
            max_total_gain = total_gain if total_gain > max_total_gain
            total_gain_history << [datum, format('%.0f', total_gain * 10000)]
            
            # states
            intrade = false
            
            logline[:action] = 'exit'
            logline[:gain] = format('%.0f', gain*10000)
            logline[:total_gain] = format('%.0f', total_gain * 10000)
            # End of exit strategy 2
        end
    end
 	
    # output line
    puts logline[:i].to_s + "\t" + logline[:datum].to_s + "\t" \
        + logline[:open].to_s + "\t" + logline[:high].to_s + "\t" + logline[:low].to_s \
        + "\t" + logline[:close_bid].to_s + "\t" + logline[:close_ask].to_s \
        + "\t" + logline[:action] + "\t" + logline[:gain] + "\t" + logline[:total_gain] + "\t" + logline[:max_drawdown] \
        + "\t" + logline[:ruleset]
    
    i = i + 1
end

puts
puts "Lines: #{line_from}-#{line_to} (#{i} total)"
puts "Buys: #{num_buys} Sells: #{num_sells} Holds: #{num_holds}"
puts "Trades won: #{trades_won} / #{t} (" + format('%.0f', 100 * trades_won / t) + "%), avg gain " + format("%.1f", total_won_gain * 10000 / trades_won)
puts "Trades lost: #{trades_lost} / #{t} (" + format('%.0f', 100 * trades_lost / t) + "%), avg gain " + format("%.1f", total_lost_gain * 10000 / trades_lost)
puts "Max drawdown: " + format('%.0f', max_drawdown*10000)
puts "Stops hit: #{stops_hit}"
puts "Total gain: " + format('%.0f', total_gain * 10000) + " [" + format('%.0f', min_total_gain * 10000) + "..." + format('%.0f', max_total_gain * 10000) + "]"

f = File.new(equity_curve_logfile, "w")
total_gain_history.each{|v| f.puts "#{v[0]},#{v[1]}"}
f.close

puts
puts 'End. Running time: ' + (Time.now - t1).to_s
#puts 7.chr

################