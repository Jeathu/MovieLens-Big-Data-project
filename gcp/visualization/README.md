VISUALISATION

0) Préparer un dossier “results” local (sur le cluster)
# Dossier local pour stocker les résultats récupérés depuis HDFS
mkdir -p ~/results

1) Récupérer les résultats MapReduce depuis HDFS
# Job 1 : moyenne par film
hdfs dfs -cat /user/movielens_db/output/avg_ratings/part-* > ~/results/avg_ratings.tsv

# Job 2 : top movies (IDs + avg + count)
hdfs dfs -cat /user/movielens_db/output/top_movies/part-* > ~/results/top_movies.tsv

# Job 3 : cooccurrence
hdfs dfs -cat /user/movielens_db/output/cooccurrence/part-* > ~/results/cooccurrence.tsv

2) Générer le script generate_visualizations.py

Uploader le rapport vers Cloud Storage
gsutil cp /tmp/rapport_movielens.html gs://movielens-hadoop-bucket-v2/reports/rapport_movielens.html

3) Télécharger sur ton PC (depuis PowerShell local)
gsutil cp gs://movielens-hadoop-bucket-v2/reports/rapport_movielens.html "$HOME\Downloads\rapport_movielens.html"

