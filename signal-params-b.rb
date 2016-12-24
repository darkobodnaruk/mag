# key areas signal
PRICE_HISTOGRAM_BUCKET_SIZES = [0.0010, 0.0020, 0.0040, 0.0100]
PRICE_HISTOGRAM_AGING_PARAMETERS = [0.97, 0.98, 0.99]

# generating "MA cross" signal: if difference between MAs is almost zero (< macross_cross_tolerance)
#  and it was at least some distance (macross_noncross_distance) away from zero a few periods ago (macross_lookback_period), that's a signal!
MACROSS_LOOKBACK_PERIOD = 3
MACROSS_CROSS_TOLERANCE = 0.0003
MACROSS_NONCROSS_DISTANCE = 0.0005
MA_LONG_PERIODS = [5,7,10,15,20]
MA_SHORT_PERIODS = [2,3,4,5,7,10,15]

# generating RSI oversold & overbought signals
RSI_SIGNAL_BAND_WIDTHS = [5,10,20,30]
RSI_LENGTHS = [2,3,4,5,7,10]

# generating ROC signal: if ROC around zero (< roc_cross_tolerance)
#  and it was at least some distance (roc_nocross_distance) away from zero a few periods ago (roc_lookback_period), that's a signal!
ROC_LOOKBACK_PERIOD = 3
ROC_CROSS_TOLERANCE = 0.0003
ROC_NOCROSS_DISTANCE = 0.0005
ROC_LENGTHS = [2,3,4,5,7,10]

# set to max period of different signals!
HISTORY_LENGTH = 20
P = HISTORY_LENGTH - 1

# generating classes/labels
# future_move_threshold: how many pips higher/lower the price has to be "lookahead_length" periods in the future to make the current period a buy/sell opportunity
LOOKAHEAD_LENGTH = 2
FUTURE_MOVE_THRESHOLD_1 = 0.0005
FUTURE_MOVE_THRESHOLD_2 = 0.0010
FUTURE_MOVE_THRESHOLD_3 = 0.0015