<?php

define ("SI", 0);
define ("US", 1);

class WMR {

  var $stationId;
  var $stationName;
  var $units;
  var $outsideField;

  function WMR($stationId,$units=1) {
    $this->stationId=$stationId;
    if ($this->stationExists($stationId)) {
      $this->units=db_result(db_query("select units from stations where id=".$stationId),0,'units');
      $this->stationName=db_result(db_query("select name from stations where id=".$stationId),0,'name');
      $this->outsideField=db_result(db_query("select outside from stations where id=".$stationId),0,'outside');
    } else {
      die ('Station does not exist');
    }
  }

  function stationExists($station) {
    $result=db_query("select * from stations where id=".$station);
    if ($result && db_numrows($result)==1) {
      return 1;
    }
    return 0;
  }

  function stationName() {
    return $this->stationName;
  }

  function channelName($channel) {
    if ($channel=="i") return "Inside";
    if ($channel=="o") return "Outside";
    return db_result(db_query("select name from extra_units where station_id=".$this->stationId."
                               and channel=".$channel." order by timestamp desc limit 1"),0,'name');
  }

  function setUnits($units) {
    if ($units==SI) {
      $this->units=SI;
      return $units;
    }
    if ($units==US) {
      $this->units=US;
      return $units;
    }
    return -1;
  }

  function _startToday() {
    return date("Y-m-d 00:00:00");
  }

  function _endToday() {
    return date("Y-m-d 23:59:59");
  }

  #
  #
  # Wind Functions
  #
  function windSpeedUnits() {
    if ($this->units==SI) return "m/s";
    return "mph";
  }

  function _currentWindSpeed() {
    $speed=db_result(db_query("select wind_speed from data where station_id=".$this->stationId."
                               and timerange=0 order by timestamp desc limit 1"),0,'wind_speed');
    if ($this->units==SI) return $speed;
    return $speed*2.24;
  }

  function __currentGustSpeed() {
    $speed=db_result(db_query("select gust_speed from data where station_id=".$this->stationId."
                               and timerange=0 order by timestamp desc limit 1"),0,'gust_speed');
    return $speed;
  }


  function _currentWindDir() {
    return db_result(db_query("select wind_dir from data where station_id=".$this->stationId."
                               and timerange=0 order by timestamp desc limit 1"),0,'wind_dir');
  }

  function currentWinds() {
    return $this->_currentWindSpeed()." ".$this->windSpeedUnits()." at ".$this->_currentWindDir(); 
  }

  function _fuzzyWindSpeed () {
    $wind_speed=$this->_currentWindSpeed();
    if ($wind_speed<1) {
      $wind="Calm";
    } else if ($wind_speed>=1 and $wind_speed<3) {
      $wind="Light";
    } else if ($wind_speed>=3 and $wind_speed<6) {
      $wind="Moderate";
    } else if ($wind_speed>=6 and $wind_speed<9) {
      $wind="Strong";
    } else {
      $wind="Very Strong";
    }
    return $wind;
  }

  function _fuzzyWindDir () {
    $wind_dir=$this->_currentWindDir();
    if ($wind_dir>337.5 || $wind_dir<22.5) {
      $direction="N";
    } else if ($wind_dir>=22.5 && $wind_dir<67.5) {
      $direction="NE";
    } else if ($wind_dir>=67.5 && $wind_dir<112.5) {
      $direction="E";
    } else if ($wind_dir>=112.5 && $wind_dir<157.5) {
      $direction="SE";
    } else if ($wind_dir>=157.5 && $wind_dir<202.5) {
      $direction="S";
    } else if ($wind_dir>=202.5 && $wind_dir<247.5) {
      $direction="SW";
    } else if ($wind_dir>=247.5 && $wind_dir<292.5) {
      $direction="W";
    } else if ($wind_dir>=292.5 && $wind_dir<337.5) {
      $direction="NW";
    }
    return $direction;
  }

  function fuzzyWinds () {
    return $this->_fuzzyWindSpeed()." winds out of the ".$this->_fuzzyWindDir();
  }


  function _currentTime() {
    return db_result(db_query("select timestamp from data where station_id=".$this->stationId."
                               and timerange=0 order by timestamp desc limit 1"),0,'timestamp');
  }


  function _previousTime($timeshift) {
    return db_result(db_query("select timestamp from data where station_id=".$this->stationId."
                               and timerange=0 and abs(time_to_sec(timediff(subtime('".$this->_currentTime()."',
                               '$timeshift'),timestamp)))<900 limit 1"),0,'timestamp');
  }
                          
  #
  #
  # Barometer Functions
  #
  function barometerUnits() {
     if ($this->units==SI) return "hpa";
     return "inhg";
  }

  function _getBarometer($when) {
    $baro= db_result(db_query("select baro_avg from data where station_id=".$this->stationId."
                               and timerange=0 and timestamp='$when'"),0,'baro_avg');
    if ($this->units==SI) return $baro;
    return round($baro/33.864,2);
  }

  function _currentBarometer() {
    $baro= db_result(db_query("select baro_avg from data where station_id=".$this->stationId."
                               and timerange=0 order by timestamp desc limit 1"),0,'baro_avg');
    if ($this->units==SI) return $baro;
    return round($baro/33.864,2);
  }

  function currentBarometer() {
    $baro=$this->_currentBarometer();
    return $baro." ".$this->barometerUnits();
  }

  function trendBarometer() {
    $trend=$this->_currentBarometer()-$this->_getBarometer($this->_previousTime("03:00"));
    if ($trend>0) {
      return "Rising";
    } else if ($trend<0) {
      return "Falling";
    } else {
      return "Steady";
    }
  }

  function currentConditions() {
    $forecast=db_result(db_query("select forecast from data where timerange=0 and station_id=".$this->stationId."
                                  order by timestamp desc limit 1"),0,'forecast');
    switch($forecast) {
      case "S":
        return "Sunny";
        break;
      case "R":
        return "Rain";
        break;
      case "P":
        return "Partly Cloudy";
        break;
      case "C":
        return "Cloudy";
        break;
      default:
        return "Unknown";
     }
  }

  #
  # Temperature Functions
  #
  function temperatureUnits() {
    if ($this->units==SI) return "C";
    return "F";
  }

  function _getOutdoorTemp($when) {
    $temp= db_result(db_query("select ".$this->outsideField."_temp_avg  from data where 
                               station_id=".$this->stationId." and timerange=0 and 
                               timestamp='$when'"),0,$this->outsideField.'_temp_avg');
    if ($this->units==SI) return $temp;
    return $temp*(9/5)+32;
  }

  function __currentOutdoorTemp() {
    $out = $this->outsideField;
    $temp=db_result(db_query("select ".$out."_temp_avg from data where ".$out."_temp_avg is not null and timerange=0 and 
                              station_id=".$this->stationId." order by timestamp desc limit 1"),0,$out.'_temp_avg');
    return $temp;
  }

  function _currentOutdoorTemp() {
    $temp = $this->__currentOutdoorTemp();
    if ($this->units==SI) return $temp;
    return $temp*(9/5)+32; 
  }

  function currentOutdoorTemp() {
    return $this->_currentOutdoorTemp()." ".$this->temperatureUnits();
  }

  function _currentOutdoorHumidity() {
    $out = $this->outsideField;
    $relh=db_result(db_query("select ".$out."_relh_avg from data where ".$out."_relh_avg is not null and timerange=0 and
                              station_id=".$this->stationId." order by timestamp desc limit 1"),0,$out.'_relh_avg');
    return $relh;
  }

  function currentOutdoorHumidity() {
    return $this->_currentOutdoorHumidity()." %";
  }

  function overnightLow() {
    $temp=db_result(db_query("select min(".$this->outsideField."_temp_low) as temp from data where timerange=0 and
                             station_id=".$this->stationId." and timestamp>='".$this->_startToday()."'"),0,"temp");
    if ($this->units==SI) return $temp;
    return $temp*(9/5)+32;
  }

  function todaysHigh() {
    $temp=db_result(db_query("select max(".$this->outsideField."_temp_high) as temp from data where timerange=0 and
                              station_id=".$this->stationId." and timestamp>='".$this->_startToday()."'"),0,"temp");
    if ($this->units==SI) return $temp;
    return $temp*(9/5)+32;
  }

  function currentWindChill() {
    $temp=$this->__currentOutdoorTemp();
    $wind=$this->__currentGustSpeed();
    if (($temp<7.2) && ($wind>1.3)) {
      $k=pow($wind,0.16);
      $wind_chill = round(13.12+(0.6215*$temp)-(11.37*$k)+0.3965*$temp*$k,1);
      if ($wind_chill<$temp) return "N/A";
      if ($this->units==SI) return $wind_chill;
      return $wind_chill*(9/5)+32;
    }
    return false;
  }

  function currentHeatIndex() {
    $temp=$this->__currentOutdoorTemp();
    $relh=$this->_currentOutdoorHumidity();
    if (($temp>26) && ($relh>40)) {
      $e=(6.112 * pow(10,((7.5*$temp)/(237.7+$temp))*($relh/100)));
      $heat_index=round($temp+(5/9)*($e-10),1);
      if ($heat_index<$temp) return "N/A";
      if ($this->units==SI) return $heat_index;
      return $heat_index*(9/5)+32;
    }
    return false;
  }

  #
  # Rain Functions
  #
  function rainUnits() {
    if ($this->units==SI) return "mm";
    return "in";
  }

  function _currentRain() {
    $rain=db_result(db_query("select rain from data where timerange=0 and
                              station_id=".$this->stationId." order by timestamp desc limit 1"),0,'rain');
    if ($this->units==SI) return $rain;
    return $rain/25.4;
  }

  function rainToday() {
    $rain=$this->_currentRain();
  }

  #
  # Chart Functions
  #

  function getChartData($channel,$item, $count, $unit) {
    if (stristr($item, 'temp') and $this->units==US) {
      $convert = "*(9/5)+32 ";
    } else {
      $convert = " ";
    }
 
    switch ($unit) {
      case "hours";
        $timerange=1;
        $unit="hour";
        break;
  
      case "days";
        $timerange=2;
        $unit="day";
        $func="dayofweek";
        break;

      case "months";
        $timerange=3;
        $unit="month";
        break;

      case "years";
        $timerange=4;
        $unit="year";
        break;
    }

    $count++;
    $result=db_query("select $func(timestamp) as unit, $item $convert as item from data where timerange=$timerange
                     and station_id=".$this->stationId." and date_sub(now(), interval $count $unit) <= timestamp order by timestamp");

    $table[0][0]="";
    $table[1][0]=$this->channelName($channel);
    for($i=0; $i<db_numrows($result); $i++) {
      $table[0][$i+1]=db_result($result,$i,"unit");
      $table[1][$i+1]=db_result($result,$i,"item");
    }
    return $table;
  }

  function getHiLowTemp($channel,$count,$unit) {
    if ($this->units==US) {
      $convert = "*(9/5)+32 ";
    } else {
      $convert = " ";
    }

    switch ($unit) {
      case "hours";
        $timerange=1;
        $unit="hour";
	$func="time(timestamp)";
        break;
 
      case "days";
        $timerange=2;
        $unit="day";
        $func="dayname(timestamp)";
        break;

      case "months";
        $timerange=3;
        $unit="month";
        $func="monthname(timestamp)";
        break;

      case "years";
        $timerange=4;
        $unit="year";
        $func="year(timestamp)";
        break;
    }

    if ($channel=="i") {
      $item="indoor";
    } elseif ($channel=="o") {
      $item="outdoor";
    } else {
      $item="channel".$channel;
    }

    $count++;
    $result=db_query("select $func as unit, ".$item."_temp_high $convert as high, ".$item."_temp_low $convert as low from data where timerange=$timerange
                     and station_id=".$this->stationId." and date_sub(now(), interval $count $unit) <= timestamp order by timestamp");

    $table[0][0]="";
    $table[1][0]="hi";
    $table[2][0]="low";
    for($i=0; $i<db_numrows($result); $i++) {
      $table[0][$i+1]=db_result($result,$i,"unit");
      $table[1][$i+1]=db_result($result,$i,"high");
      $table[2][$i+1]=db_result($result,$i,"low");
    }
    return $table;

  }

  function getAvgTemp($channel,$count,$unit) {
    if ($this->units==US) {
      $convert = "*(9/5)+32 ";
    } else {
      $convert = " ";
    }

    switch ($unit) {
      case "hours";
        $timerange=1;
        $unit="hour";
        $func="time(timestamp)";
        break;

      case "days";
        $timerange=2;
        $unit="day";
        $func="dayname(timestamp)";
        if ($count>7) $func="date(timestamp)";
        break;

      case "months";
        $timerange=3;
        $unit="month";
        $func="monthname(timestamp)";
        break;

      case "years";
        $timerange=4;
        $unit="year";
        $func="year(timestamp)";
        break;
    }

    if ($channel=="i") {
      $item="indoor";
    } elseif ($channel=="o") {
      $item="outdoor";
    } else {
      $item="channel".$channel;
    }

    $count++;
    $result=db_query("select $func as unit, ".$item."_temp_avg $convert as value from data where timerange=$timerange
                     and station_id=".$this->stationId." and date_sub(now(), interval $count $unit) <= timestamp order by timestamp");

    $table[0][0]="";
    $table[1][0]="temp";
    for($i=0; $i<db_numrows($result); $i++) {
      $table[0][$i+1]=db_result($result,$i,"unit");
      $table[1][$i+1]=db_result($result,$i,"value");
    }
    return $table;

  }

  function getTempHumd($channel,$count,$unit) {
    if ($this->units==US) {
      $convert = "*(9/5)+32 ";
    } else {
      $convert = " ";
    }

    switch ($unit) {
      case "hours";
        $timerange=1;
        $unit="hour";
        $func="time(timestamp)";
        break;

      case "days";
        $timerange=2;
        $unit="day";
        $func="dayname(timestamp)";
        if ($count>7) $func="date(timestamp)";
        break;

      case "months";
        $timerange=3;
        $unit="month";
        $func="monthname(timestamp)";
        if ($count>12) $func="concat(month(timestamp),'/',year(timestamp))";
        break;

      case "years";
        $timerange=4;
        $unit="year";
        $func="year(timestamp)";
        break;
    }

    if ($channel=="i") {
      $item="indoor";
    } elseif ($channel=="o") {
      $item="outdoor";
    } else {
      $item="channel".$channel;
    }

    $count++;
    $result=db_query("select $func as unit, ".$item."_temp_avg $convert as temperature, ".$item."_relh_avg as humidity from data where timerange=$timerange
                     and station_id=".$this->stationId." and date_sub(now(), interval $count $unit) <= timestamp order by timestamp");

    $table[0][0]="";
    $table[1][0]="Temperature";
    $table[2][0]="Relative Humidity";
    for($i=0; $i<db_numrows($result); $i++) {
      $table[0][$i+1]=db_result($result,$i,"unit");
      $table[1][$i+1]=db_result($result,$i,"temperature");
      $table[2][$i+1]=db_result($result,$i,"humidity");
    }
    return $table;

  }


  function getRain($count,$unit,$ytd) {
    if ($this->units==US) {
      $convert = "/25.4 ";
    } else {
      $convert = " ";
    }

    switch ($unit) {
      case "hours";
        $timerange=1;
        $unit="hour";
        $fetch_unit="time(timestamp)";
        break;

      case "days";
        $timerange=2;
        $unit="day";
        $fetch_unit="concat(month(timestamp),'/',day(timestamp))";
        break;

      case "months";
        $timerange=3;
        $unit="month";
        $fetch_unit="concat(month(timestamp),'/',year(timestamp))";
        break;

      case "years";
        $timerange=4;
        $unit="year";
        $fetch_unit="year(timestamp)";
        break;
    }
  
    $count++;

    $result=db_query("select $fetch_unit as unit, rain $convert as rain, rain_ytd $convert as rain_ytd  from data where timerange=$timerange
                     and station_id=".$this->stationId." and date_sub(now(), interval $count $unit) <= timestamp order by timestamp");

    $table[0][0]="";
    $table[1][0]="Rain this $unit";
    if ($ytd) $table[2][0]="Rain YTD";
    for($i=0; $i<db_numrows($result); $i++) {
      $table[0][$i+1]=db_result($result,$i,"unit");
      $table[1][$i+1]=db_result($result,$i,"rain");
      if ($ytd) $table[2][$i+1]=db_result($result,$i,"rain_ytd");
    }
    return $table;

  }

}

?>

