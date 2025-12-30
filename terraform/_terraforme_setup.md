# __*Déploiement d'un cluster Hadoop distribué sur Azure avec Terraform*__

Ce projet automatise le déploiement d'un cluster distribué **Hadoop 3.3.6** et **Hive 3.1.3** sur Microsoft Azure avec Terraform. Il provisionne l'infrastructure et bootstrape automatiquement les nœuds avec les configurations nécessaires.



![Cluster Hadoop](../images/hadoop_acc.png)


<br>

## - *Aperçu*

Le cluster se compose de 3 machines virtuelles exécutant **Ubuntu 20.04 LTS** :

|     Rôle     |    Nom d'hôte    | IP privée  | Composants                                |
| :----------: | :--------------: | :--------: | :---------------------------------------- |
|  **Master**  | `hadoop-master`  | `10.0.1.4` | NameNode, ResourceManager, Metastore Hive |
| **Worker 1** | `hadoop-worker1` | `10.0.1.5` | DataNode, NodeManager                     |
| **Worker 2** | `hadoop-worker2` | `10.0.1.6` | DataNode, NodeManager                     |

**Stack technologique :**

- **Infrastructure :** Terraform et Azure RM
- **Java Runtime :** OpenJDK 8 (requis pour la compatibilité Hive)
- **Hadoop :** Apache Hadoop 3.3.6
- **Entrepôt de données :** Apache Hive 3.1.3 (Derby Metastore)

---
<br>

## - *Guide rapide*

### 1. Prérequis

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.0
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (`az login`)
- Terminal de type Unix (Linux, macOS ou **WSL** sous Windows)

### 2. Étapes de déploiement

**Étape 1 : Initialiser & provisionner**  
Place-toi dans le dossier `terraform` puis exécute :

```bash
terraform init
terraform apply -auto-approve
```

_Terraform affichera les IP publiques du master et des workers à la fin._

**Étape 2 : Configuration post-provisionnement**  
À cause des interactions entre les permissions de fichiers Windows (si utilisation de WSL) et les exigences SSH, un script d'aide est fourni pour finaliser la configuration (propagation des clés, correction des permissions, démarrage des services) :

```bash
Remplacez les lignes en haut par le ip sorties par Terraform dans le fichier fix_cluster.sh :
MASTER_IP="4.233.69.7"
WORKER1_IP="4.233.86.121"
WORKER2_IP="4.212.94.196"

# Copier la clé vers le dossier "racine" Linux
cp hadoop_ssh_key.pem ~/my_key.pem

# Changer les droits
chmod 600 ~/my_key.pem

# 3. Mettre à jour mon script pour utiliser cette clé
sed -i 's|KEY="./hadoop_ssh_key.pem"|KEY="$HOME/my_key.pem"|' fix_cluster.sh

# Relancer le script
bash fix_cluster.sh
```



> **Attendre le message de succès :** `CLUSTER RÉPARÉ ET DÉMARRÉ AVEC SUCCÈS !`

---


<br>

## - *Accès au cluster*

Pour respecter les permissions SSH, utilisez la clé créée par le script fix dans votre répertoire personnel :

```bash
cd ~/.ssh
   ls -la
   rm -f ~/.ssh/hadoop_ssh_key.pem*

chmod 600 hadoop_ssh_key.pem
mkdir -p ~/.ssh
cp hadoop_ssh_key.pem ~/.ssh/
chmod 600 ~/.ssh/hadoop_ssh_key.pem

# Vérifiez que la clé est bien en place :
ls -la ~/.ssh/hadoop_ssh_key.pem
```


```bash
ssh -i ~/hadoop_ssh_key.pem hadoopadmin@<MASTER_PUBLIC_IP>
```

_(Remplacer `<MASTER_PUBLIC_IP>` par l'IP publique affichée à l'étape 1)_

---

<br>

## - *Vérifications et tests*

Connecté au master, vérifiez l'état des services.

### 1. Vérifier HDFS

S'assurer que les DataNodes sont actifs :

```bash
sudo -u hadoop /opt/hadoop/bin/hdfs dfsadmin -report
```

_Sortie attendue :_ `Live datanodes (2)`

### 2. Lancer un job MapReduce (YARN)

Soumettez un job pour vérifier le traitement :

```bash
sudo -u hadoop /opt/hadoop/bin/yarn jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar pi 2 100
```

_Sortie attendue :_ `Estimated value of Pi is 3.14...`

``` bash
# Créer le dossier /tmp avec les droits complets pour tous les utilisateurs
sudo -u hadoop /opt/hadoop/bin/hdfs dfs -mkdir -p /tmp
sudo -u hadoop /opt/hadoop/bin/hdfs dfs -chmod -R 777 /tmp

# Créer le dossier pour Hive
sudo -u hadoop /opt/hadoop/bin/hdfs dfs -mkdir -p /user/hive/warehouse
sudo -u hadoop /opt/hadoop/bin/hdfs dfs -chmod -R 777 /user/hive/warehouse
```

### 3. Tester Hive

Accéder au CLI Hive et exécuter des requêtes SQL :

```bash

# Changer d'identité pour devenir 'hadoop'
sudo su - hadoop

# Supprimer l'ancienne si existente base de données Derby
rm -rf metastore_db

# Initialiser le schéma
schematool -dbType derby -initSchema

# Lancer Hive
hive
```

À l'intérieur du prompt Hive :

```sql
SHOW DATABASES;

CREATE TABLE test (id INT, name STRING);

SHOW TABLES;

DROP TABLE test;

QUIT;
```

Test HDFS :
``` bash
hdfs dfs -ls /
hdfs dfs -mkdir /mon_test
hdfs dfs -put .bashrc /mon_test/mon_fichier.txt
hdfs dfs -cat /mon_test/mon_fichier.txt
hdfs fsck /mon_test/mon_fichier.txt -files -blocks -locations
hdfs dfs -rm -r /mon_test
```

---


<br>

## - *Détails de la configuration (en coulisses)*

Les scripts automatisés prennent en charge plusieurs configurations critiques :

- **Java 8** : imposé (évite des erreurs ClassCastException avec Hive)
- **Confiance SSH** : configuration d'un SSH sans mot de passe du Master vers les Workers
- **Variables d'environnement** : `HADOOP_HOME`, `HIVE_HOME`, `JAVA_HOME`, et `PDSH_RCMD_TYPE=ssh` ajoutées automatiquement dans `.bashrc`
- **Permissions HDFS** : création de `/tmp` et `/user/hive/warehouse` avec permissions `777` pour accès général

---

<br>

## - *Nettoyage / destruction*

Pour détruire toutes les ressources Azure et arrêter la facturation :

```bash
terraform destroy -auto-approve
```
