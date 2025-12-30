

----------------------------------------
-- PARTITIONNEMENT
----------------------------------------


#### partitionné par note (rating)
``` sql
hive> SHOW PARTITIONS ratings_partitioned;
OK

rating=1
rating=2
rating=3
rating=4
rating=5
Time taken: 0.065 seconds, Fetched: 5 row(s)

hive> SELECT COUNT(*) as excellent_ratings
    > FROM ratings_partitioned
    > WHERE rating = 5;
OK
226310
Time taken: 0.248 seconds, Fetched: 1 row(s)
hive>

/*  Donc comme on peut voir que dans le 1 million de notes, il y a 226310 notes de 5/5 */
```




#### partitionné par genre (gender)
``` sql
SELECT 
    CASE age
        WHEN 1 THEN 'Under 18'
        WHEN 18 THEN '18-24'
        WHEN 25 THEN '25-34'
        WHEN 35 THEN '35-44'
        WHEN 45 THEN '45-49'
        WHEN 50 THEN '50-55'
        ELSE '56+'
    END as age_group,
    COUNT(*) as count
FROM users_partitioned
WHERE gender = 'F'
GROUP BY age
ORDER BY age;


/*
Total MapReduce CPU Time Spent: 5 seconds 720 msec
OK
Under 18        78
18-24   298
25-34   558
35-44   338
45-49   189
50-55   146
56+     102
Time taken: 40.999 seconds, Fetched: 7 row(s)
hive>
*/
```


``` sql
-- Charger avec l'année extraite du timestamp Unix
INSERT OVERWRITE TABLE ratings_by_year PARTITION (year_rated)
SELECT 
    user_id,
    movie_id,
    rating,
    timestamp_val,
    YEAR(FROM_UNIXTIME(timestamp_val)) as year_rated
FROM ratings;



hive> SHOW PARTITIONS ratings_by_year;
OK
year_rated=2000
year_rated=2001
year_rated=2002
year_rated=2003
Time taken: 0.037 seconds, Fetched: 4 row(s)
hive> SELECT COUNT(*) as ratings_2000
    > FROM ratings_by_year
    > WHERE year_rated = 2000;
OK
904757
Time taken: 0.141 seconds, Fetched: 1 row(s)
hive>
*/
```







-----------------------------------------
 BUCKET
________________________________________

``` sql
CREATE TABLE IF NOT EXISTS ratings_bucketed (
    user_id INT,
    movie_id INT,
    rating INT,
    timestamp_val BIGINT
)
CLUSTERED BY (user_id) INTO 10 BUCKETS
STORED AS TEXTFILE;

-- Activer le bucketing
SET hive.enforce.bucketing = true;

-- Charger les données
INSERT OVERWRITE TABLE ratings_bucketed
SELECT user_id, movie_id, rating, timestamp_val
FROM ratings;
```



``` sql

/* 
DESCRIBE FORMATTED ratings_bucketed;
Ce qu'il faut chercher dans la sortie :

Num Buckets: doit être à 10.
Bucket Columns: doit afficher [user_id].
*/


hive> SELECT COUNT(*) FROM ratings_bucketed TABLESAMPLE(BUCKET 1 OUT OF 10 ON user_id);

Total MapReduce CPU Time Spent: 5 seconds 70 msec
OK
114383
Time taken: 18.986 seconds, Fetched: 1 row(s)
hive>
```




``` sql
CREATE TABLE IF NOT EXISTS users_bucketed (
    user_id INT,
    gender STRING,
    age INT,
    occupation INT,
    zipcode STRING
)
CLUSTERED BY (user_id) INTO 10 BUCKETS
STORED AS TEXTFILE;

-- Charger les données
INSERT OVERWRITE TABLE users_bucketed
SELECT user_id, gender, age, occupation, zipcode
FROM users;


-- ---------------------------------------------------------------------------
-- 2.3 : Jointure optimisée avec BUCKET MAP JOIN
-- ---------------------------------------------------------------------------
-- Quand les deux tables ont le même nombre de buckets sur la même colonne,
-- Hive peut faire une jointure très efficace (bucket map join)

SET hive.optimize.bucketmapjoin = true;
SET hive.optimize.bucketmapjoin.sortedmerge = true




-- Jointure optimisée
SELECT 
    u.gender,
    u.age,
    AVG(r.rating) as avg_rating,
    COUNT(*) as num_ratings
FROM ratings_bucketed r
JOIN users_bucketed u ON r.user_id = u.user_id
GROUP BY u.gender, u.age
ORDER BY u.gender, u.age;


/* Total MapReduce CPU Time Spent: 8 seconds 580 msec
OK
F       1       3.616290925569276       8827
F       18      3.4531446056310124      45427
F       25      3.6067002408583315      91340
F       35      3.6596527398783176      49473
F       45      3.663044379925342       24110
F       50      3.7971102745792735      18064
F       56      3.915534297206218       9199
M       1       3.5174608355091386      18384
M       18      3.525476254262937       138109
M       25      3.52678031398743        304216
M       35      3.604433892864308       149530
M       45      3.627942140013104       59523
M       50      3.687098078124426       54426
M       56      3.720327237077854       29581
Time taken: 51.242 seconds, Fetched: 14 row(s)
hive>
*/
```



