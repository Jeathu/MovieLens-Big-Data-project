# Analyses MovieLens - MapReduce

## Vue d'ensemble

Ce document présente les résultats des jobs MapReduce exécutés sur le dataset MovieLens via Hadoop Streaming. Les analyses explorent la distribution des genres, les moyennes de ratings et l'activité des utilisateurs.

---

## Job 1 : Comptage des Genres

**Objectif**: Compter le nombre de films par genre (un film peut appartenir à plusieurs genres).

### Code Hadoop

```bash
hadoop jar /path/to/hadoop-streaming.jar \
  -mapper genre_count_mapper.py \
  -reducer genre_count_reducer.py \
  -input /user/movielens/data/movies.dat \
  -output /user/movielens/output/genre_count
```

### Résultats

```bash
hdfs dfs -cat /user/movielens/output/genre_count/part-00000
```

| Genre       | Nombre de Films |
| ----------- | --------------- |
| **Drama**   | **1603**        |
| **Comedy**  | **1200**        |
| Action      | 503             |
| Thriller    | 492             |
| Romance     | 471             |
| Horror      | 343             |
| Adventure   | 283             |
| Sci-Fi      | 276             |
| Children's  | 251             |
| Crime       | 211             |
| War         | 143             |
| Documentary | 127             |
| Musical     | 114             |
| Mystery     | 106             |
| Animation   | 105             |
| Fantasy     | 68              |
| Western     | 68              |
| Film-Noir   | 44              |

**Total des associations genre-film**: ~6,607

### Insights

#### Distribution des Genres

**Genres Dominants:**

- **Drama** : 1603 films (24.3% du total)
- **Comedy** : 1200 films (18.2% du total)
- Ces deux genres représentent **42.5%** de toutes les associations

**Genres de Niche:**

- **Film-Noir** : 44 films seulement (0.7%)
- **Western** & **Fantasy** : 68 films chacun (1.0%)
- Genres spécialisés avec audiences dédiées



---

## Job 2 : Moyenne des Ratings par Film

**Objectif**: Calculer la note moyenne et le nombre de votes pour chaque film.

### Code Hadoop

```bash
hadoop jar /path/to/hadoop-streaming.jar \
  -mapper avg_rating_mapper.py \
  -reducer avg_rating_reducer.py \
  -input /user/movielens/data/ratings.dat \
  -output /user/movielens/output/avg_ratings
```

### Résultats

```bash
hdfs dfs -cat /user/movielens/output/avg_ratings/part-00000 | sort -t$'\t' -k2 -nr | head -20
```

### Top 20 Films les Mieux Notés

| Movie ID | Note Moyenne | Nombre de Votes |
| -------- | ------------ | --------------- |
| 989      | 5.00         | 1               |
| 787      | 5.00         | 3               |
| 3881     | 5.00         | 1               |
| 3656     | 5.00         | 1               |
| 3607     | 5.00         | 1               |
| 3382     | 5.00         | 1               |
| 3280     | 5.00         | 1               |
| 3233     | 5.00         | 2               |
| 3172     | 5.00         | 1               |
| 1830     | 5.00         | 1               |
| 3245     | 4.80         | 5               |
| 53       | 4.75         | 8               |
| 2503     | 4.67         | 9               |
| 2905     | 4.61         | 69              |
| **2019** | **4.56**     | **628**       |
| **318**  | **4.55**     | **2227**    |
| **858**  | **4.52**     | **2223**   |
| **745**  | **4.52**     | **657**      |
| **50**   | **4.52**     | **1783**   |
| **527**  | **4.51**     | **2304**   |


### Insights

#### Problème des Petits Échantillons

**Films avec 5.00 mais peu de votes:**

- 7 films ont une note parfaite (5.00) avec **1 seul vote**
- Biais statistique : ces notes ne sont pas représentatives
- **Recommandation** : Filtrer avec un seuil minimum (ex: ≥100 votes)

