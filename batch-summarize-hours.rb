#!/usr/bin/ruby

indir = "/cygdrive/d/magdata"
outdir = "1-summarized-hourly"
crosses = %w{EURUSD GBPUSD USDCAD USDCHF USDJPY}
resolutions = %w{1 2 4 8 12 24}

crosses.each do |cross|
	resolutions.each do |resolution|
		command = "ruby summarize-hours.rb #{resolution} #{indir}/#{cross}.csv #{outdir}/out-#{cross}-#{resolution.to_i*60}.csv"
		puts command
		system command
	end
end
	