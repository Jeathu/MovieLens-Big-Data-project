#!/usr/bin/env bash
set -euo pipefail

echo "============================================"
echo "   HADOOP CLUSTER DIAGNOSTIC TOOL"
echo "============================================"
echo "Host: $(hostname)"
echo "Date: $(date)"
echo ""

# vérifier les entrées dans /etc/hosts
echo "=== 1. /etc/hosts Configuration ==="
grep -E "hadoop-master|hadoop-worker" /etc/hosts || echo "WARNING: No hadoop entries in /etc/hosts"
echo ""



# Vérifier le répertoire .ssh pour hadoop user
echo "=== 2. SSH Directory for hadoop user ==="
ls -la /home/hadoop/.ssh 2>/dev/null || echo "WARNING: /home/hadoop/.ssh missing"
echo ""


# Tester SSH sans mot de passe (seulement sur le master)
echo "=== 3. SSH Passwordless Test ==="
if [ "$(hostname)" = "hadoop-master" ]; then
  echo "Testing SSH to localhost..."
  sudo -iu hadoop ssh -o BatchMode=yes -o ConnectTimeout=5 localhost 'echo "  ✓ SSH localhost OK"' 2>/dev/null || echo "  ✗ SSH localhost FAILED"
  echo "Testing SSH to hadoop-master..."
  sudo -iu hadoop ssh -o BatchMode=yes -o ConnectTimeout=5 hadoop-master 'echo "  ✓ SSH hadoop-master OK"' 2>/dev/null || echo "  ✗ SSH hadoop-master FAILED"
  echo "Testing SSH to hadoop-worker1..."
  sudo -iu hadoop ssh -o BatchMode=yes -o ConnectTimeout=5 hadoop-worker1 'echo "  ✓ SSH hadoop-worker1 OK"' 2>/dev/null || echo "  ✗ SSH hadoop-worker1 FAILED"
  echo "Testing SSH to hadoop-worker2..."
  sudo -iu hadoop ssh -o BatchMode=yes -o ConnectTimeout=5 hadoop-worker2 'echo "  ✓ SSH hadoop-worker2 OK"' 2>/dev/null || echo "  ✗ SSH hadoop-worker2 FAILED"
else
  echo "SSH test skipped (run on master node)"
fi
echo ""




# Verifier l'installation de Java
echo "=== 4. Java Installation ==="
java -version 2>&1 || echo "WARNING: Java not found"
echo ""



# Vérifier le répertoire Hadoop
echo "=== 5. Hadoop Installation ==="
if [ -d /opt/hadoop ]; then
  echo "  ✓ /opt/hadoop exists"
  /opt/hadoop/bin/hadoop version 2>/dev/null || echo "  WARNING: hadoop command failed"
else
  echo "  ✗ /opt/hadoop missing"
fi
echo ""




# Verifier le fichier workers
echo "=== 6. Workers File ==="
if [ -f /opt/hadoop/etc/hadoop/workers ]; then
  echo "  ✓ workers file exists:"
  cat /opt/hadoop/etc/hadoop/workers | sed 's/^/    /'
else
  echo "  ✗ workers file missing"
fi
echo ""



# Vérifier la configuration YARN
echo "=== 7. YARN Configuration ==="
if [ -f /opt/hadoop/etc/hadoop/yarn-site.xml ]; then
  echo "  ✓ yarn-site.xml exists"
else
  echo "  ✗ yarn-site.xml missing"
fi
echo ""



# Vérifier la configuration MapReduce
echo "=== 8. MapReduce Configuration ==="
if [ -f /opt/hadoop/etc/hadoop/mapred-site.xml ]; then
  echo "  ✓ mapred-site.xml exists"
else
  echo "  ✗ mapred-site.xml missing"
fi
echo ""





# Vérifier Hive (seulement sur le master)
echo "=== 9. Hive Installation ==="
if [ -d /opt/hive ]; then
  echo "  ✓ /opt/hive exists"
  /opt/hive/bin/hive --version 2>/dev/null | head -1 || echo "  WARNING: hive command failed"
else
  echo "  Hive not installed (expected on workers)"
fi
echo ""



# Vérifier le formatage du NameNode
echo "=== 10. NameNode Format Status ==="
if [ -d "/home/hadoop/hadoopdata/namenode/current" ]; then
  echo "  ✓ NameNode is formatted"
else
  echo "  ✗ NameNode NOT formatted (run: hdfs namenode -format)"
fi
echo ""



# Processus Java en cours d'exécution
echo "=== 11. Running Java Processes (jps) ==="
if command -v jps &>/dev/null; then
  sudo -iu hadoop jps 2>/dev/null || echo "  No Java processes running"
else
  /usr/lib/jvm/java-11-openjdk-amd64/bin/jps 2>/dev/null || echo "  jps not available"
fi
echo ""



# Hdfs raport
echo "=== 12. HDFS Report ==="
sudo -iu hadoop bash -c 'source /home/hadoop/.bashrc && hdfs dfsadmin -report 2>/dev/null' || echo "  HDFS not running or command failed"
echo ""


# Yarn node list
echo "=== 13. YARN Nodes ==="
sudo -iu hadoop bash -c 'source /home/hadoop/.bashrc && yarn node -list 2>/dev/null' || echo "  YARN not running or command failed"
echo ""

echo "============================================"
echo "   DIAGNOSTIC COMPLETE"
echo "============================================"
exit 0
