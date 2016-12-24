#!/usr/bin/ruby

require File.join(File.dirname(__FILE__), 'calculate_avg_chg.rb')

# check command-line arguments
if ARGV.length < 3
    puts "Usage: run_simulation.rb infolder rm4_xml_file horizon"
    exit
else
    infolder = Dir.new(ARGV[0])
    source_rm_xml_filename = ARGV[1]
    horizon_to_use = ARGV[2].to_i
end

$logfile = File.open("run-simulation.log", 'a')
def log(text, output_to_console = false)
    $logfile.puts text
    puts text if output_to_console
end

# const
RAPIDMINER_PATH = '/home/dare/magisterij/rapidminer-4.5/scripts/rapidminer'
SIMULATOR_PATH = '/home/dare/magisterij/simulate-trading-v9.rb'
ALGORITHM = 'W-JRip'

# switches
WRITE_RM4_XML = true
RUN_RAPIDMINER = true
RUN_SIMULATION = true


if ARGV.include?('--demo')
    DEMO = true
else
    DEMO = false
end

# variable stuff
#training_window_size = 1500
#test_window_size = 500
horizons = [1, 2, 3, 4, 5, 10, 20, 40]
#stop_loss = 0.0020
#trailing_stop_loss = 0.0040

datasets = [
    # test
    #{:name => 'EURUSD-60', :training_ws => 2000,  :test_ws => 200, :horizon_to_use => horizon_to_use},
    #{:name => 'GBPUSD-60', :training_ws => 2000,  :test_ws => 200, :horizon_to_use => horizon_to_use},
    #{:name => 'USDCAD-60', :training_ws => 2000,  :test_ws => 200, :horizon_to_use => horizon_to_use},
    #{:name => 'USDCHF-60', :training_ws => 2000,  :test_ws => 200, :horizon_to_use => horizon_to_use},
    
    #{:name => 'EURUSD-240', :training_ws => 500,  :test_ws => 100, :horizon_to_use => horizon_to_use},
    #{:name => 'GBPUSD-240', :training_ws => 1000,  :test_ws => 100, :horizon_to_use => horizon_to_use},
    #{:name => 'USDCAD-240', :training_ws => 1000,  :test_ws => 100, :horizon_to_use => horizon_to_use},
    #{:name => 'USDCHF-240', :training_ws => 1000,  :test_ws => 100, :horizon_to_use => horizon_to_use},
    #{:name => 'USDJPY-240', :training_ws => 2000,  :test_ws => 500,   :horizon_to_use => horizon_to_use},
    
    #{:name => 'EURUSD-60', :training_ws => 2000,  :test_ws => 400, :horizon_to_use => horizon_to_use},
    #{:name => 'GBPUSD-60', :training_ws => 2000,  :test_ws => 500, :horizon_to_use => horizon_to_use},
    #{:name => 'USDCAD-60', :training_ws => 2000,  :test_ws => 500, :horizon_to_use => horizon_to_use},
    #{:name => 'USDCHF-60', :training_ws => 2000,  :test_ws => 500, :horizon_to_use => horizon_to_use},
    #{:name => 'USDJPY-60', :training_ws => 2000,  :test_ws => 400, :horizon_to_use => horizon_to_use},
    
    #{:name => 'EURUSD-30', :training_ws => 2000,  :test_ws => 500,  :horizon_to_use => horizon_to_use},
    #{:name => 'GBPUSD-30', :training_ws => 2000,  :test_ws => 500, :horizon_to_use => horizon_to_use},
    #{:name => 'USDCAD-30', :training_ws => 2000,  :test_ws => 500, :horizon_to_use => horizon_to_use},
    #{:name => 'USDCHF-30', :training_ws => 2000,  :test_ws => 500, :horizon_to_use => horizon_to_use},
    #{:name => 'USDJPY-30', :training_ws => 4000,  :test_ws => 2000, :horizon_to_use => horizon_to_use},
    
    #{:name => 'EURUSD-15', :training_ws => 8000,  :test_ws => 4000, :horizon_to_use => horizon_to_use},
    #{:name => 'GBPUSD-15', :training_ws => 8000,  :test_ws => 4000, :horizon_to_use => horizon_to_use},
    #{:name => 'USDCAD-15', :training_ws => 8000,  :test_ws => 4000, :horizon_to_use => horizon_to_use},
    #{:name => 'USDCHF-15', :training_ws => 8000,  :test_ws => 4000, :horizon_to_use => horizon_to_use},
    #{:name => 'USDJPY-15', :training_ws => 8000,  :test_ws => 4000, :horizon_to_use => horizon_to_use},
    
    #{:name => 'EURUSD-5', :training_ws => 8000,  :test_ws => 4000, :horizon_to_use => horizon_to_use},
    #{:name => 'GBPUSD-5', :training_ws => 8000,  :test_ws => 4000, :horizon_to_use => horizon_to_use},
    {:name => 'USDCAD-5', :training_ws => 8000,  :test_ws => 4000, :horizon_to_use => horizon_to_use},
    #{:name => 'USDCHF-5', :training_ws => 8000,  :test_ws => 4000, :horizon_to_use => horizon_to_use},
    #{:name => 'USDJPY-15', :training_ws => 8000,  :test_ws => 4000,   :horizon_to_use => horizon_to_use},
]



# load RapidMiner XML file into source_rm_xml
source_rm_xml = ''
File.new(source_rm_xml_filename, 'r').each_line {|line| source_rm_xml += line}

