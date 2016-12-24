#!/usr/bin/ruby

t1 = Time.now

indir = "1-summarized"
outdir = "testdata"
crosses = %w{GBPUSD USDCAD USDCHF USDJPY EURUSD}
#crosses = %w{USDCHF}
resolutions = %w{240 60 30 15 5 1}

resolutions.each do |resolution|
	crosses.each do |cross|
		command = "ruby generate-signals-d.rb #{indir}/out-#{cross}-#{resolution}-bidask.csv #{outdir}/#{cross}-#{resolution}-signals.csv -prices"
		puts command
		system command
	end
end

puts "running time: " + (Time.now - t1).to_s