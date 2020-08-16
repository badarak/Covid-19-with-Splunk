# covid-19-with-splunk

Ce projet a pour but d'analyser la mortalité du Covid-19 en France. Nous répondrons aux questions:


– Top 20 des départements les plus touchés par la mortalité du Covid-19 ?
– Répartition de la mortalité du Covid-19 en Hôpital par Genre
– Le cumul des décès Covid-19 en hôpital à une date donnée

Pour ce faire, nous utiliserons Splunk avec un déploiement distribué.

1- Pré-requis

- [Docker](https://www.docker.com/)
- [Splunk](https://www.splunk.com/)
- [Données hospitalières](https://www.data.gouv.fr/fr/datasets/donnees-hospitalieres-relatives-a-lepidemie-de-covid-19/)

2.  Topologie du dépoiement Splunk

- un Indexer Cluster constitué d'un master node (spl-midx01) et de 2 peers nodes (spl-idx01 et spl-idx02)
- un Universal Forwarder (u-fwd01)
- un Search Head Cluster composé de 2 search headers (spl-sh01 et spl-sh02) et d'un deployer (spl-deployer01)


3. Install & configuration de l'Index Cluster

docker-compose -f indexer-cluster.yml up -d

3-1. Configuration du noeud master

- se connecter sur le noeud master :
  docker exec -it -u splunk spl-midx01 bash

- ajouter le stanza ci-dessous dans le fichier server.conf - /opt/splunk/etc/system/local
[clustering]
mode = master
pass4SymmKey = test@123
replication_factor = 2

- Puis redémarrer l'instance
  /opt/splunk/bin/splunk restart

3-2. Configuration des noeuds esclaves

- se connecte sur le 1er noeud esclave - spl-idx01 :
  docker exec -it -u splunk spl-idx01 bash

- ajouter les stanza ci-dessous dans le fichier server.conf - /opt/splunk/etc/system/local :

[replication_port://8080]

[clustering]
master_uri = https://172.17.0.2:8089
mode = slave
pass4SymmKey = test@123

- Puis redémarrer le peer node spl-idx01 :
/opt/splunk/bin/splunk restart

- Faire de même pour le 2ème noeud spl-idx02

3-3.  Ajout d'un index et d'un "source type" au niveau du master

- se connecter sur le noeud master :
  docker exec -it -u splunk spl-midx01 bash


- créer l'index dans le fichier indexes.conf - /opt/splunk/etc/master-apps/_cluster/local :

  [idx_covid_19]
  homePath   = $SPLUNK_DB/idx_covid_19/db
  coldPath   = $SPLUNK_DB/idx_covid_19/colddb
  thawedPath = $SPLUNK_DB/idx_covid_19/thaweddb
  repFactor = auto

- créer un Source Type dans le fichier props.conf - /opt/splunk/etc/master-apps/_cluster/local :

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

- pusher ces configurations depuis le master vers les peers nodes :

   /opt/splunk/bin/splunk apply cluster-bundle

   on vérifie le status :

   /opt/splunk/bin/splunk show cluster-bundle-status

3.4.  Spécifier le mode de découverte de l'indexer cluster par les Forwarders

   - se connecter sur le noeud master :
     docker exec -it -u splunk spl-midx01 bash

   - ajouter le stanza ci-dessous dans le fichier server.conf - /opt/splunk/etc/system/local :

   [indexer_discovery]
   pass4SymmKey = test@123

   - Puis redémarrer le master :
   /opt/splunk/bin/splunk restart
