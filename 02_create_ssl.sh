#!/bin/bash

gawk="/usr/bin/gawk"

INCLUDE_SSL_CERT="/etc/letsencrypt/live/%s/fullchain.pem"
INCLUDE_SSL_CERT_KEY="/etc/letsencrypt/live/%s/privkey.pem"

SSL_NOT_ADDED="./ssl_not_added"

TO_ADD_SSL="./to_add_ssl"

CERT_FAILED="./cert_failed"
rm ${CERT_FAILED}
touch ${CERT_FAILED}


SSL_FAILED="./ssl_failed"
rm ${SSL_FAILED}
touch ${SSL_FAILED}

ADD_SSL_CMD="./certbot certonly --email certs.infraestructura@e-ducativa.com --no-self-upgrade --webroot -w %s -d %s"

. resty
resty 'http://127.0.0.1:8081/nginx/vhosts/' -Z -v -H "Accept: application/json" -H "Content-Type: application/json" 


NGINX_DIR="/home/colo/projects/node-mngr-api/devel/etc/nginx"
BACKUP_DIR="/home/colo/projects/node-mngr-api/devel/etc/.nginx_ssl-"`date +%F_%T`

echo "Backing up Nginx Conf dir: ${NGINX_DIR}"
echo "To: ${BACKUP_DIR}"
cp -a ${NGINX_DIR} ${BACKUP_DIR}

get_value (){
	local vhost=$1
	local property=$2
	
	#puede ser de typo array si incluyó un comentario
	result=`echo ${vhost} | jq --arg property "${property}" -cr '.[$property]|type'`
	if [ ${result} == 'object' ]; then
		result=`echo ${vhost} | jq --arg property "${property}" -cr '.[$property]|._value'`
	else
		result=`echo ${vhost} | jq --arg property "${property}" -cr '.[$property]'`
	fi
	
	echo ${result}
}

get_json_value (){
	local vhost=$1
	local property=$2
	
	#puede ser de typo array si incluyó un comentario
	result=`echo ${vhost} | jq --arg property "${property}" -cr '.[$property]|type'`
	if [ ${result} == 'object' ]; then
		result=`echo ${vhost} | jq --arg property "${property}" -c '.[$property]|._value'`
	else
		result=`echo ${vhost} | jq --arg property "${property}" -c '.[$property]'`
	fi
	
	echo ${result}
}

create_ssl_vhost (){
	local vhost=$1
	local uri=$2
	#local index=$2
	#echo "index...." ${vhost} ${index}
	
	SSL_CERT=`printf "${INCLUDE_SSL_CERT}" "${uri}"`
	SSL_CERT_KEY=`printf "${INCLUDE_SSL_CERT_KEY}" "${uri}"`
	
	#add ssl include
	listen_address=$( get_value "${vhost}" "listen" | ${gawk} -F ':' '{ print $1 }' ) 
	listen="${listen_address}:443 ssl"
	#echo ${listen_address}
	#exit 0
	
	#echo ${vhost}
	
	ssl=`echo ${vhost} | jq --arg listen "${listen}" '.listen = $listen'`
	cert=`echo ${ssl} | jq --arg ssl_cert ${SSL_CERT} '.ssl_certificate = $ssl_cert'`
	key=`echo ${cert} | jq -rc --arg ssl_cert_key ${SSL_CERT_KEY} '.ssl_certificate_key = $ssl_cert_key'`
	
	#echo ${ssl}
	echo "Saving NEW SSL Vhost ${uri}"
	
	saved_vhost=`echo ${key} | POST /${uri} -q 'dir=ssl'`
	
	if [ $? -eq 0 ]; then
		#echo $saved_vhost | jq -Rrc '.'
		echo 'OK!...adding 80 port redirect...'
		redirect=`echo ${vhost} | jq --arg listen "${listen_address}:80" '.|{ listen: $listen, server_name: .server_name, rewrite: "^   https://$host$request_uri? permanent" }'`
		#echo ${redirect}
		
		echo "Saving Vhost redirect ${uri}"
		saved_redirect=`echo ${redirect} | POST /${uri} -q 'dir=ssl'`
		if [ $? -eq 0 ]; then
			echo 'Done!'
		else
			echo "Probkem saving redirect, server returned:"
			echo ${saved_vhost} | jq -Rrc '.'
		fi
	else
		echo "Probkem saving, server returned:"
		echo ${saved_redirect} | jq -Rrc '.'
	fi
}

create_cert(){
	local uri=$1
	local root=$2
	
	cmd_exec=`printf "${ADD_SSL_CMD}" "${uri}" "${root}"`
	#echo "executing.... "${cmd_exec}
	cmd_status=`${cmd_exec}`
	echo ${cmd_status}
	

}

process_uri (){
	local uri=$1
	local index=$2
	local root=$3
	
	#echo "GET /${uri}/${index}"

	vhost=`GET /${uri}/${index}`
	
	type=`echo ${vhost} | jq -cr '. | type'`
	
	if [ ${type} == 'array' ]; then
		echo "error, shouldn't be an array at all"
		exit -1
	else
		cert=$( create_cert "${uri}" "${root}" )
		#echo ${cert}
		
		if [ ${cert} -ne 0 ]; then
			echo "Failed creating cert for ${uri}/${index} - ${root}"
			echo "${uri}:${index}:${root}" >> ${CERT_FAILED}
		else
			create_ssl_vhost "${vhost}" "${uri}"
		fi
	fi
}

while IFS=':' read -r uri index root; do
  
  process_uri "${uri}" "${index}" "${root}"
  
done <${TO_ADD_SSL}

echo "Check your new SSL vhosts and enable them manually with a symlink"

exit 0
