#!/bin/bash
. ./functions.sh

echo "Backing up Nginx Conf dir: ${NGINX_DIR}"
echo "To: ${BACKUP_DIR}"
cp -a ${NGINX_DIR} ${BACKUP_DIR}

while IFS=':' read -r uri index root; do
  
  process_uri "${uri}" "${index}" "${root}"
  
done <${TO_ADD_SSL}


echo "Now check nginx conf with: "
echo "nginx -t -c ${NGINX_DIR}/nginx.conf; service nginx reload"
echo "and the run 02_create_ssl.sh"

exit 0

