#!/bin/bash
# ============================================================
# CLUSTER_PIPELINE.sh  (A exécuter sur le cluster Dataproc)
# Objectif : GCS -> local -> HDFS -> Hive -> MapReduce -> résultats
# ============================================================

set -e

# ---------- CONFIG ----------
BUCKET="gs://movielens-hadoop-bucket-v2"
LOCAL_DIR="$HOME/ml-1m"
HDFS_BASE="/user/movielens_db"
SCRIPTS_DIR="$HOME/mapreduce_scripts"
REPO_MAPREDUCE_DIR="$HOME/movielens-bigdata/src/mapreduce"  
# --------------------------------------------------

echo "=== 1) Copier les .dat depuis GCS vers le cluster ==="
mkdir -p "$LOCAL_DIR"
gsutil cp "$BUCKET/ml-1m/"*.dat "$LOCAL_DIR/"
ls -lh "$LOCAL_DIR/"

echo "=== 2) Créer structure HDFS ==="
hdfs dfs -mkdir -p "$HDFS_BASE/movies" "$HDFS_BASE/ratings" "$HDFS_BASE/users" "$HDFS_BASE/output"
hdfs dfs -ls "$HDFS_BASE"

echo "=== 3) Uploader dans HDFS ==="
hdfs dfs -rm -f "$HDFS_BASE/movies/movies.dat" || true
hdfs dfs -rm -f "$HDFS_BASE/ratings/ratings.dat" || true
hdfs dfs -rm -f "$HDFS_BASE/users/users.dat" || true

hdfs dfs -put "$LOCAL_DIR/movies.dat"  "$HDFS_BASE/movies/"
hdfs dfs -put "$LOCAL_DIR/ratings.dat" "$HDFS_BASE/ratings/"
hdfs dfs -put "$LOCAL_DIR/users.dat"   "$HDFS_BASE/users/"

hdfs dfs -ls "$HDFS_BASE/movies/"
hdfs dfs -ls "$HDFS_BASE/ratings/"
hdfs dfs -ls "$HDFS_BASE/users/"

echo "=== 4) Créer DB + tables Hive ==="
hive -e "
CREATE DATABASE IF NOT EXISTS movielens_db;
USE movielens_db;

DROP TABLE IF EXISTS movies;
DROP TABLE IF EXISTS ratings;
DROP TABLE IF EXISTS users;

CREATE EXTERNAL TABLE movies (
  movie_id INT,
  title STRING,
  genres STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
WITH SERDEPROPERTIES (
  'input.regex'='^(\\\\d+)::(.*)::(.*)$'
)
STORED AS TEXTFILE
LOCATION '$HDFS_BASE/movies';

CREATE EXTERNAL TABLE ratings (
  user_id INT,
  movie_id INT,
  rating INT,
  timestamp_val BIGINT
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
WITH SERDEPROPERTIES (
  'input.regex'='^(\\\\d+)::(\\\\d+)::(\\\\d+)::(\\\\d+)$'
)
STORED AS TEXTFILE
LOCATION '$HDFS_BASE/ratings';

CREATE EXTERNAL TABLE users (
  user_id INT,
  gender STRING,
  age INT,
  occupation INT,
  zipcode STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
WITH SERDEPROPERTIES (
  'input.regex'='^(\\\\d+)::([MF])::(\\\\d+)::(\\\\d+)::(\\\\d+)$'
)
STORED AS TEXTFILE
LOCATION '$HDFS_BASE/users';

SHOW TABLES;
"

echo "=== 5) Vérifier Hive ==="
hive -e "
USE movielens_db;
SELECT 'Films' as Type, COUNT(*) as Total FROM movies
UNION ALL
SELECT 'Ratings', COUNT(*) FROM ratings
UNION ALL
SELECT 'Users', COUNT(*) FROM users;
"
hive -e "USE movielens_db; SELECT * FROM movies LIMIT 5;"

echo "=== 6) Préparer scripts MapReduce ==="
mkdir -p "$SCRIPTS_DIR"
if [ -d "$REPO_MAPREDUCE_DIR" ]; then
  cp "$REPO_MAPREDUCE_DIR"/*.py "$SCRIPTS_DIR"/
fi

cd "$SCRIPTS_DIR"
chmod +x *.py || true
ls -lh

echo "=== 7) Lancer Job 1 (avg ratings) ==="
hdfs dfs -rm -r -f "$HDFS_BASE/output/avg_ratings" || true
mapred streaming \
  -files mapper_avg_rating.py,reducer_avg_rating.py \
  -mapper "python3 mapper_avg_rating.py" \
  -reducer "python3 reducer_avg_rating.py" \
  -input "$HDFS_BASE/ratings/ratings.dat" \
  -output "$HDFS_BASE/output/avg_ratings"

echo "=== 8) Lancer Job 2 (top 10) ==="
hdfs dfs -rm -r -f "$HDFS_BASE/output/top_movies" || true
mapred streaming \
  -files mapper_top_movies.py,reducer_top_movies.py \
  -mapper "python3 mapper_top_movies.py" \
  -reducer "python3 reducer_top_movies.py" \
  -input "$HDFS_BASE/ratings/ratings.dat" \
  -output "$HDFS_BASE/output/top_movies"

echo "=== 9) Lancer Job 3 (cooccurrence) ==="
hdfs dfs -rm -r -f "$HDFS_BASE/output/cooccurrence" || true
mapred streaming \
  -files mapper_cooccurrence.py,reducer_cooccurrence.py \
  -mapper "python3 mapper_cooccurrence.py" \
  -reducer "python3 reducer_cooccurrence.py" \
  -input "$HDFS_BASE/ratings/ratings.dat" \
  -output "$HDFS_BASE/output/cooccurrence"

echo "=== 10) Résultats ==="
yarn application -list -appStates ALL

echo "--- AVG (10 lignes) ---"
hdfs dfs -cat "$HDFS_BASE/output/avg_ratings/part-*" | head -10

echo "--- TOP MOVIES ---"
hdfs dfs -cat "$HDFS_BASE/output/top_movies/part-*"

echo "--- COOCCURRENCE (10 lignes) ---"
hdfs dfs -cat "$HDFS_BASE/output/cooccurrence/part-*" | head -10

