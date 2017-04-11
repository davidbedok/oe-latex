#!/bin/bash

# usage: user database

/usr/local/mysql/bin/mysqladmin -u $1 -P 3306 --default-character-set=utf8 CREATE $2

/usr/local/mysql/bin/mysql -u $1 -P 3306 $2 < schema/language.sql
/usr/local/mysql/bin/mysql -u $1 -P 3306 $2 < initial/language.sql
