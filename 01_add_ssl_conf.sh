#!/bin/bash

INCLUDE_SSL_FILE="/etc/nginx/conf.d/ssl.conf"

SSL_NOT_ADDED="./ssl_not_added"
TO_ADD_SSL="./to_add_ssl"

. resty
resty 'http://127.0.0.1:8081/nginx/vhosts/' -Z -v -H "Accept: application/json" -H "Content-Type: application/json" 

NGINX_DIR="/home/colo/projects/node-mngr-api/devel/etc/nginx"
BACKUP_DIR="/home/colo/projects/node-mngr-api/devel/etc/.nginx-"`date +%F_%T`

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

include_ssl_conf (){
	local vhost=$1
	local uri=$2
	local index=$3
	
	includes=$( get_json_value "${vhost}" "include" )
	type=`echo ${includes} | jq -cr '.|type'`
	
	if [ ${type} == 'array' ]; then
		ssl=`echo ${includes} | jq --arg ssl_file "${INCLUDE_SSL_FILE}" -cr '.|map(contains($ssl_file))' | egrep -c 'true'`
	elif [ ${type} == 'string' ]; then
		#echo "TYPE STRING: "${type}
		ssl=`echo ${includes} | jq --arg ssl_file "${INCLUDE_SSL_FILE}" -cr '.|contains($ssl_file)' | egrep -c 'true'`
	else
		#echo "TYPE NULL: "${type}
		ssl=0
	fi
			
	if [ ${ssl} -eq 0 ]; then
		#ssl_conf=`echo ${vhost} | jq -rc --arg ssl_file ${INCLUDE_SSL_FILE} '.include |= . + [$ssl_file]'`
		ssl_conf=`echo ${vhost} | jq --arg ssl_file ${INCLUDE_SSL_FILE} '.include |= . + [$ssl_file]'`
		ssl_conf=`echo ${ssl_conf} | jq -rc --arg ssl_file ${INCLUDE_SSL_FILE} '. |{ include: .include }'`
		#echo ${uri}
		#echo ${vhost}
		#echo ${ssl_conf}
		echo "Saving ${uri}/${index}"
		saved_vhost=`PUT /${uri}/${index} ${ssl_conf}`
		if [ $? -eq 0 ]; then
			#echo $saved_vhost | jq -Rrc '.'
			echo 'OK!'
		else
			echo "Probkem saving, server returned:"
			echo $saved_vhost | jq -Rrc '.'
		fi
	fi
	
	
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
		include_ssl_conf "${vhost}" "${uri}" "${index}"
	fi
}

while IFS=':' read -r uri index root; do
  
  process_uri "${uri}" "${index}" "${root}"
  
done <${TO_ADD_SSL}


echo "Now check nginx conf with: "
echo "nginx -t -c ${NGINX_DIR}/nginx.conf; service nginx reload"
echo "and the run 02_create_ssl.sh"

exit 0

