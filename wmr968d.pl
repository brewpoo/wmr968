#!/usr/bin/perl 

use Device::SerialPort;
use Config::Fast;
use POSIX 'setsid';
use DBI;
use Getopt::Mixed;

use vars qw($version $debug $log $pid_file $log_file $config $config_file);

# Set defaults
$version=1.0;
$debug=0;
$log=0;
$pid_file="/var/run/wmr968d.pid";
$log_file="/var/log/wmr968d.log";
$config_file="/etc/wmr968d.conf";

# Load config
loadconfig();

$debug   =$config{debug}    if (defined $config{debug});
$log     =$config{log}      if (defined $config{log});
$log_file=$config{log_file} if (defined $config{log_file});
$pid_file=$config{pid_file} if (defined $config{pid_file});

# Process command line arguments
Getopt::Mixed::getOptions("help h>help log l>log logfile=s L>logfile pidfile=s p>pidfile debug d>debug config=s c>config");

$debug = 1 if (defined $opt_debug);
$log   = 1 if (defined $opt_log);
$config_file = $opt_config if (defined $opt_config);
$log_file    = $opt_logfile if (defined $opt_logfile);
$pid_file    = $opt_pidfile if (defined $opt_pidfile);
if (defined $opt_help) {
	usage();
	exit(0);
}


# Shift remaining command line (should be input command
$command = shift @ARGV;
if ($command eq "") {
	usage();
	exit(1);
}

# Globals
use vars qw ($config $ring $port $debugIO $debugProc $wind_readings $rain_readings
             $temp_readings $baro_readings $extra_readings $debug $log);

$debugIO=$debug;
$debugProc=1;


sub usage {
  print <<"EOT"
wmr968d version $version
Usage: $0 [options] [start|stop|status|reconfig|reload]

options:
-d, --debug         Enable debuging output, does not fork
-l, --log           Enable logging
-L <logfile>,
--logfile <logfile> Use <logfile> instead of $log_file
-p <pidfile>,
--pidfile <pidfile> Use <pidfile> instead of $pid_file
-c <config>,        Use <config> instead of $config_file 
--config <config> 
-h, --help          Displays this message               

start    - starts the daemon (this is the implied command)
stop     - stop the daemon
status   - displays the status of the daemon
reconfig - reloads the config file 
reload   - stop and start the daemon

EOT
}

sub reinitstore {
# Initialize hashes 

  undef %wind_readings;
  undef %rain_readings;
  undef %baro_readings;
  undef %inside_readings;
  undef %outside_readings;
  undef %extra_readings;
}


