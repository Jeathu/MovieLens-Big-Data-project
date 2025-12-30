#!/usr/bin/env bash
set -euo pipefail

# Usage: bootstrap_master.sh <hadoop_password> <hadoop_version> <hive_version> <admin_user>
HADOOP_PASS=${1:-"password"}
HADOOP_VERSION=${2:-"3.3.6"}
HIVE_VERSION=${3:-"3.1.3"}
ADMIN=${4:-"hadoopadmin"}



# LOG ALL OUTPUT TO A FILE ON THE MASTER
exec > >(tee -i /home/${ADMIN}/bootstrap.log) 2>&1



# Installaton java jdk8
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-8-jdk curl wget unzip pdsh ssh


# Créate hadoop user et set sudo privileges
if ! id -u hadoop >/dev/null 2>&1; then
  sudo useradd -m -s /bin/bash hadoop
  echo "hadoop:${HADOOP_PASS}" | sudo chpasswd
  echo "hadoop ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/hadoop
fi
echo "${ADMIN} ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/${ADMIN}



# Mettre à jour /etc/hosts
if [ -f /tmp/hosts_entries ]; then
  sudo sed -i '/hadoop-master/d' /etc/hosts
  sudo sed -i '/hadoop-worker/d' /etc/hosts
  cat /tmp/hosts_entries | sudo tee -a /etc/hosts
else
  echo "10.0.1.4 hadoop-master" | sudo tee -a /etc/hosts
  echo "10.0.1.5 hadoop-worker1" | sudo tee -a /etc/hosts
  echo "10.0.1.6 hadoop-worker2" | sudo tee -a /etc/hosts
fi



# SSH configuration pour hadoop user
echo "[bootstrap_master] 4/13 Configuring SSH passwordless for hadoop..."
sudo mkdir -p /home/hadoop/.ssh
sudo chmod 700 /home/hadoop/.ssh
sudo chown -R hadoop:hadoop /home/hadoop/.ssh

if [ ! -f /home/hadoop/.ssh/id_rsa ]; then
  sudo -u hadoop ssh-keygen -t rsa -P "" -f /home/hadoop/.ssh/id_rsa
fi
sudo -u hadoop sh -c 'cat /home/hadoop/.ssh/id_rsa.pub >> /home/hadoop/.ssh/authorized_keys'
sudo -u hadoop sh -c 'sort -u /home/hadoop/.ssh/authorized_keys > /home/hadoop/.ssh/authorized_keys.tmp && mv /home/hadoop/.ssh/authorized_keys.tmp /home/hadoop/.ssh/authorized_keys'
sudo chmod 600 /home/hadoop/.ssh/authorized_keys
sudo chown -R hadoop:hadoop /home/hadoop/.ssh

sudo -u hadoop bash -c 'cat > /home/hadoop/.ssh/config <<EOF
Host *
  StrictHostKeyChecking no
  UserKnownHostsFile=/dev/null
EOF'
sudo chmod 600 /home/hadoop/.ssh/config
sudo chown hadoop:hadoop /home/hadoop/.ssh/config





# Test SSH
echo "[bootstrap_master] 5/13 Testing SSH..."
sudo -iu hadoop ssh localhost 'echo "SSH localhost: OK"'


# Télécharger HADOOP
echo "[bootstrap_master] Downloading Hadoop ${HADOOP_VERSION}..."
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


# Installer HADOOP
echo "[bootstrap_master] 7/13 Extracting Hadoop..."
sudo rm -rf /opt/hadoop
sudo mkdir -p /opt/hadoop
sudo tar -xzf "$HADOOP_TAR" -C /opt/hadoop --strip-components=1
sudo chown -R hadoop:hadoop /opt/hadoop


# VARIABLES D'ENVIRONNEMENT
echo "[bootstrap_master] 8/13 Configuring Hadoop Environment..."
sudo -u hadoop bash -c 'cat > /home/hadoop/.bashrc_hadoop <<EOF
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HADOOP_HOME=/opt/hadoop
export HADOOP_INSTALL=\$HADOOP_HOME
export PATH=\$PATH:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin
export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop
export HIVE_HOME=/opt/hive
export PATH=\$PATH:\$HIVE_HOME/bin
export PDSH_RCMD_TYPE=ssh
EOF'

