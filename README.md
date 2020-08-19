# covid-19-with-splunk

Ce projet a pour but d'analyser la mortalité en hôpital du Covid-19 en France. Nous répondrons aux questions suivantes:

* Top 20 des départements les plus touchés par la mortalité du Covid-19 ?
* Répartition de la mortalité du Covid-19 par Genre
* Le cumul des décès Covid-19 en hôpital à une date donnée

Pour ce faire, nous utiliserons Splunk avec un déploiement distribué.

1. Pré-requis

- [Docker](https://www.docker.com/)
- [Splunk](https://www.splunk.com/)
- [Données hospitalières](https://www.data.gouv.fr/fr/datasets/donnees-hospitalieres-relatives-a-lepidemie-de-covid-19/)

2.  Topologie du dépoiement Splunk

* un Indexer Cluster constitué d'un master node (`spl-midx01`) et de 2 peers nodes (`spl-idx01` et `spl-idx02`)
* un Universal Forwarder (`u-fwd01`)
* un Search Head Cluster composé de 2 search headers (`spl-sh01` et `spl-sh02`) et d'un deployer (`spl-deployer01`)


**3. Install & configuration de l'Index Cluster**

* lancer la commande ci-dessous depuis le répertoire docker du projet :
`docker-compose -p covid-19 -f indexer-cluster.yml up -d`

**Configuration du noeud master**

* se connecter sur le noeud master :
  docker exec -it -u splunk spl-midx01 bash

* ajouter le stanza ci-dessous dans le fichier server.conf - /opt/splunk/etc/system/local
```
[clustering]
mode = master
pass4SymmKey = test@123
replication_factor = 2
```
* Puis redémarrer l'instance
  `/opt/splunk/bin/splunk restart`

**Configuration des noeuds esclaves**

* se connecter sur le 1er noeud esclave - spl-idx01 :
  docker exec -it -u splunk spl-idx01 bash

* ajouter les stanza ci-dessous dans le fichier server.conf - /opt/splunk/etc/system/local :
```
[replication_port://8080]

[clustering]
master_uri = https://172.28.0.6:8089
mode = slave
pass4SymmKey = test@123
```
* Puis redémarrer le peer node `spl-idx01` :
`/opt/splunk/bin/splunk restart`

* Faire de même pour le 2ème noeud spl-idx02

 **Ajout d'un index et d'un "source type" au niveau du master**

* se connecter sur le noeud master :
  `docker exec -it -u splunk spl-midx01 bash`


* créer l'index dans le fichier `indexes.conf - /opt/splunk/etc/master-apps/_cluster/local` :
```
  [idx_covid_19]
  homePath   = $SPLUNK_DB/idx_covid_19/db
  coldPath   = $SPLUNK_DB/idx_covid_19/colddb
  thawedPath = $SPLUNK_DB/idx_covid_19/thaweddb
  repFactor = auto
```
* créer un Source Type dans le fichier props.conf - /opt/splunk/etc/master-apps/_cluster/local :

```
[covid_19]
INDEXED_EXTRACTIONS = csv
KV_MODE = none
LINE_BREAKER = ([\r\n]+)
NO_BINARY_CHECK = true
SHOULD_LINEMERGE = false
TIMESTAMP_FIELDS = jour
TIME_FORMAT = %Y-%m-%d
category = Custom
disabled = false
pulldown_type = 1
```
* pusher ces configurations depuis le master vers les peers nodes :

   `/opt/splunk/bin/splunk apply cluster-bundle`

   on vérifie le status :

   `/opt/splunk/bin/splunk show cluster-bundle-status`

**Spécifier le mode de découverte de l'indexer cluster par les Forwarders**

   * se connecter sur le noeud master :
     `docker exec -it -u splunk spl-midx01 bash`

   * ajouter le stanza ci-dessous dans le fichier `server.conf - /opt/splunk/etc/system/local` :
   ```
   [indexer_discovery]
   pass4SymmKey = test@123
   ```
   
   * Puis redémarrer le master :
   `/opt/splunk/bin/splunk restart`

4. Install & configuration de l'Universal Forwarder

4.1. Install de l'Universal Forwarder

- install du container centos :
docker run --name u-fwd01 --network covid-19_splunk-network -h u-fwd01 -dt centos:6

- puis install de l'agent collecteur - le Forwarder :
docker exec -it u-fwd01 bash

yum -y install wget

wget -O splunkforwarder-7.2.0-8c86330ac18-linux-2.6-x86_64.rpm 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=7.2.0&product=universalforwarder&filename=splunkforwarder-7.2.0-8c86330ac18-linux-2.6-x86_64.rpm&wget=true'

yum install splunkforwarder-7.2.0-8c86330ac18-linux-2.6-x86_64.rpm

- accepter la licence et en créant en même temps un user admin (nom du user est admin)

/opt/splunkforwarder/bin/splunk status

- Puis relancer

/opt/splunkforwarder/bin/splunk restart

4.2- Configuration de l'Universal Forwarder pour dialoguer avec l'Indexer Cluster

- se connecter sur le container :
docker exec -it u-fwd01 bash

- créer le fichier outputs.conf - /opt/splunkforwarder/etc/system/local
touch /opt/splunkforwarder/etc/system/local/outputs.conf

- ajouter le stanza ci-dessous dans le fichier outputs.conf - /opt/splunkforwarder/etc/system/local

[indexer_discovery:master]
pass4SymmKey = test@123
master_uri = https://172.28.0.6:8089

[tcpout:group1]
indexerDiscovery = master

- ajouter la Source Type covid_19 dans le fichier props.conf - /opt/splunkforwarder/etc/system/local:

[covid_19]
INDEXED_EXTRACTIONS = csv
KV_MODE = none
LINE_BREAKER = ([\r\n]+)
NO_BINARY_CHECK = true
SHOULD_LINEMERGE = false
TIMESTAMP_FIELDS = jour
TIME_FORMAT = %Y-%m-%d
category = Custom
disabled = false
pulldown_type = 1

- spécifier le répertoire dans lequel les données hospitalières arriverons :

mkdir -p /data/covid_19

puis le surveiller en ajoutant le stanza ci-dessous dans le fichier inputs.conf - /opt/splunkforwarder/etc/system/local:

[monitor:///data/covid_19]
disabled = 0
host = u-fwd01
index = idx_covid_19
sourcetype = covid_19

- relancer l'instance
/opt/splunkforwarder/bin/splunk restart

5. Install & configuration du Search Head cluster

- lancer la commande ci-dessous depuis le répertoire docker du projet :
docker-compose -p covid-19 -f search-head-cluster.yml up -d

5.1- Configuration du deployer

- se connecter sur le deployer spl-deployer01 - IP 172.28.0.4 :
docker exec -it -u splunk spl-deployer01 bash

- ajouter le stanza ci-dessous dans le server.conf - /opt/splunk/etc/system/local :

[shclustering]
pass4SymmKey = test@123
shcluster_label = badarak_shcluster

- Puis relancer l'instance
/opt/splunk/bin/splunk restart

5.2- Configuration des noeuds Search Head

- Pour le 1er search head : spl-sh01 - IP 172.28.0.3

docker exec -it -u splunk spl-sh01 bash

/opt/splunk/bin/splunk init shcluster-config \
                       -auth admin:test@123 \
                       -mgmt_uri https://172.28.0.3:8089 \
                       -replication_port 8080 \
                       -replication_factor 1 \
                       -shcluster_label badarak_shcluster \
                       -conf_deploy_fetch_url https://172.28.0.4 \
                       -secret test@123

Puis relancer l'instance
 /opt/splunk/bin/splunk restart

- Faire de même pour le 2ème search head : spl-sh02 - IP 172.28.0.2


5.3- Choix du Search Head Cluster Captain

- se connecter sur l'un des search head par ex spl-sh02:

docker exec -it -u splunk spl-sh02 bash

- Puis lancer la commande bootstrap shcluster-captain :

/opt/splunk/bin/splunk bootstrap shcluster-captain \
                       -auth admin:test@123 \
                       -servers_list "https://172.28.0.3:8089","https://172.28.0.2:8089"

5.4- Intéger le Search Head Cluster à l'Indexer Cluster

- se connecter au 1er search head - spl-sh01 :
docker exec -it -u splunk spl-sh01 bash

- lancer la commande splunk edit cluster-config :
/opt/splunk/bin/splunk edit cluster-config \
                       -auth admin:test@123 \
                       -mode searchhead \
                       -master_uri https://172.28.0.6:8089 \
                       -secret test@123

- Puis relancer l'instance
     /opt/splunk/bin/splunk restart

Faire de même pour la 2ème SH

6. Analyse de la mortalite en hôspital du Covid-19

6-1 Récupération des données

- lancer le script de chargement depuis le répertoire scripts:

 ./dataLoader.sh

6.2- Requêtes SPL associées

# Le cumul des décès Covid-19 en hôpital à une date donnée
index=idx_covid_19 sexe = 0
| stats sum(dc)

# Top 20 des départements les plus touchés par la mortalité du Covid-19 ?
index=idx_covid_19 sexe = 0
15| lookup dep_lookup.csv code_departement as dep
| sort - dc
| table dep, nom_departement, dc,
| rename dep as "Code", nom_departement as "Département", dc as "Décès" | head 20

# Répartition de la mortalité en hôpital du Covid-19 par Genre
index=idx_covid_19 sexe != 0
| lookup akblookup.csv sex_id as sexe
| stats sum(dc) as "Total Décès" by sex_label
| rename sex_label as "Genre"

6.2 Dashboad associé
