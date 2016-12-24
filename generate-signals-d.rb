#!/usr/bin/ruby

require "yaml"
require "pp"
require "Sample" 
require "signal-params-e"
require "SignalKeyarea"

# enable calculation of signals
ENABLE_MA 			= true
ENABLE_LMA 			= true
ENABLE_RSI 			= true
ENABLE_ROC 			= true
ENABLE_KEYAREA 	= true

# config file
conf = YAML.load_file('config.yaml')

t1 = Time.now

# check arguments
if ARGV.length < 2
  puts "Usage: generate-signals.rb infile outfile [-y] [-d] [-prices]"
  exit
else
  infile = ARGV[0]
  outfile = ARGV[1] #|| "out.csv"  
end

# check for existence of infile
if !File.exists?(infile)
  puts "#{infile} doesn't exist."
  exit
end

# don't override output file without "-y"
if File.exists?(outfile)
  if !ARGV.include?("-y")
    puts "#{outfile} exists, use -y to overwrite."
    exit
  end
end

# check for debug mode
if ARGV.include?("-d")
  Debug = true
  DebugLimit = 50
  puts "debug mode."
else
	Debug = conf["debug"]
	DebugLimit = conf["debugLimit"]
end

# output prices too?
if ARGV.include?("-prices")
  OutputPrices = true
else
	OutputPrices = conf.outputPrices
end

# output arguments
pp ARGV


######################################################################## FUNCTIONS ########################################################################

# calculate_ma()
#   buffer - buffer with previous samples
#   pos - position in buffer, for which we are calculating MA
#   ma_period - MA period
def calculate_ma(buffer, pos, ma_period)
  ma_period_key = ma_period.to_s
  
  # puts "(calculate_ma) #{pos} buffer.size: #{buffer.size}"
  # pp buffer[pos]
  # puts "(calculate_ma) nil?: #{buffer[pos].moving_averages.nil?}"
  
  if !buffer[pos].moving_averages[ma_period_key]
    if buffer[pos-1].moving_averages[ma_period_key]
      # calculate from previous MA (faster)
      buffer[pos].moving_averages[ma_period_key] = buffer[pos - 1].moving_averages[ma_period_key] + (buffer[pos].avg - buffer[pos - ma_period].avg) / ma_period
    else
      # calculate new MA (slower)
      sum = 0
      buffer[pos-ma_period+1..pos].each do |b|
        sum += b.avg
      end
      buffer[pos].moving_averages[ma_period_key] = sum / ma_period
    end
  end
end

# calculate_rsi()
#   buffer - buffer with previous samples
#   pos - position in buffer, from which we are calculating RSI
#   rsi_period - RSI period
def calculate_rsi(buffer, pos, rsi_period)
  rsi_period_key = rsi_period.to_s
  
  if !buffer[pos].rsis[rsi_period_key]
    # calculate new RSI (slower)
    gains = losses = 0
    for i in pos-rsi_period+1..pos
      diff = buffer[i].avg - buffer[i-1].avg
      if diff > 0
        gains += diff
      else
        losses -= diff
      end
    end
    buffer[pos].rsi_avggains[rsi_period_key] = avg_gain = gains / rsi_period
    buffer[pos].rsi_avglosses[rsi_period_key] = avg_loss = losses / rsi_period
    rs = avg_gain/avg_loss
    buffer[pos].rsis[rsi_period_key] = 100 - (100 / (1 + rs))
    
    # puts "(calculate_rsi #{ma_period}) avg_gain #{avg_gain}, avg_loss #{avg_loss}, rs #{rs}, rsi #{buffer[pos].rsis[rsi_period_key]}"
  end
end

# calculate_roc()
#   buffer - buffer with previous samples
#   pos - position in buffer, from which we are calculating ROC
#   roc_period - ROC period
def calculate_roc(buffer, pos, roc_period)
	roc_period_key = roc_period.to_s

	buffer[pos].rocs[roc_period_key] = (buffer[pos].close_bid - buffer[pos - roc_period].close_bid) / buffer[pos - roc_period].close_bid
end


######################################################################## MAIN ########################################################################

#################
# set variables #
#################

#price_histograms = {}
#price_histogram_toptens = {}
keyAreaSignalCalculator = SignalKeyarea.new

buffer = []

header_line = ["datum"]

if OutputPrices
  header_line << %w( open high low close_bid close_ask )
