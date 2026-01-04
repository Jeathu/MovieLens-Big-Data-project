# Analyses MovieLens - Hive analyse sur les  Films

## Vue d'ensemble

Ce document présente l'ensemble des analyses effectuées sur le dataset MovieLens en utilisant Apache Hive. Les analyses explorent les comportements des utilisateurs, les tendances des films et les patterns de notation.

---

## Analyses de Base

### 1. Top 10 Films Mieux Notés (≥100 votes)

**Objectif**: Identifier les films les plus appréciés avec un seuil minimum de votes pour éviter les biais.

```sql
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
```

**Résultats:**

| Titre                            | Genres                      | Note Moyenne | Nombre de votes |
| -------------------------------- | --------------------------- | ------------ | --------------- |
| Seven Samurai (1954)             | Action\|Drama               | 4.56         | 628             |
| Shawshank Redemption, The (1994) | Drama                       | 4.55         | 2227            |
| Close Shave, A (1995)            | Animation\|Comedy\|Thriller | 4.52         | 657             |
| Godfather, The (1972)            | Action\|Crime\|Drama        | 4.52         | 2223            |
| Usual Suspects, The (1995)       | Crime\|Thriller             | 4.52         | 1783            |
| Wrong Trousers, The (1993)       | Animation\|Comedy           | 4.51         | 882             |
| Schindler's List (1993)          | Drama\|War                  | 4.51         | 2304            |
| Sunset Blvd. (1950)              | Film-Noir                   | 4.49         | 470             |
| Rear Window (1954)               | Mystery\|Thriller           | 4.48         | 1050            |
| Raiders of the Lost Ark (1981)   | Action\|Adventure           | 4.48         | 2514            |



---

### 2. Distribution des Ratings par Genre

**Objectif**: Analyser la popularité et l'appréciation de chaque genre.

```sql
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
```

**Résultats:**

| Genre       | Total Ratings | Note Moyenne |
| ----------- | ------------- | ------------ |
| Drama       | 343,343       | 3.76         |
| Comedy      | 343,194       | 3.54         |
| Action      | 223,137       | 3.47         |
| Thriller    | 178,402       | 3.57         |
| Romance     | 142,769       | 3.60         |
| Sci-Fi      | 126,199       | 3.40         |
| Adventure   | 110,107       | 3.44         |
| Crime       | 75,591        | 3.69         |
| Horror      | 69,576        | 3.29         |
| Children's  | 68,543        | 3.46         |
| War         | 60,004        | 3.88         |
| Musical     | 41,323        | 3.67         |
| Animation   | 40,663        | 3.69         |
| Mystery     | 35,776        | 3.67         |
| Fantasy     | 30,077        | 3.38         |
| Western     | 20,204        | 3.66         |
| Film-Noir   | 18,261        | **4.08**     |
| Documentary | 6,960         | 3.97         |

** Insights:**

- **Drama** et **Comedy** sont les genres les plus populaires (>340K ratings chacun)
- **Film-Noir** a la meilleure note moyenne (4.08) malgré un faible nombre de ratings
- **Horror** est le genre le moins apprécié (3.29)
- Les genres **War** (3.88) et **Documentary** (3.97) sont très bien notés
- Forte corrélation entre popularité et variété (Drama, Comedy, Action)

---

### 3. Comportement des Utilisateurs par Âge

**Objectif**: Comprendre comment l'activité et les préférences varient selon l'âge.

```sql
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
```

**Résultats:**

| Groupe d'Âge | Nb Utilisateurs | Total Ratings | Note Moyenne |
| ------------ | --------------- | ------------- | ------------ |
| Under 18     | 222             | 27,211        | 3.55         |
| 18-24        | 1,103           | 183,536       | 3.51         |
| 25-34        | 2,096           | 395,556       | 3.55         |
| 35-44        | 1,193           | 199,003       | 3.62         |
| 45-49        | 550             | 83,633        | 3.64         |
| 50-55        | 496             | 72,490        | 3.71         |
| 56+          | 380             | 38,780        | **3.77**     |

**Insights:**