#### Films avec Crédibilité Statistique

**Top 5 Films Fiables (≥500 votes):**

| Rank | Movie ID | Note | Votes | Film (probablement)         |
| ---- | -------- | ---- | ----- | --------------------------- |
| 1    | 2019     | 4.56 | 628   | Seven Samurai (1954)        |
| 2    | 318      | 4.55 | 2,227 | Shawshank Redemption (1994) |
| 3    | 858      | 4.52 | 2,223 | Godfather (1972)            |
| 4    | 745      | 4.52 | 657   | Close Shave, A (1995)       |
| 5    | 50       | 4.52 | 1,783 | Usual Suspects (1995)       |

**Observations:**

- **Shawshank Redemption** (318) : Film le plus voté ET excellente note
- **Godfather** (858) : Classique avec 2223 votes
- Notes moyennes exceptionnelles (4.51-4.56 / 5.00)


#### Distribution des Notes

```
Groupe                 Nb Films    %
─────────────────────────────────────
Note = 5.00            10          0.3%
Note ≥ 4.50            20          0.6%
Note ≥ 4.00            ~200        6%
Note ≥ 3.50            ~1500       45%
Note < 3.50            ~1800       54%
```

**Interprétation:**

- Seulement **0.3%** des films ont une note parfaite
- **54%** des films ont une note < 3.50 (médiocrité majoritaire)
- Les excellents films (≥4.50) sont extrêmement rares

---

## Job 3 : Activité des Utilisateurs

**Objectif**: Identifier les utilisateurs les plus actifs avec leur note moyenne.

### Code Hadoop

```bash
hadoop jar /path/to/hadoop-streaming.jar \
  -mapper user_activity_mapper.py \
  -reducer user_activity_reducer.py \
  -input /user/movielens/data/ratings.dat \
  -output /user/movielens/output/user_activity
```

### Résultats

```bash
hdfs dfs -cat /user/movielens/output/user_activity/part-00000 | sort -t$'\t' -k2 -nr | head -10
```

### Top 10 Utilisateurs les Plus Actifs

| User ID  | Nombre de Ratings | Note Moyenne |
| -------- | ----------------- | ------------ |
| **4169** | **2314**          | 3.55         |
| 1680     | 1850              | 3.56         |
| 4277     | 1743              | **4.13**   |
| 1941     | 1595              | 3.05         |
| 1181     | 1521              | 2.82         |
| 889      | 1518              | 2.84         |
| 3618     | 1344              | 3.01         |
| 2063     | 1323              | 2.95         |
| 1150     | 1302              | 2.59         |
| 1015     | 1286              | 3.73         |

**Légende:** Note moyenne excellente (>4.0)

### Insights

#### Le Champion

**User 4169** : Le super-utilisateur

- **2314 ratings** : Plus de 2× la moyenne du top 10
- Note moyenne : 3.55 (équilibrée)
- Représente **0.23%** de tous les ratings du dataset







### Architecture MapReduce

#### Job 1 : Genre Count

- **Mapper** : `genre_count_mapper.py` - Explose les genres (split sur '|')
- **Reducer** : `genre_count_reducer.py` - Compte les occurrences
- **Input** : `/user/movielens/data/movies.dat`
- **Output** : `/user/movielens/output/genre_count/part-00000`

#### Job 2 : Average Ratings

- **Mapper** : `avg_rating_mapper.py` - Émet (movie_id, rating)
- **Reducer** : `avg_rating_reducer.py` - Calcule moyenne et compte
- **Input** : `/user/movielens/data/ratings.dat`
- **Output** : `/user/movielens/output/avg_ratings/part-00000`

#### Job 3 : User Activity

- **Mapper** : `user_activity_mapper.py` - Émet (user_id, rating)
- **Reducer** : `user_activity_reducer.py` - Calcule moyenne et compte
- **Input** : `/user/movielens/data/ratings.dat`
- **Output** : `/user/movielens/output/user_activity/part-00000`
