#!/usr/bin/perl 
#
# wmrsum
#
# Jon Lochner - Netguyz http://www.netguyz.org/projects
#
# This is a companion script to wmr968d.pl. The purpose of this
# script is to summarize the raw data obtained by wmr968d.
#

use Config::Fast;
use DBI;
use Getopt::Mixed;

use constant DEGREE_BASE => 18;
use constant WIND_CHILL_TEMP_THRESHOLD => 7.2; # dC
use constant WIND_CHILL_WIND_THRESHOLD => 1.3; # m/s
use constant HEAT_INDEX_TEMP_THRESHOLD => 26; # dC
use constant HEAT_INDEX_REHL_THRESHOLD => 40; # $

use constant RAW   => 0;
use constant HOUR  => 1;
use constant DAY   => 2;
use constant MONTH => 3;
use constant YEAR  => 4;

# Globals
use vars qw ($debug $version $log $config);

# Default settings
$version=1.0;
$debug=0;
$log=0;
$time=0;
$config_file="/etc/wmr968d.conf";
$log_file="/var/log/wmr968_process.log";

# Load database connection info
%config=fastconfig($config_file);
$log_file = $config{log_file} if (defined $config{log_file});

# Process command line arguments
Getopt::Mixed::getOptions("help h>help time t>time log l>log logfile L>logfile debug d>debug config=s c>config");

$debug = 1 if (defined $opt_debug);
$log   = 1 if (defined $opt_log);
$time  = 1 if (defined $opt_time);
$config_file = $opt_config if (defined $opt_config);
$log_file = $opt_logfile if (defined $opt_logfile);
if (defined $opt_help) {
	usage();
	exit(0);
}


sub usage {
  print <<"EOT"
wmrsum version $version
Usage: $0 [options]

options:
-d, --debug        Enable debuging output, does not fork
-l, --log          Enable logging
-t, --time         Enable process timing
-c <config>,       Use <config> instead of $config_file 
--config <config> 
-L <logifle>       Use <logfile> instead of $log_file
--logfile <logfile> 
-h, --help         Displays this message               

EOT
}


sub appendlog {
  my $msg = shift @_;

  open LOGFILE, ">>$log_file";
  print LOGFILE scalar localtime(), " - $msg\n";
  close LOGFILE
}


sub output {
  my $msg = shift @_;

  print $msg if $debug;
  appendlog($msg) if $log;

}

sub setup {
  $dbh = DBI->connect('DBI:mysql:'.$config{db_name}.':'.$config{db_host},
                      $config{db_user},$config{db_pass},
                      { RaiseError => 1, AutoCommit => 1}) or die "Can't connect to database\n";
}

sub currentInterval {
  ($timestamp,$INTERVAL) = @_;

  $_ = $timestamp;
  ($year,$month,$day,$hour,$minute,$second)=/(\d+)\-(\d+)\-(\d+)\s(\d+)\:(\d+)\:(\d+)/;

  if ($INTERVAL==HOUR) {
    $rounded=$year."-".$month."-".$day." ".$hour.":00:00";
  } elsif ($INTERVAL==DAY) {
    $rounded=$year."-".$month."-".$day." 00:00:00";
  } elsif ($INTERVAL==MONTH) {
    $rounded=$year."-".$month."-01 00:00:00";
  } elsif ($INTERVAL==YEAR) {
    $rounded=$year."-01-01 00:00:00";
  }
  return $rounded;
}

sub firstOfYear {
  $timestamp = shift @_;

  $_ = $timestamp;
  ($year,$month,$day,$hour,$minute,$second)=/(\d+)\-(\d+)\-(\d+)\s(\d+)\:(\d+)\:(\d+)/;

   $start=$year."-01-01 00:00:00";

   return $start;
}
   