sub flushstore {
# Write readings to db
  output("Flushing to database");

  $dsql="insert into data set station_id=$config{stationid},timestamp=NOW(),timerange=0";
  
  if ($wind_readings{samples}>0) {
    $dsql .= ",wind_speed='$wind_readings{wind_speed}', wind_dir='$wind_readings{wind_dir}',
             gust_speed='$wind_readings{gust_speed}', gust_dir='$wind_readings{gust_dir}',
             wind_chill='$wind_readings{wind_chill}'";
  }

  if ($rain_readings{samples}>0) {
    $dsql .= ",rain_rate='$rain_readings{rain_rate}',rain_rate_high='$rain_readings{rain_high}',
              rain='".($rain_readings{total_since}-$last_total_rain)."'";

  }

  for (my $i=1; $i<4; $i++) {
    if ($extra_readings{samples=>$i}>0) {
       $dsql .= ",channel".$i."_id='".$i."',
                 channel".$i."_temp_high='$extra_readings{temp_high=>$i}',
                 channel".$i."_temp_low='$extra_readings{temp_low=>$i}',
                 channel".$i."_temp_avg='$extra_readings{temp_avg=>$i}',
                 channel".$i."_relh_high='$extra_readings{relh_high=>$i}',
                 channel".$i."_relh_low='$extra_readings{relh_low=>$i}',
                 channel".$i."_relh_avg='$extra_readings{relh_avg=>$i}',
                 channel".$i."_dewp_high='$extra_readings{dewp_high=>$i}',
                 channel".$i."_dewp_low='$extra_readings{dewp_low=>$i}',
                 channel".$i."_dewp_avg='$extra_readings{dewp_avg=>$i}'";
    }
  }

  if ($inside_readings{samples}>0) {
     $dsql .= ",indoor_temp_high='$inside_readings{temp_high}',indoor_temp_low='$inside_readings{temp_low}',
                indoor_temp_avg='$inside_readings{temp_avg}',indoor_relh_high='$inside_readings{relh_high}',
                indoor_relh_low='$inside_readings{relh_low}',indoor_relh_avg='$inside_readings{relh_avg}',
                indoor_dewp_high='$inside_readings{dewp_high}',indoor_dewp_low='$inside_readings{dewp_low}',
                indoor_dewp_avg='$inside_readings{dewp_avg}'";
    }

  if ($outside_readings{samples}>0) {
    $dsql .= ",outdoor_temp_high='$outside_readings{temp_high}',outdoor_temp_low='$outside_readings{temp_low}',
               outdoor_temp_avg='$outside_readings{temp_avg}',outdoor_relh_high='$outside_readings{relh_high}',
               outdoor_relh_low='$outside_readings{relh_low}',outdoor_relh_avg='$outside_readings{relh_avg}',
               outdoor_dewp_high='$outside_readings{dewp_high}',outdoor_dewp_low='$outside_readings{dewp_low}',
               outdoor_dewp_avg='$outside_readings{dewp_avg}'";
  }

  if ($baro_readings{samples}>0) {
    $dsql .= ",baro_avg='$baro_readings{baro}',baro_high='$baro_readings{baro_high}',
               baro_low='$baro_readings{baro_low}',forecast='".substr($baro_readings{forecast},0,1)."',
               trend='$baro_readings{trend}'";
  }

  #output ($dsql);

  $insert=$dbh->prepare($dsql);
  $insert->execute;

  $last_total_rain=$rain_readings{total_since} unless $rain_readings{total_since}==0;

  reinitstore();

}

sub setup {
  $port = new Device::SerialPort ($config{port})
       || die "Can't open $config{port}: $!\n";

  $port->databits(8);
  $port->baudrate(9600);
  $port->parity("none");
  $port->stopbits(1);
  $port->handshake("rts");
  $port->write_settings || undef $port;
  $port->read_char_time(0);     # don't wait for each character
  $port->read_const_time(1000); # 1 second per unfulfilled "read" call


  $dbh = DBI->connect('DBI:mysql:'.$config{db_name}.':'.$config{db_host},
                      $config{db_user},$config{db_pass},
                      { RaiseError => 1, AutoCommit => 1}) or die "Can't connect to database\n";

}


sub daemonize {
  
  chdir '/'		        or die "Can't chdir to /: $!";
  open STDIN, '/dev/null'       or die "Can't read /dev/null: $!";
  open STDOUT, '>/dev/null'     or die "Can't write to /dev/null: $!";
  defined(my $pid = fork)	or die "Can't fork: $!";
  if ($pid) {
    print STDERR "$pid_file -- $pid\n";
    open (PIDFILE,">",$pid_file);
    print PIDFILE "$pid";
    close PIDFILE; 
    exit;
  }
  setsid			or die "Can't start a new session: $!";
  $SIG{INT} = \&sigint;
  $SIG{HUP} = \&sighup;
  open STDERR, '>&STDOUT'	or die "Can't dup stdout: $!";
}
 
sub getpid {
  open (PIDFILE, $pid_file) or return 0;
  $pid=<PIDFILE>;
  close PIDFILE;
  return $pid;
}

sub appendlog {
  my $msg = shift @_;

  open LOGFILE, ">>$log_file";
  print LOGFILE scalar localtime(), " - $msg\n";
  close LOGFILE
}


