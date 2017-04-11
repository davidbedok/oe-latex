CREATE TABLE language (
  language_unid int(11) NOT NULL AUTO_INCREMENT,
  language_grid int(11) NOT NULL,
  language_name varchar(50) NOT NULL,
  language_constant varchar(50) NOT NULL,
  language_shortdateformat varchar(50) NOT NULL,
  language_longdateformat varchar(50) NOT NULL,
  PRIMARY KEY (language_unid),
  UNIQUE KEY UI_LANGUAGE_GRID (language_grid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