-- ---------------------------------------------------------------------------
-- 2.4 : Échantillonnage avec les BUCKETS
-- ---------------------------------------------------------------------------
-- Les buckets permettent de faire un échantillonnage efficace

-- Prendre 1 bucket sur 10 (10% des données)
SELECT COUNT(*) as sample_size
FROM ratings_bucketed
TABLESAMPLE(BUCKET 1 OUT OF 10 ON user_id);

Total MapReduce CPU Time Spent: 5 seconds 100 msec
OK
114383
Time taken: 18.915 seconds, Fetched: 1 row(s)
hive>


/*
114383/1000000 = 0.114383
*/





-- Prendre 3 buckets sur 10 (30% des données)
SELECT AVG(rating) as avg_rating_sample
FROM ratings_bucketed
TABLESAMPLE(BUCKET 1 OUT OF 10 ON user_id)
UNION ALL
SELECT AVG(rating)
FROM ratings_bucketed
TABLESAMPLE(BUCKET 2 OUT OF 10 ON user_id)
UNION ALL
SELECT AVG(rating)
FROM ratings_bucketed
TABLESAMPLE(BUCKET 3 OUT OF 10 ON user_id);



MapReduce Jobs Launched: 
Stage-Stage-1: Map: 1  Reduce: 1   Cumulative CPU: 4.6 sec   HDFS Read: 21610210 HDFS Write: 121 SUCCESS
Stage-Stage-3: Map: 1  Reduce: 1   Cumulative CPU: 5.09 sec   HDFS Read: 21610213 HDFS Write: 121 SUCCESS
Stage-Stage-4: Map: 1  Reduce: 1   Cumulative CPU: 5.65 sec   HDFS Read: 21610207 HDFS Write: 121 SUCCESS
Stage-Stage-2: Map: 3   Cumulative CPU: 5.11 sec   HDFS Read: 11826 HDFS Write: 352 SUCCESS
Total MapReduce CPU Time Spent: 20 seconds 450 msec
OK
3.552118758906481
3.598218333037703
3.6092911268383694
Time taken: 92.05 seconds, Fetched: 3 row(s)
hive>
















-- ============================================================================
-- PARTIE 3 : COMBINAISON PARTITIONS + BUCKETS
-- ============================================================================
-- La combinaison des deux techniques offre le meilleur des deux mondes
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 3.1 : Table ratings avec PARTITIONS par rating ET BUCKETS par user_id
-- ---------------------------------------------------------------------------




hive> SHOW PARTITIONS ratings_optimized;
OK
rating=1
rating=2
rating=3
rating=4
rating=5
Time taken: 0.042 seconds, Fetched: 5 row(s)
hive> DESCRIBE FORMATTED ratings_optimized;
OK
# col_name              data_type               comment
user_id                 int
movie_id                int
timestamp_val           bigint
                 
# Partition Information          
# col_name              data_type               comment
rating                  int
                 