sub readstation {
# Grabs data from the serial port

  my $buf='';
  my $count=0;

  while ($count==0) {
    ($count, $buf)=$port->read(255);
  }
  return $buf;
}

sub nextpacket {
# Uses the global variable $ring
# Keeps $ring filled and returns
# the head message and removes it from the ring
 
  my $match="ffff";
  my $packet='';
  my $si=0;
  my $fi=0;

  # Always keep the ring filled up
  while (length($ring)<64) {
    $ring=$ring.unpack("H*",readstation());
  }

  $si=index($ring,$match);
  $fi=index($ring,$match,2);
  $packet=substr($ring,$si,$fi); # Next Packet to Process

  # Rotate the ring
  $ring=substr($ring,$fi);
  return $packet;
}


sub verifypacket {
# Calculate the packet checksum and compare to the last byte
  my $packet = shift (@_);
  my @data;
  my $chksum=0;

  for (my $i=0; $i<(length($packet)/2)-1; $i++) {
    $data[$i]=substr($packet,$i*2,2);
    $chksum+=hex($data[$i]);
  }
  $chksum&=0xff;
  if ($chksum==hex(substr($packet,length($packet)-2,2))) {
    return $packet
  }
  if ($debugIO) { output("BONK - Bad Checksum"); }
  return 0;
}
 
sub nextmessage {
# Grabs the next message and verfies it
  my $message=nextpacket();

  if ($debugIO) { output("next: $message"); }
  if (verifypacket($message)) {
    return $message;
  }
  return 0;
}

sub readmessage {
  my $message = shift (@_);
  my @byte;

  $message=substr($message,4,(length($message)-6));
  for (my $i=0; $i<(length($message)/2); $i++) {
    $byte[$i]=substr($message,$i*2,2);
  }
  return @byte;
}


sub lo {
  my $value = shift (@_);
  return substr($value,1,1);
}

sub hi {
  my $value = shift (@_);
  return substr($value,0,1);
}

sub sign {
  my $value = shift (@_);
  if ($value=="8") {
    return -1;
  } else {
    return 1;
  }
}

sub dir {
  my $value = shift (@_);
  return ($value/abs($value));
}

sub getwind {
  my $message  = shift (@_);
  my @byte=readmessage($message);

  $gust_dir   =lo($byte[3]).$byte[2]; #degrees
  $gust_speed =$byte[4].hi($byte[3]); #m/s
  $wind_speed =lo($byte[6]).$byte[5]; 
  $wind_chill =$byte[7]*sign(hi($byte[6])); 
  $gust_speed =$gust_speed/10;
  $wind_speed =$wind_speed/10;

  $wind_readings{samples}++;
  if ($gust_speed > $wind_readings{gust_speed}) { 
    $wind_readings{gust_speed}=$gust_speed; 
    $wind_readings{gust_dir}=$gust_dir; 
  }
  
  if ($wind_readings{samples}>1) {
    $wind_readings{wind_speed}=(($wind_readings{wind_speed}*($wind_readings{samples}-1))+$wind_speed)/$wind_readings{samples};
    $wind_readings{wind_dir}=(($wind_readings{wind_dir}*($wind_readings{samples}-1))+$gust_dir)/$wind_readings{samples};
    $wind_readings{wind_chill}=(($wind_readings{wind_chill}*($wind_readings{samples}-1))+$wind_chill)/$wind_readings{samples};
  } else {
    $wind_readings{wind_speed}=$wind_speed;
    $wind_readings{wind_dir}=$gust_dir;
    $wind_readings{wind_chill}=$wind_chill;
  }

  if ($debugProc) { output("Wind: $gust_dir degrees, $gust_speed m/s, $wind_speed m/s (avg), $wind_chill C"); }
}

