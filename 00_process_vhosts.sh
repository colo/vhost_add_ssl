#!/bin/bash
. ./functions.sh


rm ${SSL_NOT_ADDED}
touch ${SSL_NOT_ADDED}

rm ${TO_ADD_SSL}
touch ${TO_ADD_SSL}

VHOSTS=`GET /| jq -c -r '.[]'`

for uri in ${VHOSTS[@]}; do
	
	process_vhost "${uri}"
	
done

echo "Now run 01_add_ssl_conf.sh"

exit 0

