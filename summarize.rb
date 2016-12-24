infile = ARGV[1] || "A787C846D229AD3763DDE3239089E32A.csv"
minute_resolution = ARGV[0] ? ARGV[0].to_i : 5
outfile = ARGV[2] || "output" + Time.now.strftime("-%Y%m%d-%H%M%S") + ".csv"
testbreak = 0

##

of = File.new(outfile, "w")
# of = $stdout

i = 0
period = nil,nil,nil
open = high = low = close = nil
File.open(infile).each do |line|
	# parse
	line =~ /(.*) (\d\d):(\d\d):(\d\d),(.*),(.*)/
	#puts line
	avg_bidask = ($5.to_f + $6.to_f) / 2
	
	
	# close
	close = avg_bidask
	
	current_period = nil,$1,$2,$3

	# diff = (current_period[2].to_i * 60 + current_period[3].to_i) - (period[2].to_i * 60 + period[3].to_i)
	# if diff < 0 || diff > minute_resolution
	# 	of << "diff:" << diff.to_s << "\t\t" << period[1] << " " << period[2] << ":" << period[3] << ":" << $4 << "," << open << "," << high << "," << low << "," << close << "\n"
	# 	period = current_period
	# end

	if period != current_period && current_period[3].to_i % minute_resolution == 0
		of << period[1] << " " << period[2] << ":" << period[3] << ":" << "00" << "," << open << "," << high << "," << low << "," << close << "\n"
		period = current_period
		open = high = low = close = nil
	end

	
	# ohlc
	open = avg_bidask if !open
	high = avg_bidask if !high || avg_bidask > high
	low = avg_bidask if !low || avg_bidask < low
	
			
	# break for testing
	break if testbreak > 0 && i > testbreak
	
	# display some info how far along we are
  puts (i.to_f / 1000000).to_s + "M" if i % 2000000 == 0
  #of.flush
  
  # increment
  i = i+1
end

puts "done"
of.close