sub getrain {
  my $message  = shift (@_);
  my @byte=readmessage($message);

  $rain_rate =$byte[2];
  $rain_total=$byte[5].$byte[4];
  $rain_yest =$byte[7].$byte[6];
  $total_min =$byte[8];
  $total_hour=$byte[9];
  $total_day =$byte[10];
  $total_month=$byte[11];
  $total_year=$byte[12];

  if ($first_interval++==0) { $last_total_rain=$rain_total; }
  $rain_readings{samples}++;
  if ($rain_readings{samples}==1) { $rain_readings{rain_high}=$rain_rate; }
  if ($rain_rate>$rain_readings{rain_high}) { $rain_readings{rain_high}=$rain_rate; }
  $rain_readings{total_since}=$rain_total;
  if ($rain_readings{samples}>1) {
    $rain_readings{rain_rate}=(($rain_readings{rain_rate}*($rain_readings{samples}-1))+$rain_rate)/$rain_readings{samples};
  } else {
    $rain_readings{rain_rate}=$rain_rate;
  }

  if ($debugProc) { output("Rate: $rain_rate mm/h, Yesterday: $rain_yest mm, Total: $rain_total mm since ".$total_hour.$total_min.$total_day.$total_month.$total_year); }
} 
  
sub getextra {
  my $message  = shift (@_);
  my @byte=readmessage($message);

  $channel=oct(lo($byte[1]));
  if ($channel==4) { $channel=3; }
  $temp   =lo($byte[3]).$byte[2];
  $sign   =sign(hi($byte[3]));
  $relh   =$byte[4];
  $dewp   =$byte[5];
  $temp   =$sign*($temp/10);

  if($extra_readings{samples=>$channel}==0) {
    $extra_readings{temp_high=>$channel}=$temp;
    $extra_readings{temp_low=>$channel}=$temp;
    $extra_readings{relh_high=>$channel}=$relh;
    $extra_readings{relh_low=>$channel}=$relh;
    $extra_readings{dewp_high=>$channel}=$dewp;
    $extra_readings{dewp_low=>$channel}=$dewp;
  }

  $extra_readings{samples => $channel}++;
  if ($extra_readings{samples=>$channel}>1) {
    $extra_readings{temp_avg=>$channel}=(($extra_readings{temp_avg=>$channel}*($extra_readings{samples=>$channel}-1))+$temp)/$extra_readings{samples=>$channel};
    $extra_readings{relh_avg=>$channel}=(($extra_readings{relh_avg=>$channel}*($extra_readings{samples=>$channel}-1))+$relh)/$extra_readings{samples=>$channel};
    $extra_readings{dewp_avg=>$channel}=(($extra_readings{dewp_avg=>$channel}*($extra_readings{samples=>$channel}-1))+$dewp)/$extra_readings{samples=>$channel};
  } else {
    $extra_readings{temp_avg=>$channel}=$temp;
    $extra_readings{relh_avg=>$channel}=$relh;
    $extra_readings{dewp_avg=>$channel}=$dewp;
  }


  if($relh<$extra_readings{relh_low=>$channel}) { $extra_readings{relh_low=>$channel}=$relh; };
  if($temp>$extra_readings{temp_high=>$channel}) { $extra_readings{temp_high=>$channel}=$temp; };
  if($temp<$extra_readings{temp_low=>$channel}) { $extra_readings{temp_low=>$channel}=$temp; };
  if($relh>$extra_readings{relh_high=>$channel}) { $extra_readings{relh_high=>$channel}=$relh; };
  if($dewp>$extra_readings{dewp_high=>$channel}) { $extra_readings{dewp_high=>$channel}=$dewp; };
  if($dewp<$extra_readings{dewp_low=>$channel}) { $extra_readings{dewp_low=>$channel}=$dewp; };


  if ($debugProc) { output("Channel: $channel, Temp: $temp C, Rel. Humidity: $relh%, Dew Point: $dewp C"); }
}