xml = ''
#infolder.each do |subfolder|
#if File.directory?(subfolder) && subfolder[0..0] != '.' && subfolder == 'GBPUSD-60'
datasets.each do |ds|
  subfolder = ds[:name]
  puts
  puts 'Dataset: ' + subfolder
  #puts source_rm_xml
  
  #classes_to_eliminate = '12345'.gsub(ds[:horizon_to_use], '')
  classes_to_eliminate = Array.new(horizons.map{|h| 'numclass' + h.to_s})
  classes_to_eliminate += Array.new(horizons.map{|h| 'wnumclass' + h.to_s})
  classes_to_eliminate -= ['wnumclass' + ds[:horizon_to_use].to_s]
  classes_to_eliminate = classes_to_eliminate.join('|')
  #puts classes_to_eliminate
  #exit
  
  csv_filename = ds[:name] + '-signals.csv'
  
  t1 = Time.now
  
  # calculate average profit threshold for machine learning from average change in the first training window (which is not used for training anyway)
  avg_chg = calculate_avg_chg("#{subfolder}/#{csv_filename}", ds[:training_ws], ds[:horizon_to_use])
  ds[:profit_threshold_low] = avg_chg * -1/2
  ds[:profit_threshold_high] = avg_chg * 1/2
  
  # fix XML file for RapidMiner
  xml = source_rm_xml.dup
  # filename
  xml.gsub!(/(<operator name="Read CSV source" class="CSVExampleSource">\s*<parameter key="filename"	value=")(.*?)"/, '\1' + csv_filename +'"') or puts "error setting filename"
  xml.gsub!(/(<operator name="define filename and folder" class="MacroDefinition">\s*<list key="macros">\s*<parameter key="filename"	value=")(.*?)"/, '\1' + ALGORITHM + '"') or puts "error setting filename"
  # folder
  xml.gsub!(/(<parameter key="folder"	value=")(.*?)"/, '\1' + ds[:name] + '"') or puts "error setting folder"
  # profit threshold
  xml.gsub!(/(<parameter key="sell"	value=")(.*?)"/, '\1' + ds[:profit_threshold_low].to_s + '"') or puts "error setting profit threshold"
  xml.gsub!(/(<parameter key="hold"	value=")(.*?)"/, '\1' + ds[:profit_threshold_high].to_s + '"') or puts "error setting profit threshold"
  # "adaptiveness"
  xml.gsub!(/(<parameter key="training_window_width"	value=")(.*?)"/, '\1' + ds[:training_ws].to_s + '"') or puts "error setting adaptiveness"
  xml.gsub!(/(<parameter key="test_window_width"	value=")(.*?)"/, '\1' + ds[:test_ws].to_s + '"') or puts "error setting adaptiveness"
  # horizon
  #xml.gsub!(/(<operator name="remove attr: prices, classes" class="AttributeFilter">\s*<parameter key="condition_class"	value="attribute_name_filter".>\s*<parameter key="parameter_string"	value="\(numclass\[)(.*?)\]0\?\|/, '\1' + classes_to_eliminate + ']0?|') or puts "error setting horizon"
  xml.gsub!(/(<operator name="remove attr: prices, classes" class="AttributeFilter">\s*<parameter key="condition_class"	value="attribute_name_filter".>\s*<parameter key="parameter_string"	value="\()/, '\1' + classes_to_eliminate + '|') or puts "error setting horizon"
  xml.gsub!(/(<operator name="make label" class="ChangeAttributeRole">\s*<parameter key="name"	value="wnumclass)(.*?)"/, '\1' + ds[:horizon_to_use].to_s + '"') or puts "error setting predicted class"
  
  #puts xml
  #exit
  
  target_rm_xml_filename = "#{subfolder}/#{source_rm_xml_filename}"
  log('----------------------------------------------------------------------')
  log(xml)
  File.open("#{target_rm_xml_filename}", 'w') {|of| of.write(xml)} if WRITE_RM4_XML
  log('Running time (avg calc + xml write): ' + (Time.now - t1).to_s, true)
  
  # run RapidMiner
  command_line = "\"#{RAPIDMINER_PATH}\" #{subfolder}/#{source_rm_xml_filename} > #{subfolder}/rapidminer-output.log"
  puts command_line
  rm_failed = false
  if RUN_RAPIDMINER
    t1 = Time.now
    rm_result = system command_line
    if !rm_result
      log('***** ERROR STATUS (RAPIDMINER): ' + $?.to_s, true)
      rm_failed = true
    end
    log('Running time RM: ' + (Time.now - t1).to_s, true)
  else
    log('skipping machine learning on dataset', true)
  end
  
  # run simulation
  #command_line = "\"#{SIMULATOR_PATH}\" #{subfolder}/#{csv_filename} #{subfolder}/#{ALGORITHM}-models.res #{ds[:training_ws]} -1 #{ds[:test_ws]} #{subfolder}/equitycurve.csv #{horizon_to_use} #{stop_loss} #{trailing_stop_loss} > #{subfolder}/trading.log"
  command_line = "\"#{SIMULATOR_PATH}\" #{subfolder}/#{csv_filename} #{subfolder}/#{ALGORITHM}-models.res #{ds[:training_ws]} -1 #{ds[:test_ws]} #{subfolder}/equitycurve.csv #{subfolder}/trading.log #{horizon_to_use}"
  puts command_line
  if !rm_failed && RUN_SIMULATION
    sim_result = system command_line
    if !sim_result
      log('***** ERROR STATUS (SIMULATION): ' + $?.to_s, true)
    end
  else
      log('skipping simulation on dataset', true)
  end
  
  exit if DEMO
  
end
#end
