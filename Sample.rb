class Sample
  attr_accessor :moving_averages
  
  attr_accessor :rsis
  attr_accessor :rsi_avggains
  attr_accessor :rsi_avglosses
  attr_accessor :rocs
  # attr_accessor :rsi_rss
  
  attr_accessor :signals_ma
  attr_accessor :signals_lma
  attr_accessor :signals_rsi
  attr_accessor :signals_roc
  attr_accessor :signals_keyarea
  attr_accessor :klass1
  attr_accessor :klass2
  attr_accessor :klass3
  attr_accessor :numklass
  
  attr_accessor :date
  attr_accessor :open
  attr_accessor :high
  attr_accessor :low
  attr_accessor :close
  attr_accessor :avg
  
  def initialize
    # puts "initialize"
    @moving_averages = {}
    
    @rsis = {}
    @rsi_avggains = {}
    @rsi_avglosses = {}
    @rocs = {}
    # @rsi_rss = {}
    
    @signals_ma = []
    @signals_lma = []
    @signals_rsi = []
    @signals_roc = []
    @signals_keyarea = []
    @ma_diffs = {}
  end
end