sub getforecast {
  my $value=shift(@_);

  if ($value=="2") {
    return "Cloudy";
  } elsif ($value=="3") {
    return "Rain";
  } elsif ($value=="6") {
    return "Partly Cloudy";
  } elsif ($value=="C") {
    return "Sunny";
  } else {
    return "Unknown";
  }
}
  
sub getinside {
  my $message = shift (@_);
  my @byte=readmessage($message);

  $temp   =$byte[3].$byte[2];
  $relh   =$byte[4];
  $dewp   =$byte[5];
  $baro   =hex($byte[6])+856; #milibar
  $cast   =getforecast(hi($byte[7]));
  
  $temp=$temp/10;

  if($inside_readings{samples}==0) {
    $inside_readings{temp_high}=$temp;
    $inside_readings{temp_low}=$temp;
    $inside_readings{relh_high}=$relh;
    $inside_readings{relh_low}=$relh;
    $inside_readings{dewp_high}=$dewp;
    $inside_readings{dewp_low}=$dewp;
  }

  $inside_readings{samples}++;
  if ($inside_readings{samples}>1) {
    $inside_readings{temp_avg}=(($inside_readings{temp_avg}*($inside_readings{samples}-1))+$temp)/$inside_readings{samples};
    $inside_readings{relh_avg}=(($inside_readings{relh_avg}*($inside_readings{samples}-1))+$relh)/$inside_readings{samples};
    $inside_readings{dewp_avg}=(($inside_readings{dewp_avg}*($inside_readings{samples}-1))+$dewp)/$inside_readings{samples};
  } else {
    $inside_readings{temp_avg}=$temp;
    $inside_readings{relh_avg}=$relh;
    $inside_readings{dewp_avg}=$dewp;
  }

  if($temp>$inside_readings{temp_high}) { $inside_readings{temp_high}=$temp; };
  if($temp<$inside_readings{temp_low}) { $inside_readings{temp_low}=$temp; };
  if($relh>$inside_readings{relh_high}) { $inside_readings{relh_high}=$relh; };
  if($relh<$inside_readings{relh_low}) { $inside_readings{relh_low}=$relh; };
  if($dewp>$inside_readings{dewp_high}) { $inside_readings{dewp_high}=$dewp; };
  if($dewp<$inside_readings{dewp_low}) { $inside_readings{dewp_low}=$dewp; };
    
  if($baro_readings{samples}==0) {
    $baro_readings{baro_high}=$baro;
    $baro_readings{baro_low}=$baro;
  }
  $baro_readings{samples}++;
  if ($baro_readings{samples}>1) {
    $baro_readings{baro}=(($baro_readings{baro}*($baro_readings{samples}-1))+$baro)/$baro_readings{samples};
  } else {
    $baro_readings{baro}=$baro;
  }

  if($baro>$baro_readings{baro_high}) { $baro_readings{baro_high}=$baro; }
  if($baro<$baro_readings{baro_low}) { $baro_readings{baro_low}=$baro; }
  $baro_readings{forecast}=$cast;
  
  if ($debugProc) { output("Inside: $temp C, Rel. Humidity: $relh%, Dew Point: $dewp C, Bar: $baro, Forecast: $cast"); }
}

