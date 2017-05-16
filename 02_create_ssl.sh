#!/bin/bash
. ./functions.sh

rm ${CERT_FAILED}
touch ${CERT_FAILED}


rm ${SSL_FAILED}
touch ${SSL_FAILED}

#override BACKUP_DIR
BACKUP_DIR="/home/colo/projects/node-mngr-api/devel/etc/.nginx_ssl-"`date +%F_%T`

echo "Backing up Nginx Conf dir: ${NGINX_DIR}"
echo "To: ${BACKUP_DIR}"
cp -a ${NGINX_DIR} ${BACKUP_DIR}

while IFS=':' read -r uri index root; do
  
  process_uri_ssl "${uri}" "${index}" "${root}"
  
done <${TO_ADD_SSL}

echo "Check your new SSL vhosts and enable them manually with a symlink"

exit 0