- Le groupe **25-34 ans** est le plus actif (395K ratings, 2096 utilisateurs)
- Les utilisateurs plus âgés donnent des notes plus élevées (tendance croissante avec l'âge)
- **56+** : note moyenne la plus élevée (3.77) mais moins actifs
- **18-24** : note moyenne la plus basse (3.51) mais très actifs
- Moyenne de ratings par utilisateur la plus élevée pour les 25-34 ans (~189 ratings/user)

---

### 4. Activité par Genre (Hommes vs Femmes)

**Objectif**: Comparer l'activité et les préférences entre hommes et femmes.

```sql
-- Activité des utilisateurs par genre (H/F)
SELECT
    u.gender,
    COUNT(DISTINCT u.user_id) as num_users,
    COUNT(*) as total_ratings,
    ROUND(AVG(r.rating), 2) as avg_rating
FROM ratings r
JOIN users u ON r.user_id = u.user_id
GROUP BY u.gender;
```

**Résultats:**

| Genre | Nb Utilisateurs | Total Ratings | Note Moyenne |
| ----- | --------------- | ------------- | ------------ |
| F     | 1,709           | 246,440       | **3.62**     |
| M     | 4,331           | 753,769       | 3.57         |

**Insights:**

- Les hommes représentent **72%** des utilisateurs (4331 vs 1709)
- Les hommes génèrent **75%** des ratings (754K vs 246K)
- Les femmes donnent des notes légèrement plus élevées (3.62 vs 3.57)
- Moyenne de ratings par utilisateur similaire (~144 pour F, ~174 pour M)

---

## Analyses Avancées

### 5. Films les Plus Controversés

**Objectif**: Identifier les films avec la plus grande variance d'opinions.

```sql
-- Films les plus controversés (grande variance dans les notes)
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
```

**Résultats:**

| Titre                          | Genres                    | Note Moy. | Écart-type | Nb Votes |
| ------------------------------ | ------------------------- | --------- | ---------- | -------- |
| Plan 9 from Outer Space (1958) | Horror\|Sci-Fi            | 2.63      | **1.45**   | 249      |
| Beloved (1998)                 | Drama                     | 3.13      | 1.37       | 104      |
| Godzilla 2000 (1999)           | Action\|Adventure\|Sci-Fi | 2.69      | 1.36       | 143      |
| Texas Chainsaw Massacre (1974) | Horror                    | 3.22      | 1.33       | 247      |
| Blair Witch Project (1999)     | Horror                    | 3.03      | 1.32       | 1,237    |
| Dumb & Dumber (1994)           | Comedy                    | 3.19      | 1.32       | 660      |
| Natural Born Killers (1994)    | Action\|Thriller          | 3.14      | 1.31       | 700      |
| Crash (1996)                   | Drama\|Thriller           | 2.76      | 1.31       | 141      |
| Idle Hands (1999)              | Comedy\|Horror            | 2.72      | 1.30       | 207      |
| Down to You (2000)             | Comedy\|Romance           | 2.69      | 1.30       | 122      |

**Insights:**

- Films **Horror** et **Comedy** dominent (audiences polarisées)
- Blair Witch Project : 1237 votes avec forte division d'opinions
- Écart-type élevé (1.30-1.45) indique "love it or hate it"
- Notes moyennes généralement basses (2.63-3.22)

---

### 6. Films les Plus Populaires

**Objectif**: Identifier les films avec le plus grand nombre de votes.

```sql
-- Films les plus populaires (nombre de votes)
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
```

**Résultats:**

| Titre                          | Genres                            | Nb Votes  | Note Moy. |
| ------------------------------ | --------------------------------- | --------- | --------- |
| American Beauty (1999)         | Comedy\|Drama                     | **3,428** | 4.32      |
| Jurassic Park (1993)           | Action\|Adventure\|Sci-Fi         | 2,672     | 3.76      |
| Saving Private Ryan (1998)     | Action\|Drama\|War                | 2,653     | 4.34      |
| Matrix, The (1999)             | Action\|Sci-Fi\|Thriller          | 2,590     | 4.32      |
| Back to the Future (1985)      | Comedy\|Sci-Fi                    | 2,583     | 3.99      |
| Silence of the Lambs (1991)    | Drama\|Thriller                   | 2,578     | **4.35**  |
| Men in Black (1997)            | Action\|Adventure\|Comedy\|Sci-Fi | 2,538     | 3.74      |
| Raiders of the Lost Ark (1981) | Action\|Adventure                 | 2,514     | 4.48      |
| Fargo (1996)                   | Crime\|Drama\|Thriller            | 2,513     | 4.25      |
| Sixth Sense, The (1999)        | Thriller                          | 2,459     | 4.41      |

**Insights:**

- Majoritairement des films des années **1990s** (8/10)
- Excellentes notes moyennes (3.74-4.48)
- American Beauty : le plus populaire avec 3428 votes

---

### 7. Genres Préférés par Tranche d'Âge

**Objectif**: Analyser les préférences de genres selon l'âge (top 5 par groupe).

```sql
-- Genres préférés par tranche d'âge
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
```

**Top 5 par Groupe d'Âge:**

| Groupe       | Genre #1         | Genre #2        | Genre #3        | Genre #4          | Genre #5           |
| ------------ | ---------------- | --------------- | --------------- | ----------------- | ------------------ |
| **Under 18** | Comedy (10,574)  | Drama (7,207)   | Action (5,542)  | Thriller (4,452)  | Children's (4,027) |
| **18-24**    | Comedy (66,491)  | Drama (56,081)  | Action (43,455) | Thriller (33,471) | Romance (24,626)   |
| **25-34**    | Comedy (137,744) | Drama (134,225) | Action (91,871) | Thriller (72,863) | Romance (56,059)   |
| **35-44**    | Drama (69,435)   | Comedy (67,061) | Action (43,765) | Thriller (34,812) | Romance (28,479)   |
| **45-49**    | Drama (31,205)   | Comedy (27,135) | Action (16,693) | Thriller (14,093) | Romance (12,944)   |
| **50-55**    | Drama (28,395)   | Comedy (22,498) | Action (14,795) | Thriller (12,494) | Romance (11,079)   |
| **56+**      | Drama (16,795)   | Comedy (11,691) | Action (7,016)  | Thriller (6,217)  | Romance (6,130)    |

**Insights:**

- **Under 18**: Seul groupe avec "Children's" dans le top 5
- **18-34 ans**: Comedy domine, préférence pour Action/Thriller
- **35+ ans**: Drama prend la première place (maturité des goûts)
- **Tous groupes**: Top 5 toujours Comedy, Drama, Action, Thriller, Romance
- Notes moyennes augmentent avec l'âge pour tous les genres

---

### 8. Différences Hommes vs Femmes par Genre

**Objectif**: Comparer les préférences de genres entre H/F.

```sql
-- Différence de goûts entre hommes et femmes
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
```

**Résultats avec Écart de Notes:**

| Genre       | Ratings H | Ratings F | Note H | Note F | **Écart (F-H)** |
| ----------- | --------- | --------- | ------ | ------ | --------------- |
| Drama       | 247,802   | 95,541    | 3.76   | 3.76   | **0.00**        |
| Comedy      | 249,844   | 93,350    | 3.52   | 3.59   | **+0.07**       |
| Action      | 183,718   | 39,419    | 3.47   | 3.47   | **0.00**        |
| Thriller    | 140,139   | 38,263    | 3.57   | 3.58   | **+0.01**       |
| Romance     | 93,676    | 49,093    | 3.56   | 3.67   | **+0.11**    |
| Sci-Fi      | 104,500   | 21,699    | 3.41   | 3.38   | **-0.03**       |
| Adventure   | 87,411    | 22,696    | 3.42   | 3.48   | **+0.06**       |
| Crime       | 59,926    | 15,665    | 3.70   | 3.68   | **-0.02**       |
| Horror      | 56,000    | 13,576    | 3.30   | 3.26   | **-0.04**       |
| Children's  | 48,181    | 20,362    | 3.40   | 3.61   | **+0.21**  |
| War         | 47,588    | 12,416    | 3.88   | 3.89   | **+0.01**       |
| Musical     | 27,876    | 13,447    | 3.60   | 3.81   | **+0.21**  |
| Animation   | 28,989    | 11,674    | 3.66   | 3.76   | **+0.10**       |
| Mystery     | 26,688    | 9,088     | 3.66   | 3.70   | **+0.04**       |
| Fantasy     | 22,718    | 7,359     | 3.35   | 3.48   | **+0.13**       |
| Western     | 16,818    | 3,386     | 3.68   | 3.58   | **-0.10**       |
| Film-Noir   | 14,059    | 4,202     | 4.09   | 4.02   | **-0.07**       |
| Documentary | 5,257     | 1,703     | 3.96   | 3.97   | **+0.01**       |

**Insights Clés:**

- **Children's** et **Musical**: +0.21 (plus grands écarts, femmes préfèrent)
- **Romance**: +0.11 (femmes préfèrent significativement)
- **Western**: -0.10 (hommes préfèrent)
- **Film-Noir**: -0.07 (hommes préfèrent légèrement)
- Hommes regardent **82%** des Action, **83%** des Sci-Fi
- Femmes représentent **34%** des Romance (surreprésentation relative)

---

### 9. Utilisateurs les Plus Actifs

**Objectif**: Identifier les utilisateurs power users.

```sql
-- Utilisateurs les plus actifs
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
```

**Top 20 Utilisateurs:**

| User ID | Genre | Âge | Nb Ratings | Note Moy. |
| ------- | ----- | --- | ---------- | --------- |
| 4169    | M     | 50  | **2,314**  | 3.55      |
| 1680    | M     | 25  | 1,850      | 3.56      |
| 4277    | M     | 35  | 1,743      | **4.13**  |
| 1941    | M     | 35  | 1,595      | 3.05      |
| 1181    | M     | 35  | 1,521      | 2.82      |
| 889     | M     | 45  | 1,518      | 2.84      |
| 3618    | M     | 56  | 1,344      | 3.01      |
| 2063    | M     | 25  | 1,323      | 2.95      |
| 1150    | **F** | 25  | 1,302      | 2.59      |
| 1015    | M     | 35  | 1,286      | 3.73      |

**Insights:**

- **19/20** utilisateurs les plus actifs sont des hommes
- User **4169** (M, 50 ans): champion avec 2314 ratings
- User **1150**: seule femme dans le top 20 (9ème position)
- User **4277**: meilleure note moyenne (4.13) parmi les actifs
- Groupe d'âge dominant: **25-35 ans** (40% du top 20)

---

### 10. Genres avec les Meilleures Notes

**Objectif**: Identifier les genres les mieux évalués (≥1000 ratings).

```sql
-- Genres qui reçoivent les meilleures notes
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
```

**Résultats:**

| Genre       | Nb Ratings | Note Moy. | Nb Films |
| ----------- | ---------- | --------- | -------- |
| Film-Noir   | 18,261     | **4.08**  | 44       |
| Documentary | 6,960      | 3.97      | 91       |
| War         | 60,004     | 3.88      | 132      |
| Drama       | 343,343    | 3.76      | 1,464    |
| Crime       | 75,591     | 3.69      | 194      |
| Animation   | 40,663     | 3.69      | 95       |
| Mystery     | 35,776     | 3.67      | 100      |
| Musical     | 41,323     | 3.67      | 111      |
| Western     | 20,204     | 3.66      | 65       |
| Romance     | 142,769    | 3.60      | 452      |
| Thriller    | 178,402    | 3.57      | 467      |
| Comedy      | 343,194    | 3.54      | 1,126    |
| Action      | 223,137    | 3.47      | 447      |
| Children's  | 68,543     | 3.46      | 223      |
| Adventure   | 110,107    | 3.44      | 251      |
| Sci-Fi      | 126,199    | 3.40      | 239      |
| Fantasy     | 30,077     | 3.38      | 60       |
| Horror      | 69,576     | 3.29      | 285      |

**Insights:**

- **Film-Noir**: meilleur genre (4.08) mais peu de films (44)
- **Documentary** et **War**: excellentes notes (3.97, 3.88)
- **Horror**: note la plus basse (3.29) malgré 285 films
- Corrélation inverse: genres niche = meilleures notes
- **Drama**: meilleur compromis (343K ratings, 3.76)

---



##  Métadonnées Techniques

- **Dataset**: MovieLens
- **Plateforme**: Apache Hive
- **Tables**: `ratings`, `movies`, `users`
- **Période d'analyse**: Snapshot du dataset MovieLens
- **Total Ratings**: ~1,000,000
- **Total Utilisateurs**: 6,040
- **Total Films**: ~3,900

---

_Analyses générées avec Apache Hive sur cluster Hadoop_
