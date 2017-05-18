#!/bin/bash
. ./functions.sh

rm ${CERT_FAILED}
touch ${CERT_FAILED}


rm ${SSL_FAILED}
touch ${SSL_FAILED}

echo "Backing up Nginx Conf dir: ${NGINX_DIR}"
echo "To: ${BACKUP_DIR_SSL}"
cp -a ${NGINX_DIR} ${BACKUP_DIR_SSL}

while IFS=':' read -r uri index root; do
  
  process_uri_ssl "${uri}" "${index}" "${root}"
  
done <${TO_ADD_SSL}

echo "Check your new SSL vhosts and enable them manually with a symlink"

exit 0
