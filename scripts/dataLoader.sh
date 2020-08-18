#!/bin/sh

DOWNLOAD_DATE_YYYYMMDD=$(date -v -1d '+%Y%m%d')
FILE_NAME_PREFIX='donnees-hospitalieres-covid19-'
DOWNLOAD_DATE_YYYY_MM_DD=$(date -v -1d '+%Y-%m-%d')
FILE_NAME_SUFFIX='-19h00.csv'
DOWNLOAD_URL="https://www.data.gouv.fr/fr/datasets/r/63352e38-d353-4b54-bfd1-f1b3ee1cabd7"

DEST_DIR='/data/covid_19/'
FILE_COVID_19=$FILE_NAME_PREFIX$DOWNLOAD_DATE_YYYY_MM_DD$FILE_NAME_SUFFIX


echo ">>> Url de telechargement : $DOWNLOAD_URL"
echo
echo

curl -L $DOWNLOAD_URL --output "$FILE_COVID_19"

echo ">>> Téléchargement terminé"
echo
echo ">>> déplacement du fichier vers le Forward : $DEST_DIR"

docker cp $FILE_COVID_19 u-fwd01:$DEST_DIR
