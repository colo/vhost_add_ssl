#!/bin/bash
. ./functions.sh

#echo "Backing up Nginx Conf dir: ${NGINX_DIR}"
#echo "To: ${BACKUP_DIR}"
#cp -a ${NGINX_DIR} ${BACKUP_DIR}

rm "${TO_ADD_SSL}_really"
rm "${TO_ADD_SSL}_not_to_do"
rm "./to_match_missing"

while IFS=':' read -r uri index root; do
  
    #echo "${uri}" "${index}" "${root}"
    found=0
    while IFS= read -r url; do
  
        #echo "${url}"
        if [ ${uri} == ${url} ]; then
            found=1
            echo "${uri}:${index}:${root}">> "${TO_ADD_SSL}_really"
        fi

    done <"to_match"

    if [ ${found} -eq 0 ]; then
        echo "${uri}:${index}:${root}">> "${TO_ADD_SSL}_not_to_do"
    fi
  
done <${TO_ADD_SSL}

while IFS= read -r url; do
    found=0

    while IFS=':' read -r uri index root; do

        if [ ${uri} == ${url} ]; then
            found=1
        fi

    done <${TO_ADD_SSL}
    
    if [ ${found} -eq 0 ]; then
        echo ${url} >> "./to_match_missing"
    fi


done <"to_match"

#echo "Now check nginx conf with: "
#echo "nginx -t -c ${NGINX_DIR}/nginx.conf; service nginx reload"
#echo "and the run 02_create_ssl.sh"

exit 0
