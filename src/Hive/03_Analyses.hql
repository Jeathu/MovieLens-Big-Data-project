
SET hive.cli.print.header=true;
SET hive.cli.print.current.db=true;
SET hive.resultset.use.unique.column.names=false;



----------------------------------------------------------------------------
-- Top 10 des films les mieux notés
----------------------------------------------------------------------------

-- Films avec au moins 100 votes pour éviter les biais
SELECT 
    m.title,
    m.genres,
    ROUND(AVG(r.rating), 2) as avg_rating,
    COUNT(*) as num_ratings
FROM ratings r
JOIN movies m ON r.movie_id = m.movie_id
GROUP BY m.movie_id, m.title, m.genres
HAVING COUNT(*) >= 100
ORDER BY avg_rating DESC
LIMIT 10;




-- Nombre de ratings par genre
SELECT 
    g.genre,
    COUNT(*) as total_ratings,
    ROUND(AVG(r.rating), 2) as avg_rating
FROM ratings r
JOIN (
    SELECT movie_id, genre 
    FROM movies 
    LATERAL VIEW explode(split(genres, '[|]')) t AS genre
) g ON r.movie_id = g.movie_id
GROUP BY g.genre
ORDER BY total_ratings DESC;




-- Comportement des utilisateurs par âge
SELECT 
    CASE 
        WHEN u.age = 1 THEN 'Under 18'
        WHEN u.age = 18 THEN '18-24'
        WHEN u.age = 25 THEN '25-34'
        WHEN u.age = 35 THEN '35-44'
        WHEN u.age = 45 THEN '45-49'
        WHEN u.age = 50 THEN '50-55'
        ELSE '56+'
    END as age_group,
    COUNT(DISTINCT u.user_id) as num_users,
    COUNT(*) as total_ratings,
    ROUND(AVG(r.rating), 2) as avg_rating
FROM ratings r
JOIN users u ON r.user_id = u.user_id
GROUP BY u.age
ORDER BY u.age;




-- Activité des utilisateurs par genre (H/F)
SELECT 
    u.gender,
    COUNT(DISTINCT u.user_id) as num_users,
    COUNT(*) as total_ratings,
    ROUND(AVG(r.rating), 2) as avg_rating
FROM ratings r
JOIN users u ON r.user_id = u.user_id
GROUP BY u.gender;










-- ============================================================================
-- ANALYSES AVANCÉES - MovieLens
-- ============================================================================


-- 1. Films les plus controversés (grande variance dans les notes)
SELECT 
    m.title,
    m.genres,
    ROUND(AVG(r.rating), 2) as avg_rating,
    ROUND(STDDEV(r.rating), 2) as rating_stddev,
    COUNT(*) as num_ratings
FROM ratings r
JOIN movies m ON r.movie_id = m.movie_id
GROUP BY m.movie_id, m.title, m.genres
HAVING COUNT(*) >= 100
ORDER BY rating_stddev DESC
LIMIT 10;




-- 2. Films les plus populaires (nombre de votes)
SELECT 
    m.title,
    m.genres,
    COUNT(*) as num_ratings,
    ROUND(AVG(r.rating), 2) as avg_rating
FROM ratings r
JOIN movies m ON r.movie_id = m.movie_id
GROUP BY m.movie_id, m.title, m.genres
ORDER BY num_ratings DESC
LIMIT 10;




-- 3. Genres préférés par tranche d'âge
SELECT 
    CASE 
        WHEN u.age = 1 THEN 'Under 18'
        WHEN u.age = 18 THEN '18-24'
        WHEN u.age = 25 THEN '25-34'
        WHEN u.age = 35 THEN '35-44'
        WHEN u.age = 45 THEN '45-49'
        WHEN u.age = 50 THEN '50-55'
        ELSE '56+'
    END as age_group,
    g.genre,
    COUNT(*) as num_ratings,
    ROUND(AVG(r.rating), 2) as avg_rating
FROM ratings r
JOIN users u ON r.user_id = u.user_id
JOIN (
    SELECT movie_id, genre 
    FROM movies 
    LATERAL VIEW explode(split(genres, '[|]')) t AS genre
) g ON r.movie_id = g.movie_id
GROUP BY u.age, g.genre
ORDER BY age_group, num_ratings DESC;




-- 4. Différence de goûts entre hommes et femmes
SELECT 
    g.genre,
    SUM(CASE WHEN u.gender = 'M' THEN 1 ELSE 0 END) as male_ratings,
    SUM(CASE WHEN u.gender = 'F' THEN 1 ELSE 0 END) as female_ratings,
    ROUND(AVG(CASE WHEN u.gender = 'M' THEN r.rating END), 2) as male_avg_rating,
    ROUND(AVG(CASE WHEN u.gender = 'F' THEN r.rating END), 2) as female_avg_rating
FROM ratings r
JOIN users u ON r.user_id = u.user_id
JOIN (
    SELECT movie_id, genre 
    FROM movies 
    LATERAL VIEW explode(split(genres, '[|]')) t AS genre
) g ON r.movie_id = g.movie_id
GROUP BY g.genre
ORDER BY (male_ratings + female_ratings) DESC;




-- 5. Utilisateurs les plus actifs
SELECT 
    u.user_id,
    u.gender,
    u.age,
    COUNT(*) as num_ratings,
    ROUND(AVG(r.rating), 2) as avg_rating
FROM ratings r
JOIN users u ON r.user_id = u.user_id
GROUP BY u.user_id, u.gender, u.age
ORDER BY num_ratings DESC
LIMIT 20;




-- 6. Genres qui reçoivent les meilleures notes
SELECT 
    g.genre,
    COUNT(*) as num_ratings,
    ROUND(AVG(r.rating), 2) as avg_rating,
    COUNT(DISTINCT r.movie_id) as num_movies
FROM ratings r
JOIN (
    SELECT movie_id, genre 
    FROM movies 
    LATERAL VIEW explode(split(genres, '[|]')) t AS genre
) g ON r.movie_id = g.movie_id
GROUP BY g.genre
HAVING COUNT(*) >= 1000
ORDER BY avg_rating DESC;