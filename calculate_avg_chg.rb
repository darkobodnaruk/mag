#!/usr/bin/ruby

def calculate_avg_chg(infile, training_window_size, horizon)
    previous_closes = []
    i = 0
    calculate_avg_chg = 0
    
    File.open(infile).each do |line|
        arr = line.split(',')
        
        datum 		= arr[0]
        open 		= arr[1].to_f
        high 		= arr[2].to_f
        low 		= arr[3].to_f
        close_bid   = arr[4].to_f
        close_ask   = arr[5].to_f
        
        # if first line, output the column we will be checking
        if arr[0] == "datum" 	
            $headers = arr
            next
        end
        
        # calculate average change in close_bid between periods through the first training window size - this is the basis for stop loss size
        if i < training_window_size + 1
            
            if previous_closes.size == horizon
                chg = close_bid - previous_closes[0]
                chg = -1 * chg if chg < 0
                calculate_avg_chg = calculate_avg_chg + chg / (training_window_size - horizon)
                
                previous_closes.shift
            end
            
            previous_closes << close_bid
            
            i += 1
            next 
        end
        
    end
    
    calculate_avg_chg
end