if ! grep -q ".bashrc_hadoop" /home/hadoop/.bashrc; then
  echo "source /home/hadoop/.bashrc_hadoop" | sudo tee -a /home/hadoop/.bashrc
fi

echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" | sudo tee -a /opt/hadoop/etc/hadoop/hadoop-env.sh
echo "export PDSH_RCMD_TYPE=ssh" | sudo tee -a /opt/hadoop/etc/hadoop/hadoop-env.sh



# CREER LE FICHIER WORKERs
echo "[bootstrap_master] Creating workers file..."
sudo -u hadoop bash -c 'cat > /opt/hadoop/etc/hadoop/workers <<EOF
hadoop-worker1
hadoop-worker2
EOF'



# FICHIERS DE CONFIGURATION (XML)
echo "[bootstrap_master] Writing Hadoop XML configs..."
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
  <property><name>dfs.namenode.name.dir</name><value>/home/hadoop/hadoopdata/namenode</value></property>
  <property><name>dfs.datanode.data.dir</name><value>/home/hadoop/hadoopdata/datanode</value></property>
  <property><name>dfs.namenode.http-address</name><value>hadoop-master:9870</value></property>
</configuration>
EOF'

sudo -u hadoop bash -c 'cat > /opt/hadoop/etc/hadoop/yarn-site.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <property><name>yarn.nodemanager.aux-services</name><value>mapreduce_shuffle</value></property>
  <property><name>yarn.resourcemanager.hostname</name><value>hadoop-master</value></property>
  <property><name>yarn.nodemanager.env-whitelist</name><value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,HADOOP_YARN_HOME,HADOOP_MAPRED_HOME</value></property>
</configuration>
EOF'

sudo -u hadoop bash -c 'cat > /opt/hadoop/etc/hadoop/mapred-site.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <property><name>mapreduce.framework.name</name><value>yarn</value></property>
  <property><name>mapreduce.application.classpath</name><value>/opt/hadoop/share/hadoop/mapreduce/*:/opt/hadoop/share/hadoop/mapreduce/lib/*</value></property>
</configuration>
EOF'

sudo -u hadoop mkdir -p /home/hadoop/hadoopdata/namenode
sudo -u hadoop mkdir -p /home/hadoop/hadoopdata/datanode
sudo chown -R hadoop:hadoop /home/hadoop/hadoopdata




# TELECHARGER HIVE
echo "[bootstrap_master] Downloading Hive ${HIVE_VERSION}..."
HIVE_TAR="apache-hive-${HIVE_VERSION}-bin.tar.gz"
HIVE_URL="https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}/${HIVE_TAR}"

cd /tmp
if [ ! -f "$HIVE_TAR" ] || [ $(stat -c%s "$HIVE_TAR") -lt 1000000 ]; then
  rm -f "$HIVE_TAR"
  wget -q --show-progress --timeout=300 "$HIVE_URL" || curl -O "$HIVE_URL"
fi

# INSTALLER HIVE
echo "[bootstrap_master] Extracting Hive..."
sudo rm -rf /opt/hive
sudo mkdir -p /opt/hive
sudo tar -xzf "$HIVE_TAR" -C /opt/hive --strip-components=1
sudo chown -R hadoop:hadoop /opt/hive

# Hive config
sudo -u hadoop bash -c 'cat > /opt/hive/conf/hive-site.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <property><name>javax.jdo.option.ConnectionURL</name><value>jdbc:derby:;databaseName=/home/hadoop/metastore_db;create=true</value></property>
  <property><name>hive.metastore.warehouse.dir</name><value>/user/hive/warehouse</value></property>
</configuration>
EOF'

sudo -u hadoop mkdir -p /home/hadoop/hive/warehouse
sudo -u hadoop mkdir -p /tmp/hive
sudo chmod 777 /tmp/hive


# VERIFICATIONS FINALES
echo "[bootstrap_master] Final checks..."
if [ -x /opt/hadoop/bin/hdfs ]; then
  echo "HDFS binary found: OK"
else
  echo "ERROR: HDFS binary not found at /opt/hadoop/bin/hdfs"
  exit 1
fi

echo "[bootstrap_master] INSTALLATION SUCCESSFUL!"
exit 0
