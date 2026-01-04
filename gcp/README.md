GCP – Dataproc Pipeline & Visualisations

Ce dossier contient toute la logique d’exécution du projet MovieLens sur Google Cloud Platform (GCP), depuis la création de l’infrastructure jusqu’à la génération des visualisations et du rapport final.

 Structure du dossier
gcp/
├── project_setup.ps1
├── CLUSTER_PIPELINE.sh
└── visualization/
    ├── generate_visualization.py
    ├── generate_html.py
    └── README.md

 Description des fichiers
project_setup.ps1

Script PowerShell (Windows) permettant de :

Authentifier l’utilisateur sur Google Cloud

Créer un nouveau projet GCP

Activer les APIs nécessaires :

Dataproc

Compute Engine

Cloud Storage

Créer un bucket Cloud Storage

Uploader les fichiers MovieLens (.dat)

Créer un cluster Dataproc

Se connecter automatiquement au nœud master

 À exécuter uniquement depuis votre machine locale (Windows).

CLUSTER_PIPELINE.sh

Script Bash exécuté sur le cluster Dataproc.

Il automatise :

La récupération des données depuis Cloud Storage

Le chargement dans HDFS

La création de la base et des tables Hive

L’exécution des jobs MapReduce

La préparation des résultats pour analyse

 À exécuter une fois connecté en SSH sur le nœud master du cluster.

 Dossier visualization/

Ce dossier contient les scripts permettant de transformer les résultats Big Data en analyses lisibles et présentables.

generate_visualization.py

Script Python qui génère des visualisations ASCII dans le terminal, à partir des résultats HDFS :

Top 15 films les plus populaires

Top 15 films les mieux notés

Distribution des notes (1 à 5 étoiles)

Répartition par genres

Activité par tranche d’âge

Comparaison hommes / femmes

Statistiques globales


generate_html.py

Script Python qui génère un rapport HTML professionnel, incluant :

Statistiques générales

Tableaux récapitulatifs

Graphiques

Design responsive avec CSS

Synthèse finale du projet

Le fichier HTML généré est ensuite :

stocké localement sur le cluster

uploadé sur Cloud Storage

téléchargeable sur le PC local

 Exécution des visualisations

Une fois les jobs MapReduce terminés :

cd ~/gcp/visualization
python3 generate_visualization.py


Pour générer le rapport HTML :

python3 generate_html.py

 Publication du rapport HTML
gsutil cp /tmp/rapport_movielens.html gs://<votre-bucket>/


Puis téléchargement sur le PC local :

gsutil cp gs://<votre-bucket>/rapport_movielens.html ~/Downloads/

