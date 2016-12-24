LOAD DATA LOCAL INFILE 'D:\\dropbox\\My Dropbox\\magisterij\\code\\2-MAsignals\\EURUSD-30\\out-EURUSD-30-signals.csv'
REPLACE INTO TABLE EURUSD30
FIELDS TERMINATED BY ','
IGNORE 1 LINES
(dt,open,high,low,close,ma_sig_5_20,ma_sig_10_20,ma_sig_15_20,ma_sig_5_30,ma_sig_10_30,ma_sig_15_30,ma_sig_20_30,ma_sig_5_40,ma_sig_10_40,ma_sig_15_40,ma_sig_20_40,ma_sig_5_50,ma_sig_10_50,ma_sig_15_50,ma_sig_20_50,rsi_sig_5_10,rsi_sig_5_20,rsi_sig_5_30,rsi_sig_10_10,rsi_sig_10_20,rsi_sig_10_30,rsi_sig_15_10,rsi_sig_15_20,rsi_sig_15_30,rsi_sig_20_10,rsi_sig_20_20,rsi_sig_20_30,class1,class2,class3)
