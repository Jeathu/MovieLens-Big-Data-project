#!/bin/bash
set -e

# Configuration des IPs (basé sur ton cluster actuel)
KEY="$HOME/my_key.pem"
MASTER_IP="4.233.102.34"
WORKER1_IP="4.178.76.144"
WORKER2_IP="4.178.63.58"
ADMIN="hadoopadmin"



echo "=== ETAPE 1 : Réparation de la clé locale (Problème 0777) ==="
# En WSL/Linux, les clés doivent être en lecture seule pour l'utilisateur
chmod 600 "$KEY"
echo "Permissions clé locale corrigées."


echo "=== ETAPE 2 : Récupération de la clé du Master ==="
# On va chercher la clé publique que le master utilise pour se connecter aux autres
PUB_KEY=$(ssh -o StrictHostKeyChecking=no -i "$KEY" $ADMIN@$MASTER_IP "sudo cat /home/hadoop/.ssh/id_rsa.pub")
echo "Clé maître récupérée."


echo "=== ETAPE 3 : Ouverture des accès sur les Workers ==="
# On installe cette clé sur chaque worker
for IP in $WORKER1_IP $WORKER2_IP; do
    echo "Traitement du worker $IP..."
    ssh -o StrictHostKeyChecking=no -i "$KEY" $ADMIN@$IP "
        sudo mkdir -p /home/hadoop/.ssh
        echo '$PUB_KEY' | sudo tee -a /home/hadoop/.ssh/authorized_keys >/dev/null
        sudo chown -R hadoop:hadoop /home/hadoop/.ssh
        sudo chmod 700 /home/hadoop/.ssh
        sudo chmod 600 /home/hadoop/.ssh/authorized_keys
    "
done
echo "Connexion Master -> Workers réparée."


echo "=== ETAPE 4 : Correction configuration Hive et PDSH sur Master ==="
ssh -o StrictHostKeyChecking=no -i "$KEY" $ADMIN@$MASTER_IP "
    # Ajout des variables manquantes si elles n'existent pas déjà
    if ! grep -q 'HIVE_HOME' /home/hadoop/.bashrc_hadoop; then
        echo 'export HIVE_HOME=/opt/hive' | sudo tee -a /home/hadoop/.bashrc_hadoop
        echo 'export PATH=\$PATH:\$HIVE_HOME/bin' | sudo tee -a /home/hadoop/.bashrc_hadoop
        echo 'export PDSH_RCMD_TYPE=ssh' | sudo tee -a /home/hadoop/.bashrc_hadoop
    fi

    # Correction pour PDSH dans l'environnement Hadoop
    if ! grep -q 'PDSH_RCMD_TYPE' /opt/hadoop/etc/hadoop/hadoop-env.sh; then
        echo 'export PDSH_RCMD_TYPE=ssh' | sudo tee -a /opt/hadoop/etc/hadoop/hadoop-env.sh
    fi
"
echo "Environnement Hive et PDSH corrigé."

echo "=== ETAPE 5 : Lancement Final ==="
echo "Exécution de complete_setup.sh sur le master..."
ssh -o StrictHostKeyChecking=no -i "$KEY" $ADMIN@$MASTER_IP "sudo bash /home/hadoopadmin/complete_setup.sh"

echo ""
echo "CLUSTER RÉPARÉ ET DÉMARRÉ AVEC SUCCÈS !"
