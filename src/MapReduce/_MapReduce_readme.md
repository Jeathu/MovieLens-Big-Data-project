# MapReduce Python Scripts pour MovieLens

<br>

## __*- Scripts importants :*__

| Mapper | Reducer | Description |
|--------|---------|-------------|
| `avg_rating_mapper.py` | `avg_rating_reducer.py` | Calcule la moyenne des ratings par film |
| `genre_count_mapper.py` | `genre_count_reducer.py` | Compte le nombre de films par genre |
| `user_activity_mapper.py` | `user_activity_reducer.py` | Analyse l'activité des utilisateurs |

---

<br>

##  __*- Comment exécuter avec Hadoop programemme map-reduce*__

### Prérequis
1. Copier les scripts Python sur le nœud master :
```bash
scp src/MapReduce/*.py azureuser@<IP_MASTER>:~/mapreduce/
```

2. Rendre les scripts exécutables :
```bash
chmod +x ~/mapreduce/*.py
```

---

<br>

## __*- Job 1 : Moyenne des ratings par film*__

```bash
hadoop jar $HADOOP_HOME/share/hadoop/tools/lib/hadoop-streaming-*.jar \
    -input /user/movielens/ratings/ratings.dat \
    -output /user/movielens/output/avg_ratings \
    -mapper "python3 avg_rating_mapper.py" \
    -reducer "python3 avg_rating_reducer.py" \
    -file ~/mapreduce/avg_rating_mapper.py \
    -file ~/mapreduce/avg_rating_reducer.py
```

### Voir les résultats :
```bash
hdfs dfs -cat /user/movielens/output/avg_ratings/part-00000 | head -20
```

---

<br>

## __*- Job 2 : Comptage des films par genre*__

```bash
hadoop jar $HADOOP_HOME/share/hadoop/tools/lib/hadoop-streaming-*.jar \
    -input /user/movielens/movies/movies.dat \
    -output /user/movielens/output/genre_count \
    -mapper "python3 genre_count_mapper.py" \
    -reducer "python3 genre_count_reducer.py" \
    -file ~/mapreduce/genre_count_mapper.py \
    -file ~/mapreduce/genre_count_reducer.py
```

### Voir les résultats :
```bash
hdfs dfs -cat /user/movielens/output/genre_count/part-00000
```

---

<br>

## __*- Job 3 : Activité des utilisateurs*__

```bash
hadoop jar $HADOOP_HOME/share/hadoop/tools/lib/hadoop-streaming-*.jar \
    -input /user/movielens/ratings/ratings.dat \
    -output /user/movielens/output/user_activity \
    -mapper "python3 user_activity_mapper.py" \
    -reducer "python3 user_activity_reducer.py" \
    -file ~/mapreduce/user_activity_mapper.py \
    -file ~/mapreduce/user_activity_reducer.py
```

### Voir les résultats (top 10 utilisateurs les plus actifs) :
```bash
hdfs dfs -cat /user/movielens/output/user_activity/part-00000 | sort -t$'\t' -k2 -nr | head -10
```



<br>
<br>

---
## ⚠️ Notes importantes (si il y des cas)

1. **Supprimer le dossier output avant chaque exécution** (Hadoop ne permet pas d'écrire dans un dossier existant) :
```bash
hdfs dfs -rm -r /user/movielens/output/avg_ratings
```

2. **Vérifier que Python 3 est installé sur tous les nœuds** :
```bash
python3 --version
```

3. **Localiser le JAR Hadoop Streaming** :
```bash
find $HADOOP_HOME -name "hadoop-streaming*.jar"
```
