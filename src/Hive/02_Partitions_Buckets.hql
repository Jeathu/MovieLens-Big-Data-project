-- ============================================================================
-- PARTITIONS ET BUCKETS DANS HIVE - MovieLens
-- ============================================================================

USE movielens;




-- ============================================================================
-- PARTIE 1 : PARTITIONS
-- ============================================================================


---------------------------------------
-- 1.1 : Table ratings PARTITIONNÉE par note (rating)
-- ---------------------------------------------------------------------------
-- Utile pour analyser rapidement les films par niveau de satisfaction



-- Créer la table partitionnée
CREATE TABLE IF NOT EXISTS ratings_partitioned (
    user_id INT,
    movie_id INT,
    timestamp_val BIGINT
)
PARTITIONED BY (rating INT)
STORED AS TEXTFILE;


-- Activer le mode partition dynamique
SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = nonstrict;


-- Charger les données avec partition dynamique
INSERT OVERWRITE TABLE ratings_partitioned PARTITION (rating)
SELECT 
    user_id,
    movie_id,
    timestamp_val,
    rating
FROM ratings;


-- Vérifier les partitions créées
SHOW PARTITIONS ratings_partitioned;


-- Requête optimisée : ne scanne QUE la partition rating=5
SELECT COUNT(*) as excellent_ratings
FROM ratings_partitioned
WHERE rating = 5;




-- ---------------------------------------------------------------------------
-- 1.2 : Table users PARTITIONNÉE par genre (M/F)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS users_partitioned (
    user_id INT,
    age INT,
    occupation INT,
    zipcode STRING
)
PARTITIONED BY (gender STRING)
STORED AS TEXTFILE;


-- Charger avec partition dynamique
INSERT OVERWRITE TABLE users_partitioned PARTITION (gender)
SELECT 
    user_id,
    age,
    occupation,
    zipcode,
    gender
FROM users;


-- Vérifier les partitions
SHOW PARTITIONS users_partitioned;


-- Requête optimisée : analyse des femmes uniquement
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





-- ---------------------------------------------------------------------------
-- 1.3 : Table ratings PARTITIONNÉE par année (extraction du timestamp)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ratings_by_year (
    user_id INT,
    movie_id INT,
    rating INT,
    timestamp_val BIGINT
)
PARTITIONED BY (year_rated INT)
STORED AS TEXTFILE;


-- Charger avec l'année extraite du timestamp Unix
INSERT OVERWRITE TABLE ratings_by_year PARTITION (year_rated)
SELECT 
    user_id,
    movie_id,
    rating,
    timestamp_val,
    YEAR(FROM_UNIXTIME(timestamp_val)) as year_rated
FROM ratings;


-- Voir les partitions (années)
SHOW PARTITIONS ratings_by_year;


-- Requête : ratings de l'année 2000 uniquement
SELECT COUNT(*) as ratings_2000
FROM ratings_by_year
WHERE year_rated = 2000;







-- ============================================================================
-- PARTIE 2 : BUCKETS (CLUSTERING)
-- ============================================================================
-- Les BUCKETS divisent les données en fichiers basés sur le hash d'une colonne.
-- Utile pour les jointures et l'échantillonnage.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 2.1 : Table ratings avec BUCKETS par user_id
-- ---------------------------------------------------------------------------
-- Optimise les jointures avec la table users

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


-- DESCRIBE FORMATTED ratings_bucketed;
-- SELECT COUNT(*) FROM ratings_bucketed TABLESAMPLE(BUCKET 1 OUT OF 10 ON user_id);



-- ---------------------------------------------------------------------------
-- 2.2 : Table users avec BUCKETS par user_id (même nombre de buckets!)
-- ---------------------------------------------------------------------------

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
SET hive.optimize.bucketmapjoin.sortedmerge = true;

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



-- ---------------------------------------------------------------------------
-- 2.4 : Échantillonnage avec les BUCKETS
-- ---------------------------------------------------------------------------
-- Les buckets permettent de faire un échantillonnage efficace


-- Prendre 1 bucket sur 10 (10% des données)
SELECT COUNT(*) as sample_size
FROM ratings_bucketed
TABLESAMPLE(BUCKET 1 OUT OF 10 ON user_id);


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




-- ============================================================================
-- PARTIE 3 : COMBINAISON PARTITIONS + BUCKETS
-- ============================================================================


-- ---------------------------------------------------------------------------
-- 3.1 : Table ratings avec PARTITIONS par rating ET BUCKETS par user_id
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ratings_optimized (
    user_id INT,
    movie_id INT,
    timestamp_val BIGINT
)
PARTITIONED BY (rating INT)
CLUSTERED BY (user_id) INTO 8 BUCKETS
STORED AS TEXTFILE;

SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = nonstrict;
SET hive.enforce.bucketing = true;


-- Charger les données
INSERT OVERWRITE TABLE ratings_optimized PARTITION (rating)
SELECT 
    user_id,
    movie_id,
    timestamp_val,
    rating
FROM ratings;


-- Vérifier la structure
SHOW PARTITIONS ratings_optimized;
DESCRIBE FORMATTED ratings_optimized;


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




-- ============================================================================
-- PARTIE 4 : TABLES AVEC FORMAT ORC
-- ============================================================================
-- ORC (Optimized Row Columnar) est le format recommandé pour Hive
-- Il offre compression et performances optimales
-- ============================================================================

CREATE TABLE IF NOT EXISTS ratings_orc (
    user_id INT,
    movie_id INT,
    rating INT,
    timestamp_val BIGINT
)
PARTITIONED BY (year_rated INT)
CLUSTERED BY (user_id) SORTED BY (user_id) INTO 8 BUCKETS
STORED AS ORC
TBLPROPERTIES ("orc.compress"="SNAPPY");


-- Charger depuis la table originale
INSERT OVERWRITE TABLE ratings_orc PARTITION (year_rated)
SELECT 
    user_id,
    movie_id,
    rating,
    timestamp_val,
    YEAR(FROM_UNIXTIME(timestamp_val)) as year_rated
FROM ratings;




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
