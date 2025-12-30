#!/usr/bin/env bash
set -euo pipefail

# Usage: complete_setup.sh
# Etre exécuté sur le master après le bootstrap initial pour finaliser l'installation de Hadoop et Hive.

ADMIN=${SUDO_USER:-$(whoami)}

echo "=== Finalizing Hadoop setup ==="
sudo -iu hadoop bash -c 'source /home/hadoop/.bashrc || true'



# Formater le NameNode si ce n'est pas déjà fait
if [ ! -d "/home/hadoop/hadoopdata/namenode/current" ]; then
  echo "Formatting NameNode (only do this once)..."
  sudo -iu hadoop bash -c '/opt/hadoop/bin/hdfs namenode -format -force || true'
else
  echo "NameNode already formatted"
fi



# Démarrer les services Hadoop
echo "Starting HDFS services"
sudo -iu hadoop bash -c '/opt/hadoop/sbin/start-dfs.sh' || true

# Démarrer YARN
echo "Starting YARN services"
sudo -iu hadoop bash -c '/opt/hadoop/sbin/start-yarn.sh' || true




# Créer les répertoires Hive dans HDFS
echo "Creating Hive directories in HDFS..."
sudo -u hadoop /opt/hadoop/bin/hdfs dfs -mkdir -p /tmp
sudo -u hadoop /opt/hadoop/bin/hdfs dfs -chmod -R 777 /tmp
sudo -u hadoop /opt/hadoop/bin/hdfs dfs -mkdir -p /user/hive/warehouse
sudo -u hadoop /opt/hadoop/bin/hdfs dfs -chmod -R 777 /user/hive/warehouse



# Initialiser le Metastore de Hive
echo "Initializing Hive Metastore Schema..."
if [ ! -d "/home/hadoop/metastore_db" ]; then
  sudo -u hadoop /opt/hive/bin/schematool -dbType derby -initSchema
else
  echo "Metastore already initialized."
fi

echo "Hive version check"
sudo -u hadoop /opt/hive/bin/hive --version

echo "=== Finalization complete ==="
exit 0
