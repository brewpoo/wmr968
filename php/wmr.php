<?php

require_once ('./lib/wmr.conf.php');
require_once ('./lib/wmr.db.php');
include ('./lib/wmr.inc.php');

$wmr = new WMR($wmr_station,US);

echo $wmr->stationName()." ".$wmr->currentWinds()."\n".$wmr->fuzzyWinds()."\n";
echo "Barometer ".$wmr->currentBarometer()." and ".$wmr->trendBarometer()."\n";
echo "Currently ".$wmr->currentConditions()."\n";
echo "Current Temp: ".$wmr->currentOutdoorTemp()."\n";
echo "Current RelH: ".$wmr->currentOutdoorHumidity()."\n";

for ($i=1;$i<=3;$i++) {
  echo "Channel ".$i." is ".$wmr->channelName($i)."\n";
}

?>
