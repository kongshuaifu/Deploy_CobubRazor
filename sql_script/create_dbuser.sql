CREATE DATABASE razor_db;
CREATE DATABASE razor_dw;

CREATE USER 'razor'@'%' IDENTIFIED BY 'razor';

GRANT ALL PRIVILEGES ON `razor\_db`.* TO 'razor'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON `razor\_dw`.* TO 'razor'@'%' WITH GRANT OPTION;