# Detailed Table Information             
Database:               movielens                
OwnerType:              USER
Owner:                  hadoop
CreateTime:             Sun Dec 28 19:59:01 UTC 2025
LastAccessTime:         UNKNOWN
Retention:              0
Location:               hdfs://hadoop-master:9000/user/hive/warehouse/movielens.db/ratings_optimized
Table Type:             MANAGED_TABLE
Table Parameters:
        COLUMN_STATS_ACCURATE   {\"BASIC_STATS\":\"true\"}
        bucketing_version       2
        numFiles                40
        numPartitions           5
        numRows                 1000209
        rawDataSize             18592877
        totalSize               19593086
        transient_lastDdlTime   1766951941

Table Parameters:
        COLUMN_STATS_ACCURATE   {\"BASIC_STATS\":\"true\"}
        bucketing_version       2
        numFiles                40
        numPartitions           5
        numRows                 1000209
        rawDataSize             18592877
        totalSize               19593086
        transient_lastDdlTime   1766951941
Table Parameters:
        COLUMN_STATS_ACCURATE   {\"BASIC_STATS\":\"true\"}
        bucketing_version       2
        numFiles                40
        numPartitions           5
        numRows                 1000209
        rawDataSize             18592877
        totalSize               19593086
Table Parameters:
        COLUMN_STATS_ACCURATE   {\"BASIC_STATS\":\"true\"}
        bucketing_version       2
        numFiles                40
        numPartitions           5
        numRows                 1000209
        rawDataSize             18592877
Table Parameters:
        COLUMN_STATS_ACCURATE   {\"BASIC_STATS\":\"true\"}
        bucketing_version       2
        numFiles                40
        numPartitions           5
        numRows                 1000209
Table Parameters:
        COLUMN_STATS_ACCURATE   {\"BASIC_STATS\":\"true\"}
        bucketing_version       2
        numFiles                40
        numPartitions           5
Table Parameters:
        COLUMN_STATS_ACCURATE   {\"BASIC_STATS\":\"true\"}
        bucketing_version       2
        numFiles                40
Table Parameters:
        COLUMN_STATS_ACCURATE   {\"BASIC_STATS\":\"true\"}
        bucketing_version       2
Table Parameters:
        COLUMN_STATS_ACCURATE   {\"BASIC_STATS\":\"true\"}
Table Parameters:
        COLUMN_STATS_ACCURATE   {\"BASIC_STATS\":\"true\"}
        bucketing_version       2
        numFiles                40
        numPartitions           5
Table Parameters:
        COLUMN_STATS_ACCURATE   {\"BASIC_STATS\":\"true\"}
        bucketing_version       2
Table Parameters:
        COLUMN_STATS_ACCURATE   {\"BASIC_STATS\":\"true\"}
        COLUMN_STATS_ACCURATE   {\"BASIC_STATS\":\"true\"}
        bucketing_version       2
        numFiles                40
        bucketing_version       2
        numFiles                40
        numFiles                40
        numPartitions           5
        numPartitions           5
        numRows                 1000209
        rawDataSize             18592877
        totalSize               19593086
        transient_lastDdlTime   1766951941

# Storage Information
SerDe Library:          org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe
InputFormat:            org.apache.hadoop.mapred.TextInputFormat
OutputFormat:           org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat
Compressed:             No
Num Buckets:            8
Bucket Columns:         [user_id]
Sort Columns:           []
Storage Desc Params:
        serialization.format    1
Time taken: 0.089 seconds, Fetched: 38 row(s)
hive>












-- ---------------------------------------------------------------------------
-- 3.2 : Requête ultra-optimisée
-- ---------------------------------------------------------------------------
-- Cette requête bénéficie des deux optimisations:
-- 1. Partition pruning (rating = 5)
-- 2. Bucket sampling (10% des utilisateurs)

SELECT 
    movie_id,
    COUNT(*) as num_5star_ratings
FROM ratings_optimized
TABLESAMPLE(BUCKET 1 OUT OF 8 ON user_id)
WHERE rating = 5
GROUP BY movie_id
ORDER BY num_5star_ratings DESC
LIMIT 10;




MapReduce Jobs Launched: 
Stage-Stage-1: Map: 1  Reduce: 1   Cumulative CPU: 4.41 sec   HDFS Read: 4443210 HDFS Write: 48974 SUCCESS
Stage-Stage-2: Map: 1  Reduce: 1   Cumulative CPU: 2.63 sec   HDFS Read: 56560 HDFS Write: 290 SUCCESS
Total MapReduce CPU Time Spent: 7 seconds 40 msec
OK
2858    255
260     234
527     201
858     192
1196    186
1198    182
318     180
296     178
593     174
608     172
Time taken: 41.663 seconds, Fetched: 10 row(s)
hive>








-- ============================================================================
-- VÉRIFICATION FINALE
-- ============================================================================

SHOW TABLES;

-- Compter les lignes dans chaque table
SELECT 'ratings' as table_name, COUNT(*) as row_count FROM ratings
UNION ALL
SELECT 'ratings_partitioned', COUNT(*) FROM ratings_partitioned
UNION ALL
SELECT 'ratings_bucketed', COUNT(*) FROM ratings_bucketed
UNION ALL
SELECT 'ratings_optimized', COUNT(*) FROM ratings_optimized;




MapReduce Total cumulative CPU time: 6 seconds 860 msec
Ended Job = job_1766945762376_0034
MapReduce Jobs Launched: 
Stage-Stage-1: Map: 1  Reduce: 1   Cumulative CPU: 4.4 sec   HDFS Read: 24606339 HDFS Write: 125 SUCCESS
Stage-Stage-3: Map: 1  Reduce: 1   Cumulative CPU: 4.12 sec   HDFS Read: 19607915 HDFS Write: 137 SUCCESS
Stage-Stage-4: Map: 1  Reduce: 1   Cumulative CPU: 3.63 sec   HDFS Read: 21606936 HDFS Write: 134 SUCCESS
Stage-Stage-5: Map: 1  Reduce: 1   Cumulative CPU: 3.57 sec   HDFS Read: 19611780 HDFS Write: 135 SUCCESS
Stage-Stage-2: Map: 4   Cumulative CPU: 6.86 sec   HDFS Read: 19791 HDFS Write: 491 SUCCESS
Total MapReduce CPU Time Spent: 22 seconds 580 msec
OK
ratings_partitioned     1000209
ratings_optimized       1000209
ratings_bucketed        1000209
ratings 1000209
Time taken: 116.368 seconds, Fetched: 4 row(s)
hive>