end


##################
# parse file
##################
of = File.new(outfile, "w")
i = 0
puts "Opening #{infile}..."
File.open(infile).each do |line|
  line =~ /(.*),(.*),(.*),(.*),(.*),(.*)/

  # create new sample
  sample = Sample.new
  sample.date = $1
  sample.open = $2.to_f
  sample.high = $3.to_f
  sample.low = $4.to_f
  sample.close_bid = $5.to_f
  sample.close_ask = $6.to_f
  sample.avg = (sample.high + sample.low) / 2

  # add to buffer
  buffer << sample

  # if buffer not full yet, continue
  if buffer.size < HISTORY_LENGTH + LOOKAHEAD_LENGTHS[-1] + 1
    i += 1
    next
  end
  
  # remove first
  buffer.shift
  
  if ENABLE_MA
	  # calculate MAs and MA cross signals
	  pair = 0
	  MA_LONG_PERIODS.each do |l|
	    MA_SHORT_PERIODS.each do |s|
	      # puts "l=#{l} s=#{s}"
	      next if l <= s
	      
	      calculate_ma(buffer, P, l)
	      calculate_ma(buffer, P, s)
	      
	      l_key = l.to_s
	      s_key = s.to_s
	      
	      # generate MA signals
	      begin 
	        if buffer[P].moving_averages[s_key] - buffer[P].moving_averages[l_key] < ((-1) * MACROSS_CROSS_TOLERANCE) &&
	           buffer[P - MACROSS_LOOKBACK_PERIOD].moving_averages[s_key] - buffer[P - MACROSS_LOOKBACK_PERIOD].moving_averages[l_key] > MACROSS_NONCROSS_DISTANCE
	           
	          buffer[P].signals_ma[pair] = "b"
	          
	        elsif buffer[P].moving_averages[s_key] - buffer[P].moving_averages[l_key] > MACROSS_CROSS_TOLERANCE &&
	              buffer[P - MACROSS_LOOKBACK_PERIOD].moving_averages[s_key] - buffer[P - MACROSS_LOOKBACK_PERIOD].moving_averages[l_key] < ((-1) * MACROSS_NONCROSS_DISTANCE)
	              
	          buffer[P].signals_ma[pair] = "s"
	          
	        else
	          buffer[P].signals_ma[pair] = "h"
	        end
	      rescue Exception => e
	        puts "Exception (MA): " + e.to_s  
	        buffer[P].signals_ma[pair] = "?"
	      end
	      
	      if header_line
	        mapair_key = s_key + "-" + l_key
	        header_line << "ma-sig-#{mapair_key}"
	      end
	      
	      pair += 1
	    end
	  end
	end
  
  # calculate MAs and MA cross signals
  if ENABLE_LMA
	  pair = 0
	  MA_LONG_PERIODS.each do |l|
	    MA_SHORT_PERIODS.each do |s|
	      # puts "l=#{l} s=#{s}"
	      next if l <= s
	      
		# no need to recalculate, same long&short periods
		if !ENABLE_MA
			calculate_ma(buffer, P, l)
			calculate_ma(buffer, P, s)
		end
	      
	      l_key = l.to_s
	      s_key = s.to_s
	        
	      # generate LastingMA signals
	      begin 
	        if buffer[P].moving_averages[s_key] > buffer[P].moving_averages[l_key]
	          buffer[P].signals_lma[pair] = "b"
	        elsif buffer[P].moving_averages[s_key] < buffer[P].moving_averages[l_key]
	          buffer[P].signals_lma[pair] = "s"
	        end
	      rescue Exception => e
	        puts "Exception (MA): " + e.to_s  
	        buffer[P].signals_lma[pair] = "?"
	      end
	      
	      if header_line
	        mapair_key = s_key + "-" + l_key
	        header_line << "lma-sig-#{mapair_key}"
	      end
	      
	      pair += 1
	    end
	  end
  end
  
  # generate RSI signals
  if ENABLE_RSI
	  pair = 0
	  RSI_LENGTHS.each do |l|
	    RSI_SIGNAL_BAND_WIDTHS.each do |bw|
	      
	      calculate_rsi(buffer, P, l)
	      
	      l_key = l.to_s
	      
	      begin
	        if buffer[P].rsis[l_key] < bw
	          buffer[P].signals_rsi[pair] = "b"
	        elsif buffer[P].rsis[l_key] > (100 - bw)
	          buffer[P].signals_rsi[pair] = "s"
	        else
	          buffer[P].signals_rsi[pair] = "h"
	        end
	#      rescue Exception => e
	#        puts e.to_s
	#        buffer[P].signals_rsi[pair] = "?"
	      end
	      
	      if header_line
	        rsipair_key = l.to_s + "-" + bw.to_s
	        header_line << "rsi-sig-#{rsipair_key}"
	      end
	      
	      pair += 1
	    end
	  end
	end
  
  # calculate ROCs and ROC signals
  if ENABLE_ROC
	  pair = 0
	  ROC_LENGTHS.each do |l|
	  	calculate_roc(buffer, P, l)
	  	l_key = l.to_s
	
			begin
				if buffer[P].rocs[l_key] < ROC_CROSS_TOLERANCE && buffer[P].rocs[l_key] > (-1) * ROC_CROSS_TOLERANCE 
					if buffer[P - ROC_LOOKBACK_PERIOD].rocs[l_key] > ROC_NOCROSS_DISTANCE
						buffer[P].signals_roc[pair] = "s"
					elsif buffer[P - ROC_LOOKBACK_PERIOD].rocs[l_key] < (-1) * ROC_NOCROSS_DISTANCE
						buffer[P].signals_roc[pair] = "b"
					else
						buffer[P].signals_roc[pair] = "h"
					end
				else
					buffer[P].signals_roc[pair] = "h"
				end
	  	rescue Exception => e
	      puts "Exception (ROC): " + e.to_s  
	      buffer[P].signals_roc[pair] = "?"
	    end
	  	
	    if header_line
	      header_line << "roc#{l_key}"
	    end
	    
	    pair += 1
	  end
  end
  
	# calculate key area signals
  # age price histogram buckets
  if ENABLE_KEYAREA
	  pair = 0
	  PRICE_HISTOGRAM_BUCKET_SIZES.each do |bs|
	  	PRICE_HISTOGRAM_AGING_PARAMETERS.each do |ap|
				pair_key = "#{bs}-#{ap}"			
				
				# calculate the signal
				#buffer[P].signals_keyarea[pair] = calculate_keyarea_signal(bs, ap, price_histograms, price_histogram_toptens, buffer)
				buffer[P].signals_keyarea[pair] = keyAreaSignalCalculator.calculate(bs, ap, buffer)
				
				# if this is the first line, output the header
			  if header_line
			    header_line << "ka#{pair_key}"
			  end
			  
			  # increase counter
			  pair += 1
			end
		end
	end



  # generate numeric class, no threshold
  #buffer[P].numklass1 = sprintf("%.04f", buffer[P + 1].avg - buffer[P].avg)
  #buffer[P].numklass2 = sprintf("%.04f", buffer[P + 2].avg - buffer[P].avg)
  #buffer[P].numklass3 = sprintf("%.04f", buffer[P + 3].avg - buffer[P].avg)
  #buffer[P].numklass4 = sprintf("%.04f", buffer[P + 4].avg - buffer[P].avg)
  #buffer[P].numklass5 = sprintf("%.04f", buffer[P + 5].avg - buffer[P].avg)
  
  LOOKAHEAD_LENGTHS.each do |l|
	if buffer[P + 1].avg - buffer[P].avg > 0
	  buffer[P].numklass[l.to_s] = sprintf("%.04f", buffer[P + l].close_bid - buffer[P].close_ask)
	else
	  buffer[P].numklass[l.to_s] = sprintf("%.04f", buffer[P + l].close_ask - buffer[P].close_bid)
	end
  end
  
