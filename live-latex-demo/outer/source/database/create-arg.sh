#!/bin/bash

# usage: user password database

mysqladmin -u $1 -p$2 -P 3306 --default-character-set=utf8 CREATE $3

mysql -u $1 -p$2 -P 3306 $3 < schema/language.sql
mysql -u $1 -p$2 -P 3306 $3 < initial/language.sql
