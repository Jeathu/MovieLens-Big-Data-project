#!/usr/bin/env bash
set -euo pipefail

# Usage: bootstrap_worker.sh <hadoop_password> <hadoop_version> <admin_user>
HADOOP_PASS=${1:-"password"}
HADOOP_VERSION=${2:-"3.3.6"}
ADMIN=${3:-"hadoopadmin"}

# LOG
exec > >(tee -i /home/${ADMIN}/bootstrap.log) 2>&1

echo "[bootstrap_worker] Starting Hadoop worker installation..."

# Installation java jdk8
echo "[bootstrap_worker] Installing OpenJDK 8 and tools..."
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-8-jdk curl wget unzip pdsh ssh



# Créate hadoop user et set sudo privileges
echo "[bootstrap_worker]  Creating hadoop user..."
if ! id -u hadoop >/dev/null 2>&1; then
  sudo useradd -m -s /bin/bash hadoop
  echo "hadoop:${HADOOP_PASS}" | sudo chpasswd
  echo "hadoop ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/hadoop
fi
echo "${ADMIN} ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/${ADMIN}




# UPDATE /etc/hosts
echo "[bootstrap_worker] Configuring /etc/hosts..."
if [ -f /tmp/hosts_entries ]; then
  sudo sed -i '/hadoop-master/d' /etc/hosts
  sudo sed -i '/hadoop-worker/d' /etc/hosts
  cat /tmp/hosts_entries | sudo tee -a /etc/hosts
else
  echo "10.0.1.4 hadoop-master" | sudo tee -a /etc/hosts
  echo "10.0.1.5 hadoop-worker1" | sudo tee -a /etc/hosts
  echo "10.0.1.6 hadoop-worker2" | sudo tee -a /etc/hosts
fi



# 4. SSH CONFIG
echo "[bootstrap_worker] Configuring SSH..."
sudo mkdir -p /home/hadoop/.ssh
sudo chmod 700 /home/hadoop/.ssh
sudo chown -R hadoop:hadoop /home/hadoop/.ssh




# authorized_keys avec permissions correctes
sudo -u hadoop touch /home/hadoop/.ssh/authorized_keys
sudo chmod 600 /home/hadoop/.ssh/authorized_keys
sudo chown hadoop:hadoop /home/hadoop/.ssh/authorized_keys

sudo -u hadoop bash -c 'cat > /home/hadoop/.ssh/config <<EOF
Host *
  StrictHostKeyChecking no
  UserKnownHostsFile=/dev/null
EOF'
sudo chmod 600 /home/hadoop/.ssh/config
sudo chown hadoop:hadoop /home/hadoop/.ssh/config



# Télécharger HADOOP
echo "[bootstrap_worker]  Downloading Hadoop ${HADOOP_VERSION}..."
HADOOP_TAR="hadoop-${HADOOP_VERSION}.tar.gz"
HADOOP_URL="https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/${HADOOP_TAR}"

cd /tmp
if [ ! -f "$HADOOP_TAR" ] || [ $(stat -c%s "$HADOOP_TAR") -lt 1000000 ]; then
  rm -f "$HADOOP_TAR"
  echo "Downloading from Apache Archive..."
  wget -q --show-progress --timeout=300 "$HADOOP_URL" || curl -O "$HADOOP_URL"
fi

if [ ! -f "$HADOOP_TAR" ]; then
  echo "ERROR: Hadoop download failed!"
  exit 1
fi

# Extraire HADOOP
echo "[bootstrap_worker] Extracting Hadoop..."
sudo rm -rf /opt/hadoop
sudo mkdir -p /opt/hadoop
sudo tar -xzf "$HADOOP_TAR" -C /opt/hadoop --strip-components=1
sudo chown -R hadoop:hadoop /opt/hadoop



# ENV VARIABLES
echo "[bootstrap_worker]  Configuring Hadoop Environment..."
sudo -u hadoop bash -c 'cat > /home/hadoop/.bashrc_hadoop <<EOF
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HADOOP_HOME=/opt/hadoop
export HADOOP_INSTALL=$HADOOP_HOME
export PATH=$PATH:$HADOOP_HOME/sbin:$HADOOP_HOME/bin
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
EOF'

if ! grep -q ".bashrc_hadoop" /home/hadoop/.bashrc; then
  echo "source /home/hadoop/.bashrc_hadoop" | sudo tee -a /home/hadoop/.bashrc
fi

echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" | sudo tee -a /opt/hadoop/etc/hadoop/hadoop-env.sh

# 8. CONFIG XML
echo "[bootstrap_worker] Writing XML configs..."
sudo -u hadoop bash -c 'cat > /opt/hadoop/etc/hadoop/core-site.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <property><name>fs.defaultFS</name><value>hdfs://hadoop-master:9000</value></property>
  <property><name>hadoop.tmp.dir</name><value>/home/hadoop/hadoopdata</value></property>
</configuration>
EOF'

sudo -u hadoop bash -c 'cat > /opt/hadoop/etc/hadoop/hdfs-site.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <property><name>dfs.replication</name><value>2</value></property>
  <property><name>dfs.namenode.http-address</name><value>hadoop-master:9870</value></property>
  <property><name>dfs.datanode.data.dir</name><value>/home/hadoop/hadoopdata/datanode</value></property>
</configuration>
EOF'

sudo -u hadoop bash -c 'cat > /opt/hadoop/etc/hadoop/yarn-site.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <property><name>yarn.nodemanager.aux-services</name><value>mapreduce_shuffle</value></property>
  <property><name>yarn.resourcemanager.hostname</name><value>hadoop-master</value></property>
</configuration>
EOF'

sudo -u hadoop mkdir -p /home/hadoop/hadoopdata/datanode
sudo chown -R hadoop:hadoop /home/hadoop/hadoopdata



# VÉRIFICATION
echo "[bootstrap_worker] Double checking..."
if [ -x /opt/hadoop/bin/hdfs ]; then
  echo "HDFS binary: OK"
else
  echo "ERROR: HDFS binary not found!"
  exit 1
fi

echo "[bootstrap_worker] INSTALLATION SUCCESSFUL!"
exit 0