#  if buffer[P + 1].avg - buffer[P].avg > 0
#	buffer[P].numklass1 = sprintf("%.04f", buffer[P + 1].close_bid - buffer[P].close_ask)
#  else
#	buffer[P].numklass1 = sprintf("%.04f", buffer[P + 1].close_ask - buffer[P].close_bid)
#  end
#  if buffer[P + 2].avg - buffer[P].avg > 0
#	buffer[P].numklass2 = sprintf("%.04f", buffer[P + 2].close_bid - buffer[P].close_ask)
#  else
#	buffer[P].numklass2 = sprintf("%.04f", buffer[P + 2].close_ask - buffer[P].close_bid)
#  end
#  if buffer[P + 3].avg - buffer[P].avg > 0
#	buffer[P].numklass3 = sprintf("%.04f", buffer[P + 3].close_bid - buffer[P].close_ask)
#  else
#	buffer[P].numklass3 = sprintf("%.04f", buffer[P + 3].close_ask - buffer[P].close_bid)
#    end
#  if buffer[P + 4].avg - buffer[P].avg > 0
#	buffer[P].numklass4 = sprintf("%.04f", buffer[P + 4].close_bid - buffer[P].close_ask)
#  else
#	buffer[P].numklass4 = sprintf("%.04f", buffer[P + 4].close_ask - buffer[P].close_bid)
#  end
#  if buffer[P + 5].avg - buffer[P].avg > 0
#	buffer[P].numklass5 = sprintf("%.04f", buffer[P + 5].close_bid - buffer[P].close_ask)
#  else
#	buffer[P].numklass5 = sprintf("%.04f", buffer[P + 5].close_ask - buffer[P].close_bid)
#  end



    
    
  # output header line to results
  if header_line
    of << header_line.join(",")
    LOOKAHEAD_LENGTHS.each do |l|
	  of << ','
	  of << 'numclass' + l.to_s
	end
    #of << ","
    #of << "numclass1"
    #of << ","
    #of << "numclass2"
    #of << ","
    #of << "numclass3"
    #of << ","
    #of << "numclass4"
    #of << ","
    #of << "numclass5"
    of << "\n"
    header_line = nil
  end
  
  # output every n-th line (for debugging)
  if i % 1000 == 0
    puts "#{i}: #{buffer[P].date}" 
