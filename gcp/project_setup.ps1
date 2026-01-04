# ============================================================
# GCP_SETUP.ps1  (A exécuter sur Windows / PowerShell)
# Objectif : projet + APIs + bucket + upload + cluster + SSH
# ============================================================

# ---------- CONFIG ----------
$PROJECT_ID   = "movielens-hadoop-2025-v2"
$PROJECT_NAME = "MovieLens Hadoop BigData V2"
$REGION       = "us-central1"
$ZONE         = "us-central1-b"
$BUCKET       = "gs://movielens-hadoop-bucket-v2"
$LOCAL_DATA   = "C:\Users\rania\Downloads\ml-1m"
$CLUSTER      = "cluster-movielens-v2"
# --------------------------------------------------

# 1) Login
gcloud auth login

# 2) Créer projet 
gcloud projects create $PROJECT_ID --name="$PROJECT_NAME"

# 3) Définir projet actif
gcloud config set project $PROJECT_ID

# 4) Facturation (manuel)
Write-Host " Active la facturation du projet dans la console Billing :"
Write-Host "https://console.cloud.google.com/billing"


# 5) Activer APIs
gcloud services enable dataproc.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable storage.googleapis.com

# 6) Créer bucket (si existe déjà, ignore l’erreur)
gsutil mb -p $PROJECT_ID -l $REGION $BUCKET

# 7) Upload dataset MovieLens
cd $LOCAL_DATA
gsutil cp movies.dat  "$BUCKET/ml-1m/"
gsutil cp ratings.dat "$BUCKET/ml-1m/"
gsutil cp users.dat   "$BUCKET/ml-1m/"

# 8) Vérifier
gsutil ls "$BUCKET/ml-1m/"

# 9) Créer cluster Dataproc
gcloud dataproc clusters create $CLUSTER `
  --region=$REGION `
  --zone=$ZONE `
  --master-machine-type=n1-standard-4 `
  --master-boot-disk-size=50GB `
  --worker-machine-type=n1-standard-4 `
  --worker-boot-disk-size=50GB `
  --num-workers=2 `
  --image-version=2.1-debian11

# 10) SSH vers le master
gcloud compute ssh "$CLUSTER-m" `
  --zone=$ZONE `
  --project=$PROJECT_ID