sub getoutside {
  my $message = shift (@_);
  my @byte=readmessage($message);

  $temp   =lo($byte[3]).$byte[2];
  $sign   =sign(hi($byte[3]));
  $relh   =$byte[4];
  $dewp   =$byte[5];
  $ds     =sign(hi($byte[1]));

  $temp=$sign*($temp/10);
  $dewp=$ds*$dewp;

  if($outside_readings{samples}==0) {
    $outside_readings{temp_high}=$temp;
    $outside_readings{temp_low}=$temp;
    $outside_readings{relh_high}=$relh;
    $outside_readings{relh_low}=$relh;
    $outside_readings{dewp_high}=$dewp;
    $outside_readings{dewp_low}=$dewp;
  }

  $outside_readings{samples}++;
  if ($outside_readings{samples}>1) {
    $outside_readings{temp_avg}=(($outside_readings{temp_avg}*($outside_readings{samples}-1))+$temp)/$outside_readings{samples};
    $outside_readings{relh_avg}=(($outside_readings{relh_avg}*($outside_readings{samples}-1))+$relh)/$outside_readings{samples};
    $outside_readings{dewp_avg}=(($outside_readings{dewp_avg}*($outside_readings{samples}-1))+$dewp)/$outside_readings{samples};
  } else {
    $outside_readings{temp_avg}=$temp;
    $outside_readings{relh_avg}=$relh;
    $outside_readings{dewp_avg}=$dewp;
  }

  if($temp>$outside_readings{temp_high}) { $outside_readings{temp_high}=$temp; };
  if($temp<$outside_readings{temp_low}) { $outside_readings{temp_low}=$temp; };
  if($relh>$outside_readings{relh_high}) { $outside_readings{relh_high}=$relh; };
  if($relh<$outside_readings{relh_low}) { $outside_readings{relh_low}=$relh; };
  if($dewp>$outside_readings{dewp_high}) { $outside_readings{dewp_high}=$dewp; };
  if($dewp<$outside_readings{dewp_low}) { $outside_readings{dewp_low}=$dewp; };


  if ($debugProc) { output("Outside: $temp C, Rel. Humidity: $relh%, Dew Point: $dewp C"); }
}


sub parsemessage {
# Decodes the packet and stores the values
# in memory
  my $message = shift (@_);
  my @byte;
  
  @byte=readmessage($message);

  SWITCH: for ($byte[0]) {
    /00/ && do {
    # Anemometer
      getwind($message);
    };

    /01/ && do {
    # Rain guage
      getrain($message);
    };

    /02/ && do {
    # Extra Sensors
      getextra($message);
    };

    /03/ && do {
    # Outside Temp
      getoutside($message);
    };

    /06/ && do {
    # Inside Sensor 
      getinside($message);
    }
  }
   
}
  

sub cleanup {
# Close and free
  $port->close;
  undef $port;
  $dbh->disconnect;
  unlink $pid_file;
}

sub sigint {
# Die nicely
  cleanup();
  die("exiting on signal");
}

sub sighup {
  output ("Received HUP: reloading config");
  loadconfig();
  output ($alarm-time()." seconds to purge");

  return;
}


sub start {
  daemonize() unless $debug;
  setup();
  reinitstore();
  output("Started");

  $alarm=time()+$config{sampleinterval};
  $first_interval=0;

  my $message='';
  $ring='';

  while () {
    if ($message=nextmessage()) {
      parsemessage($message);
    }
    if (time()>=$alarm) {
      flushstore();
      $alarm=time()+$config{sampleinterval};
    }
  }

  cleanup();
}

sub stop {
  $pid=getpid() or die ("PID file missing, process not running?");
  if (kill(SIGTERM, $pid)) {
    print "Exiting\n";
  } else {
    print "Not running, stale PID file\n";
  }
}

sub restart {
  stop;
  start;
}

sub loadconfig {
  %config=fastconfig($config_file);

  $debug   =$config{debug}    if (defined $config{debug});
  $log     =$config{log}      if (defined $config{log});
  $log_file=$config{log_file} if (defined $config{log_file});
  $pid_file=$config{pid_file} if (defined $config{pid_file});
}

sub output {
  print $_[0] if $debug;
  appendlog($_[0]) if $log;

}

sub status {
  $pid=getpid() or die ("PID file missing, process not running?");
  if (kill(0, $pid)) {
    print "Running with pid $pid\n";
  } else {
    print "Not running, stale PID file\n"; 
  }
}

if ($command eq "status") {
  status();
} elsif ($command eq "stop") {
  stop();
} elsif ($command eq "start") {
  start();
} elsif ($command eq "restart") {
  restart();
} elsif ($command eq "reload") {
  loadconfig();
}
