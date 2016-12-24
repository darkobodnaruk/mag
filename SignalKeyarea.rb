class SignalKeyarea
	def initialize
		@price_histogram = {}
		@price_histogram_topx = {}
	end
	
	# bs:												bucket size
	# ap: 											aging parameter
	# @price_histogram: 				hash with param_pair => (hash with bucket => price frequency)
	# @price_histogram_topx:	hash with param_pair => two-value array containing [bucket, price frequency]
	# buffer: 									main buffer with OHLC prices
	#
	# TBD: why am I using a two-value array instead of a hash (which *can* be sorted), again?
	def calculate (bs, ap, buffer)
		pair_key = "#{bs}-#{ap}"
		@price_histogram[pair_key] = {} if !@price_histogram[pair_key]
		@price_histogram_topx[pair_key] = [] if !@price_histogram_topx[pair_key]
		
	  # age histograms
	  @price_histogram[pair_key].each do |k,v|
	  	@price_histogram[pair_key][k] = v * ap
	  end
	  # age histograms in top10 list
	  @price_histogram_topx[pair_key].each do |t|
	  	t[1] = t[1] * ap
	  end
	  	
	  # calculate which bucket in the histogram the price belongs to
	  bucket = (buffer[P].close / bs).to_i * bs
	  # increase the bucket counter
	  @price_histogram[pair_key][bucket] = (@price_histogram[pair_key][bucket] ?  @price_histogram[pair_key][bucket] : 0) + 1
		# if the bucket belongs to the top10 list, increase the counter there too
		corrected = false
		@price_histogram_topx[pair_key].each do |t|
			if t[0] == bucket
				t[1] = @price_histogram[pair_key][bucket]
				corrected = true
				break
			end
		end
		
		# add the bucket to the top 10 (if we haven't increased an existing one)
		if !corrected
			@price_histogram_topx[pair_key].push([bucket,@price_histogram[pair_key][bucket]])
		end
		# re-sort the top10 prices by counter
		@price_histogram_topx[pair_key] = @price_histogram_topx[pair_key].sort_by { |k| -1 * k[1] }
		# chop off the last element to keep top10 array at the right length
		if @price_histogram_topx[pair_key].count > 10
			@price_histogram_topx[pair_key].pop
		end
		
		# is there a signal? compare current & previous bucket...
		bucket_current = (buffer[P].close / bs).to_i * bs
		bucket_previous = (buffer[P-1].close / bs).to_i * bs
		# ... if exiting a top10 bucket and entering a regular one - we have a signal!
		if bucket_current != bucket_previous && @price_histogram_topx[pair_key].map{ |t| t[0] }.include?(bucket_previous) && !@price_histogram_topx[pair_key].map{ |t| t[0] }.include?(bucket_current)
			if bucket_current > bucket_previous
				return "b"
			else
				return "s"
			end
		else
			return "h"
		end
	end
	
end