sub nextInterval {
  ($timestamp,$INTERVAL) = @_;

  $_ = $timestamp;
  ($year,$month,$day,$hour,$minute,$second)=/(\d+)-(\d+)-(\d+)\s(\d+):(\d+):(\d+)/;

  if ($INTERVAL==HOUR) {
    $rounded=$year."-".$month."-".$day." ".$hour.":00:00";
    $interval="HOUR";
  } elsif ($INTERVAL==DAY) { 
    $rounded=$year."-".$month."-".$day." 00:00:00";
    $interval="DAY";
  } elsif ($INTERVAL==MONTH) {
    $rounded=$year."-".$month."-01 00:00:00";
    $interval="MONTH";
  } elsif ($INTERVAL==YEAR) {
    $rounded=$year."-01-01 00:00:00";
    $interval="YEAR";
  }

  #output("Rounded: $rounded\n");
  $niq=$dbh->prepare("select ('".$rounded."' + INTERVAL 1 $interval + INTERVAL 0 SECOND)");
  $niq->execute;
  ($next) = $niq->fetchrow_array;
  #output("Next: $next\n");
  return $next;
}

sub outdoorSensor {
  ($stationId,$measurement) = @_;

  $sth=$dbh->prepare(q{select outside from stations where id = ?});
  $sth->execute($stationId);
  ($sensor)=$sth->fetchrow_array;
  return $sensor."_".$measurement;
}

