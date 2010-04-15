select timestamp, indoor_temp_avg*(9/5)+32 as dining, channel2_temp_avg*(9/5)+32  as outside, channel1_temp_avg*(9/5)+32 as duckhouse, channel3_temp_avg*(9/5)+32  as living from data where timerange=1 and date(timestamp)='2007-01-20' order  by timestamp;

select concat(month(timestamp),'/',year(timestamp)) as month, indoor_temp_avg*(9/5)+32 as dining, channel2_temp_avg*(9/5)+32  as outside, channel1_temp_avg*(9/5)+32 as duckhouse, channel3_temp_avg*(9/5)+32 as living, rain/25.4 as rain, rain_ytd/25.4 as rain_ytd from data where timerange=3 group by month order by timestamp;

Extremes:
select timestamp, indoor_temp_high*(9/5)+32 as dining, channel2_temp_high*(9/5)+32 as outside, channel1_temp_high*(9/5)+32 as duckhouse, channel3_temp_high*(9/5)+32 as living, rain_rate_high/25.4 as downpour from data where timerange=3 order by timestamp;

select timestamp, indoor_temp_low*(9/5)+32 as dining, channel2_temp_low*(9/5)+32 as outside, channel1_temp_low*(9/5)+32 as duckhouse, channel3_temp_low*(9/5)+32 as living, rain_rate_high/25.4 as downpour from data where timerange=3 order by timestamp;
