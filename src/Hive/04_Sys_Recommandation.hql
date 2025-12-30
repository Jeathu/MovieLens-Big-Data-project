-- ============================================================================
-- SYSTÈME DE RECOMMANDATION - MovieLens
-- ============================================================================

-- Configuration de l'affichage Hive Standard
SET hive.cli.print.header=true;
SET hive.resultset.use.unique.column.names=false;


-- Vue des favoris
DROP VIEW IF EXISTS user_favorites;
CREATE VIEW user_favorites AS
SELECT user_id, movie_id, rating
FROM ratings
WHERE rating >= 4;




-- ============================================================================
-- COLLABORATIVE FILTERING SIMPLE
-- ============================================================================
-- Recommandations basées sur des utilisateurs similaires

SELECT 
    t.title, 
    t.genres, 
    t.avg_rating, 
    t.num_recommendations
FROM (
    SELECT 
        m.title,
        m.genres,
        ROUND(AVG(r.rating), 2) as avg_rating,
        COUNT(*) as num_recommendations
    FROM ratings r
    JOIN movies m ON r.movie_id = m.movie_id
    JOIN (
        -- Utilisateurs similaires
        SELECT DISTINCT r2.user_id
        FROM ratings r1
        JOIN ratings r2 ON r1.movie_id = r2.movie_id
        WHERE r1.user_id = 1 
        AND r2.user_id != 1
        AND r1.rating >= 4 
        AND r2.rating >= 4
    ) similar_users ON r.user_id = similar_users.user_id
    LEFT JOIN (
        -- Exclusion des films vus
        SELECT movie_id FROM ratings WHERE user_id = 1
    ) seen_movies ON r.movie_id = seen_movies.movie_id
    WHERE seen_movies.movie_id IS NULL
    AND r.rating >= 4
    GROUP BY m.movie_id, m.title, m.genres
    HAVING COUNT(*) >= 5
) t
ORDER BY t.avg_rating DESC, t.num_recommendations DESC
LIMIT 10;




-- ============================================================================
-- CONTENT-BASED FILTERING
-- ============================================================================
-- Recommandations basées sur le genre préféré

SELECT 
    t2.title, 
    t2.genres, 
    t2.avg_rating
FROM (
    SELECT 
        m.title,
        m.genres,
        ROUND(AVG(r.rating), 2) as avg_rating
    FROM ratings r
    JOIN movies m ON r.movie_id = m.movie_id
    JOIN (
        -- Explosion des genres
        SELECT movie_id, genre 
        FROM movies 
        LATERAL VIEW explode(split(genres, '[|]')) t AS genre
    ) m_exploded ON r.movie_id = m_exploded.movie_id
    JOIN (
        -- Genre préféré de l'utilisateur
        SELECT 
            g.genre as preferred_genre,
            AVG(r_user.rating) as user_avg_rating, 
            COUNT(*) as genre_count 
        FROM ratings r_user
        JOIN (
            SELECT movie_id, genre 
            FROM movies 
            LATERAL VIEW explode(split(genres, '[|]')) t AS genre
        ) g ON r_user.movie_id = g.movie_id
        WHERE r_user.user_id = 1
        GROUP BY g.genre
        ORDER BY user_avg_rating DESC, genre_count DESC 
        LIMIT 1
    ) user_pref ON m_exploded.genre = user_pref.preferred_genre
    LEFT JOIN (
         -- Exclusion des films vus
         SELECT movie_id FROM ratings WHERE user_id = 1
    ) seen ON r.movie_id = seen.movie_id
    WHERE seen.movie_id IS NULL
    GROUP BY m.movie_id, m.title, m.genres
    HAVING COUNT(*) >= 50
) t2
ORDER BY t2.avg_rating DESC
LIMIT 10;