sub summarize {
  ($STATION, $INTERVAL) = @_;

  $summarized=0;
  
  # Prepare queries
  $ltsq=$dbh->prepare(q{select max(timestamp) from data where station_id= ? and timerange= ?});
  $ftsq=$dbh->prepare(q{select min(timestamp) from data where station_id= ? and timerange= ?});
  $ddq=$dbh->prepare(q{select sum(cooling_degrees), sum(heating_degrees) from data where
                       station_id= ? and timerange= ? and
                       timestamp>= ? and timestamp< ? });
  $wcq=$dbh->prepare(q{select min(wind_chill) from data where
                       station_id= ? and timerange= ? and
                       timestamp>= ? and timestamp< ? });
  $hiq=$dbh->prepare(q{select max(heat_index) from data where
                       station_id= ? and timerange= ? and
                       timestamp>= ? and timestamp< ? });
  $fdq=$dbh->prepare(q{select max(indoor_temp_high) as indoor_temp_high,
          max(indoor_relh_high) as indoor_relh_high,
          max(indoor_dewp_high) as indoor_dewp_high,
          min(indoor_temp_low) as indoor_temp_low,
          min(indoor_relh_low) as indoor_relh_low,
          min(indoor_dewp_low) as indoor_dewp_low,
          avg(indoor_temp_avg) as indoor_temp_avg,
          avg(indoor_relh_avg) as indoor_relh_avg,
          avg(indoor_dewp_avg) as indoor_dewp_avg,
          max(outdoor_temp_high) as outdoor_temp_high,
          max(outdoor_relh_high) as outdoor_relh_high,
          max(outdoor_dewp_high) as outdoor_dewp_high,
          min(outdoor_temp_low) as outdoor_temp_low,
          min(outdoor_relh_low) as outdoor_relh_low,
          min(outdoor_dewp_low) as outdoor_dewp_low,
          avg(outdoor_temp_avg) as outdoor_temp_avg,
          avg(outdoor_relh_avg) as outdoor_relh_avg,
          avg(outdoor_dewp_avg) as outdoor_dewp_avg,
          max(channel1_temp_high) as channel1_temp_high,
          max(channel1_relh_high) as channel1_relh_high,
          max(channel1_dewp_high) as channel1_dewp_high,
          min(channel1_temp_low) as channel1_temp_low,
          min(channel1_relh_low) as channel1_relh_low,
          min(channel1_dewp_low) as channel1_dewp_low,
          avg(channel1_temp_avg) as channel1_temp_avg,
          avg(channel1_relh_avg) as channel1_relh_avg,
          avg(channel1_dewp_avg) as channel1_dewp_avg,
          max(channel2_temp_high) as channel2_temp_high,
          max(channel2_relh_high) as channel2_relh_high,
          max(channel2_dewp_high) as channel2_dewp_high,
          min(channel2_temp_low) as channel2_temp_low,
          min(channel2_relh_low) as channel2_relh_low,
          min(channel2_dewp_low) as channel2_dewp_low,
          avg(channel2_temp_avg) as channel2_temp_avg,
          avg(channel2_relh_avg) as channel2_relh_avg,
          avg(channel2_dewp_avg) as channel2_dewp_avg,
          max(channel3_temp_high) as channel3_temp_high,
          max(channel3_relh_high) as channel3_relh_high,
          max(channel3_dewp_high) as channel3_dewp_high,
          min(channel3_temp_low) as channel3_temp_low,
          min(channel3_relh_low) as channel3_relh_low,
          min(channel3_dewp_low) as channel3_dewp_low,
          avg(channel3_temp_avg) as channel3_temp_avg,
          avg(channel3_relh_avg) as channel3_relh_avg,
          avg(channel3_dewp_avg) as channel3_dewp_avg,
          max(baro_high) as baro_high,
          min(baro_low) as baro_low,
          avg(baro_avg) as baro_avg,
          avg(trend) as trend,
          avg(wind_speed) as wind_speed,
          avg(wind_dir) as wind_dir,
          avg(rain_rate) as rain_rate,
          max(rain_rate_high) as rain_rate_high,
          sum(rain) as rain
          from data where station_id= ? and timerange= ?
          and timestamp>= ? and timestamp< ?});
  $gdq=$dbh->prepare(q{select gust_speed, gust_dir from data where gust_speed = (select max(gust_speed) from data where
                         station_id= ? and timerange= ? and
                         timestamp>= ? and timestamp< ?)});
  $dsq=$dbh->prepare(q{select id from data where station_id= ? and timestamp>= ? and timerange= ?});
  $siq=$dbh->prepare(q{select channel1_id, channel2_id, channel3_id from data
                       where station_id = ? and timestamp>= ? and timestamp < ? });
  $rytd=$dbh->prepare(q{select sum(rain) as rain from data where station_id= ? and timerange= ? and
                        timestamp>= ? and timestamp< ?});



  # Determine last interval summarized
  $ltsq->execute($STATION,$INTERVAL);
  ($last_timestamp) = $ltsq->fetchrow_array;
  if (!$last_timestamp) {
    $ftsq->execute($STATION,$INTERVAL-1);;
    ($last_timestamp) = $ftsq->fetchrow_array;
    $last_timestamp=currentInterval($last_timestamp,$INTERVAL);
    $current_timestamp=$last_timestamp;
  } else {
    $current_timestamp=nextInterval($last_timestamp,$INTERVAL);
  }
  
  #output("Previous timestamp: $last_timestamp\n");

  while() {
    #output("Summarizing ($INTERVAL):$current_timestamp\n");

    $next_timestamp=nextInterval($current_timestamp,$INTERVAL);
    #output("Upper Bounds:$next_timestamp\n");
 
    # Make sure we have data to summarize
    $dsq->execute($STATION,$next_timestamp,$INTERVAL-1);
    if ($dsq->rows==0) { 
      return $summarized;; 
    }

    # Get Min/Max/Avg/Sum 
    $fdq->execute($STATION,$INTERVAL-1,$current_timestamp,$next_timestamp);
    $data=$fdq->fetchrow_hashref;

    # Get wind gust data
    $gdq->execute($STATION,$INTERVAL-1,$current_timestamp,$next_timestamp);
    ($gust_speed,$gust_dir)=$gdq->fetchrow_array;
  
    # Compute cooling and heating degrees
    if (($INTERVAL==DAY) && ($data->{outdoorSensor($STATION,"temp_avg")})) {
      my $mean_temp=($data->{outdoorSensor($STATION,"temp_high")}+$data->{outdoorSensor($STATION,"temp_low")})/2;
      if ($mean_temp>DEGREE_BASE) {
      # Cooling degrees
        $cooling_degrees=$mean_temp - DEGREE_BASE;
        $heating_degrees=0;
      } elsif ($mean_temp<DEGREE_BASE) {
      # Heating degrees
        $heating_degrees=DEGREE_BASE - $mean_temp;
        $cooling_degrees=0;
      }
    } elsif (($INTERVAL==MONTH) || ($INTERVAL==YEAR)) {
      $ddq->execute($STATION,$INTERVAL-1,$current_timestamp,$next_timestamp);
      ($cooling_degrees,$heating_degrees)=$ddq->fetchrow_array;
    } else {
      $cooling_degrees=0;
      $heating_degrees=0;
    }

    # Compute YTD rain fall
    $rytd->execute($STATION,$INTERVAL-1,firstOfYear($current_timestamp),$next_timestamp);
    ($rain_ytd)=$rytd->fetchrow_array;

    # Compute apparent temperature summarize max & min
    # Wind Chill based on gust speed at average temp)
    if ($INTERVAL==HOUR) {
      if (($data->{outdoorSensor($STATION,"temp_avg")}<WIND_CHILL_TEMP_THRESHOLD) && ($gust_speed>WIND_CHILL_WIND_THRESHOLD)) {
        $temp = $data->{outdoorSensor($STATION,"temp_avg")};
        $wind_chill = 13.12+(0.6215*$temp)-(11.37*($gust_speed**0.16))+0.3965*$temp*($gust_speed**0.16);
        $wind_chill = '' if $wind_chill>$temp;
      } else {
        $wind_chill='';
      }
    } else {
      $wcq->execute($STATION,$INTERVAL-1,$current_timestamp,$next_timestamp);
      ($wind_chill)=$wcq->fetchrow_array;
    }
     

    # Heat index based on avg relative humidity and outside temp
    if ($INTERVAL==HOUR) {
      if (($data->{outdoorSensor($STATION,"temp_avg")}>HEAT_INDEX_TEMP_THRESHOLD) &&
          ($data->{outdoorSensor($STATION,"relh_avg")}>HEAT_INDEX_RELH_THRESHOLD)) {
        $temp=$data->{outdoorSensor($STATION,"temp_avg")};
        $relh=$data->{outdoorSensor($STATION,"relh_avg")};
        $e=(6.112*10**((7.5*$temp)/(237.7+$temp))*($relh/100));
	$heat_index=$temp+(5/9)*($e-10);
        $heat_index='' if $heat_index<$temp;
      } else {
        $heat_index='';
      }
    } else {
      $hiq->execute($STATION,$INTERVAL-1,$current_timestamp,$next_timestamp);
      ($heat_index)=$hiq->fetchrow_array;
    }

    # Insert new summarized record
    $siq->execute($STATION,$current_timestamp,$next_timestamp); 
    ($channel1_id,$channel2_id,$channel3_id)=$siq->fetchrow_array;

     $sql = "insert into data set timestamp='$current_timestamp', timerange='$INTERVAL',
             station_id='$STATION', channel1_id='$channel1_id', channel2_id='$channel2_id', channel3_id='$channel3_id',
             gust_speed='$gust_speed',gust_dir='$gust_dir',
             cooling_degrees='$cooling_degrees',heating_degrees='$heating_degrees',
             rain_ytd='$rain_ytd'";

    $sql .= ",wind_chill='$wind_chill'" if $wind_chill;
    $sql .= ",heat_index='$heat_index'" if $heat_index;

    while (($key,$value) = each %$data) {
      #output "$key => $value\n";
      $sql .= ",$key='$value'" if $value;
    }

    #output($sql."\n"); 
    $dbh->do($sql);
    $summarized++;

    $current_timestamp=$next_timestamp;

  } # End While
  
}

if ($time) { $start=time(); }
setup();
$slq=$dbh->prepare("select id from stations");
$slq->execute;
while (($station)=$slq->fetchrow_array) {
  for($i=1;$i<5;$i++) {
    $count=summarize($station,$i);
    output("Summarized $count entries ($i) for station $station\n");
  }
}

if ($time) {
  $end=time(); 
  output ("Elapsed time: ".($end-$start)." seconds\n");
}

