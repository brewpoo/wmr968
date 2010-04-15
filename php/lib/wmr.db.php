<?php
//
// This file defines the connection parameters and functions used
// to connect to the database.
//
// database.php mysql
//

function db_connect() {
        global $wmr_dbhost, $wmr_dbuser, $wmr_dbpass;
        $conn = mysql_connect($wmr_dbhost, $wmr_dbuser, $wmr_dbpass);
        if (!$conn) {
          echo mysql_error();
        }
        return $conn;
}

function db_query($qstring,$print=0) {
        global $wmr_dbname;
        return @mysql($wmr_dbname, $qstring);
}

function db_numrows($qhandle) {
        if ($qhandle) {
                return @mysql_numrows($qhandle);
        } else {
                return 0;
        }
}

function db_result($qhandle, $row, $field) {
        return @mysql_result($qhandle, $row, $field);
}

function db_numfields($lhandle) {
        return @mysql_numfields($lhandle);
}

function db_fieldname($lhandle,$fnumber) {
           return @mysql_fieldname($lhandle,$fnumber);
}

function db_affected_rows($qhandle) {
        return @mysql_affected_rows();
}

function db_fetch_array($qhandle,$type=MYSQL_BOTH) {
        return @mysql_fetch_array($qhandle,$type);
}

function db_fetch_row($qhandle) {
        return @mysql_fetch_row($qhandle);
}

function db_fetch_field($qhandle, $field) {
        return @mysql_fetch_field($qhandle, $field);
}

function db_insertid($qhandle) {
        return @mysql_insert_id($qhandle);
}

function db_error() {
        return "\n\n<P><B>".@mysql_error()."</B><P>\n\n";
}

db_connect();

?>

