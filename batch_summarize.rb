indir = "sources"
outdir = "1-summarized"
crosses = %w{EURUSD GBPUSD USDCAD USDCHF USDJPY}
resolutions = %w{1 2 5 10 15 30}

crosses.each do |cross|
	resolutions.each do |resolution|
		command = "ruby summarize.rb #{resolution} #{indir}/#{cross}.csv #{outdir}/out-#{cross}-#{resolution}.csv"
		puts command
		system command
	end
end
	