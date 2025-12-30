-- Créer la base de données
CREATE DATABASE IF NOT EXISTS movielens;
USE movielens;

-- !clear;



-- Table RATINGS avec RegexSerDe
CREATE EXTERNAL TABLE IF NOT EXISTS ratings (
    user_id INT,
    movie_id INT,
    rating INT,
    timestamp_val BIGINT
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
WITH SERDEPROPERTIES (
  "input.regex" = "([^:]+)::([^:]+)::([^:]+)::([^:]+)"
)
STORED AS TEXTFILE
LOCATION '/user/movielens/ratings';



-- Table MOVIES avec RegexSerDe
CREATE EXTERNAL TABLE IF NOT EXISTS movies (
    movie_id INT,
    title STRING,
    genres STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
WITH SERDEPROPERTIES (
  "input.regex" = "([^:]+)::([^:]+)::(.+)"
)
STORED AS TEXTFILE
LOCATION '/user/movielens/movies';



-- Table USERS avec RegexSerDe
CREATE EXTERNAL TABLE IF NOT EXISTS users (
    user_id INT,
    gender STRING,
    age INT,
    occupation INT,
    zipcode STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
WITH SERDEPROPERTIES (
  "input.regex" = "([^:]+)::([^:]+)::([^:]+)::([^:]+)::(.+)"
)
STORED AS TEXTFILE
LOCATION '/user/movielens/users';






-- Vérifier que les tables sont bien chargées
SHOW TABLES;
SELECT * FROM ratings LIMIT 5;
SELECT * FROM movies LIMIT 5;
SELECT * FROM users LIMIT 5;


-- Nettoyer les tables (si besoin)
DROP TABLE IF EXISTS ratings;
DROP TABLE IF EXISTS movies;
DROP TABLE IF EXISTS users;


--- Compter le nombre de lignes dans chaque table
SELECT COUNT(*) FROM ratings;
SELECT COUNT(*) FROM movies;
SELECT COUNT(*) FROM users;