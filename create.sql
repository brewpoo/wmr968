CREATE DATABASE wmr;

USE wmr;

CREATE TABLE stations (
  id	TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name	VARCHAR(255) NOT NULL,

  KEY(id),
  PRIMARY KEY(id)
);

CREATE TABLE extra_units (
  id		INT UNSIGNED NOT NULL AUTO_INCREMENT,
  station_id	TINYINT UNSIGNED NOT NULL,

  timestamp	DATETIME NOT NULL,
  channel	TINYINT UNSIGNED,
  name		VARCHAR(50) NOT NULL,
  description	TEXT,

  KEY(id),
  KEY(station_id),
  KEY(channel),
  PRIMARY KEY(id)
);

CREATE TABLE data (
  id		INT UNSIGNED NOT NULL AUTO_INCREMENT,
  station_id	TINYINT UNSIGNED NOT NULL,
  timestamp	DATETIME NOT NULL,

  timerange	TINYINT UNSIGNED, # 0-raw, 1-hourly, 2-daily, 4-monthly, 8-yearly 

  channel1_id	INT UNSIGNED,
  channel2_id	INT UNSIGNED,
  channel3_id	INT UNSIGNED,

  indoor_temp_high	DECIMAL(3,1),
  outdoor_temp_high	DECIMAL(3,1),
  channel1_temp_high	DECIMAL(3,1),
  channel2_temp_high	DECIMAL(3,1),
  channel3_temp_high	DECIMAL(3,1),

  indoor_temp_low	DECIMAL(3,1),
  outdoor_temp_low	DECIMAL(3,1),
  channel1_temp_low	DECIMAL(3,1),
  channel2_temp_low	DECIMAL(3,1),
  channel3_temp_low	DECIMAL(3,1),

  indoor_temp_avg	DECIMAL(3,1),
  outdoor_temp_avg	DECIMAL(3,1),
  channel1_temp_avg	DECIMAL(3,1),
  channel2_temp_avg	DECIMAL(3,1),
  channel3_temp_avg	DECIMAL(3,1),

  indoor_relh_high	DECIMAL(3,1),
  outdoor_relh_high	DECIMAL(3,1),
  channel1_relh_high	DECIMAL(3,1),
  channel2_relh_high	DECIMAL(3,1),
  channel3_relh_high	DECIMAL(3,1),

  indoor_relh_low	DECIMAL(3,1),
  outdoor_relh_low	DECIMAL(3,1),
  channel1_relh_low	DECIMAL(3,1),
  channel2_relh_low	DECIMAL(3,1),
  channel3_relh_low	DECIMAL(3,1),

  indoor_relh_avg	DECIMAL(3,1),
  outdoor_relh_avg	DECIMAL(3,1),
  channel1_relh_avg	DECIMAL(3,1),
  channel2_relh_avg	DECIMAL(3,1),
  channel3_relh_avg	DECIMAL(3,1),

  indoor_dewp_high	DECIMAL(3,1),
  outdoor_dewp_high	DECIMAL(3,1),
  channel1_dewp_high	DECIMAL(3,1),
  channel2_dewp_high	DECIMAL(3,1),
  channel3_dewp_high	DECIMAL(3,1),

  indoor_dewp_low	DECIMAL(3,1),
  outdoor_dewp_low	DECIMAL(3,1),
  channel1_dewp_low	DECIMAL(3,1),
  channel2_dewp_low	DECIMAL(3,1),
  channel3_dewp_low	DECIMAL(3,1),

  indoor_dewp_avg	DECIMAL(3,1),
  outdoor_dewp_avg	DECIMAL(3,1),
  channel1_dewp_avg	DECIMAL(3,1),
  channel2_dewp_avg	DECIMAL(3,1),
  channel3_dewp_avg	DECIMAL(3,1),

  baro_high		INT,
  baro_low		INT,
  baro_avg		INT,
  trend			TINYINT,
  forecast		CHAR(1),

  gust_speed		DECIMAL(3,1),
  gust_dir		SMALLINT UNSIGNED,
  wind_speed		DECIMAL(3,1),
  wind_dir		SMALLINT UNSIGNED,
  wind_speed_high	DECIMAL(3,1),
  wind_chill		SMALLINT,

  rain			SMALLINT UNSIGNED,
  rain_ytd		SMALLINT UNSIGNED,
  rain_rate		SMALLINT UNSIGNED,
  rain_rate_high	SMALLINT UNSIGNED,

  cooling_degrees	SMALLINT UNSIGNED,
  heating_degrees	SMALLINT UNSIGNED,

  KEY(id),
  KEY(station_id),
  KEY(timerange),
  KEY(timestamp),
  PRIMARY KEY(id)
);