#    puts "signals_ma"
#    pp buffer[P].signals_ma
#    puts "moving_averages"
#    pp buffer[P].moving_averages
#    puts "rsis"
#    pp buffer[P].rsis
#    puts "klass1: #{buffer[P].klass2}"
#    puts "klass2: #{buffer[P].klass2}"
#    puts "klass3: #{buffer[P].klass3}"
#    puts "previous 10 avgs:"
#    10.downto(1) {|c| puts buffer[P-c].date + ":" + buffer[P-c+1].avg.to_s + ","}
    
#  	price_histogram = price_histogram.sort_by { |k,v| k }
#    price_histogram.each do |k,v|
#    	puts "#{k}: #{v}"
#    end
#		puts price_histogram_toptens.count
#		price_histogram_toptens.each do |t|
#			puts t[0].to_s + "/" + t[1].to_s
#		end
    
#    puts
  end
  
  # output for checking against Excel file
  # if buffer[P].signals_ma["5-20"] != 0
  #   puts "#{i}: #{buffer[P].date}"
  #   pp buffer[P].signals_ma
  # end
  
  # debugging limit: stop after n lines
  if Debug && i >= DebugLimit
  	puts "debuglimit"
    break
  end
  
  # output signals, skip first couple of incomplete instances
  of << buffer[P].date
  of << ","
  if OutputPrices
    of << buffer[P].open << ","
    of << buffer[P].high << ","
    of << buffer[P].low << ","
    of << buffer[P].close_bid << ","
    of << buffer[P].close_ask << ","
  end
  of << buffer[P].signals_ma.join(",") << "," if ENABLE_MA
  of << buffer[P].signals_lma.join(",") << "," if ENABLE_LMA
  of << buffer[P].signals_rsi.join(",")<< "," if ENABLE_RSI
  of << buffer[P].signals_roc.join(",")<< "," if ENABLE_ROC
  of << buffer[P].signals_keyarea.join(",") << "," if ENABLE_KEYAREA
#  LOOKAHEAD_LENGTHS.each do |l|
#	of << "#{buffer[P].numklass[l.to_s]}"
#	of << ","
#  end
  of << LOOKAHEAD_LENGTHS.map{ |l| "#{buffer[P].numklass[l.to_s]}" }.join(",")
  #of << "#{buffer[P].numklass1}"
  #of << ","
  #of << "#{buffer[P].numklass2}"
  #of << ","
  #of << "#{buffer[P].numklass3}"
  #of << ","
  #of << "#{buffer[P].numklass4}"
  #of << ","
  #of << "#{buffer[P].numklass5}"        
  of << "\n"
  
  i += 1
  
end #File.open
of.close

puts "running time: " + (Time.now - t1).to_s