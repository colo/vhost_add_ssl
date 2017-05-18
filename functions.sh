#!/bin/bash

gawk="/usr/bin/gawk"
#production - debian
#gawk="/usr/bin/awk"

. resty
resty 'http://127.0.0.1:8081/nginx/vhosts/' -Z -v -H "Accept: application/json" -H "Content-Type: application/json" 
#production
#resty 'http://127.0.0.1:8081/nginx/vhosts/enabled/' -Z -v -H "Accept: application/json" -H "Content-Type: application/json" 

SSL_NOT_ADDED="./ssl_not_added"
TO_ADD_SSL="./to_add_ssl"
CERT_FAILED="./cert_failed"

INCLUDE_SSL_FILE="/etc/nginx/conf.d/ssl.conf"

NGINX_DIR="/home/colo/projects/node-mngr-api/devel/etc/nginx"
BACKUP_DIR="/home/colo/projects/node-mngr-api/devel/etc/.nginx-"`date +%F_%T`
BACKUP_DIR_SSL="/home/colo/projects/node-mngr-api/devel/etc/.nginx_ssl-"`date +%F_%T`

#production
#NGINX_DIR="/etc/nginx"
#BACKUP_DIR="/var/backups/.nginx-"`date +%F_%T`
#BACKUP_DIR_SSL="/var/backups/.nginx_ssl-"`date +%F_%T`


INCLUDE_SSL_CERT="/etc/letsencrypt/live/%s/fullchain.pem"
INCLUDE_SSL_CERT_KEY="/etc/letsencrypt/live/%s/privkey.pem"

ADD_SSL_CMD="./certbot certonly --email certs.infraestructura@e-ducativa.com --no-self-upgrade --webroot -w %s -d %s"



get_value (){
	local vhost=$1
	local property=$2
	
	#puede ser de typo array si incluyó un comentario
	result=`echo ${vhost} | jq --arg property "${property}" -c -r '.[$property]|type'`
	if [ ${result} == 'object' ]; then
		result=`echo ${vhost} | jq --arg property "${property}" -c -r '.[$property]|._value'`
	else
		result=`echo ${vhost} | jq --arg property "${property}" -c -r '.[$property]'`
	fi
	
	echo ${result}
}

get_json_value (){
	local vhost=$1
	local property=$2
	
	#puede ser de typo array si incluyó un comentario
	result=`echo ${vhost} | jq --arg property "${property}" -c -r '.[$property]|type'`
	if [ ${result} == 'object' ]; then
		result=`echo ${vhost} | jq --arg property "${property}" -c '.[$property]|._value'`
	else
		result=`echo ${vhost} | jq --arg property "${property}" -c '.[$property]'`
	fi
	
	echo ${result}
}

is_ssl() {
	local vhost=$1
	ssl_certificate=$( get_value "${vhost}" "ssl_certificate" )
	
	if [ ${ssl_certificate} = "null" ]; then
		echo 0
	else
		ssl_certificate_key=$( get_value "${vhost}" "ssl_certificate_key" )
		
		if [ ${ssl_certificate_key} = "null" ]; then
			echo 0
		else
			echo 1
			
		fi
		
	fi
	
	
}

process_vhost (){
	local uri=$1
	
	vhost=`GET /${uri}`
	
	type=`echo ${vhost} | jq -cr '. | type'`
	
	
	
	if [ ${type} == 'array' ]; then
		#no se procesar el array con jc, así q hago nuevamente el GET pero con indice
		length=`echo ${vhost} | jq '.|length'`
		#echo ${length}
		index=0
		while [ ${index} -lt ${length} ]; do
			#echo The counter is ${index}
			#echo "I ${uri}"
			vhost=`GET /${uri}/${index}`
			
			server_name=$( get_value "${vhost}" "server_name" )
			root=$( get_value "${vhost}" "root" )
			is_ssl=$( is_ssl "${vhost}" )
			#echo "${server_name}:${root}:${is_ssl}"
			
			##echo ${is_ssl}
			
			#si no tiene ssl & tiene un root, podemos hacer el certificado
			if [ ${is_ssl} -lt 1 -a ${root} != "null" ]; then
				echo "${server_name}/${index} needs ssl"
				echo "${server_name}:${index}:${root}" >> ${TO_ADD_SSL}
			else
				echo "${server_name}:${index}:${root}" >> ${SSL_NOT_ADDED}
			
			fi
			
			let index=index+1
		done
		
	else
		server_name=$( get_json_value "${vhost}" "server_name" )
		
		#echo ${server_name} | jq -Rcr '. | type'
		
		type=`echo ${server_name} | jq -cr '. | type'`
		
		#si tiene varios server names en un mismo vhost, utilizamos la uri...los demás server_names no se pierden,
		#ya que serán llamados nuevamente porque la lista inicial incluye todo y cada uno de los server_name en 
		# todos los vhosts
		#
		# de hecho es la forma correcta de procesarlos, ya que es necesario procesar cada uno de los servers_names
		# y generarles vhosts individuales, porque cada uno debe tener sus archivos de CERT y KEY
		if [ ${type} == 'array' ]; then
			echo "ARRAY"
			server_name=${uri}
		else
			server_name=$( get_value "${vhost}" "server_name" )
		fi
		
		
		
		root=$( get_value "${vhost}" "root" )
		is_ssl=$( is_ssl "${vhost}" )
		
		#echo ${is_ssl}
		
		#si no tiene ssl & tiene un root, podemos hacer el certificado
		if [ ${is_ssl} -lt 1 -a ${root} != "null" ]; then
			echo "${server_name}/0 needs ssl"
			echo "${server_name}:0:${root}" >> ${TO_ADD_SSL}
		else
			echo "${server_name}:0:${root}" >> ${SSL_NOT_ADDED}
		fi
		
	fi
}

include_ssl_conf (){
	local vhost=$1
	local uri=$2
	local index=$3
	
	includes=$( get_json_value "${vhost}" "include" )
	type=`echo ${includes} | jq -c -r '.|type'`
	
	if [ ${type} == 'array' ]; then
		ssl=`echo ${includes} | jq --arg ssl_file "${INCLUDE_SSL_FILE}" -c -r '.|map(contains($ssl_file))' | egrep -c 'true'`
	elif [ ${type} == 'string' ]; then
		#echo "TYPE STRING: "${type}
		ssl=`echo ${includes} | jq --arg ssl_file "${INCLUDE_SSL_FILE}" -c -r '.|contains($ssl_file)' | egrep -c 'true'`
	else
		#echo "TYPE NULL: "${type}
		ssl=0
	fi
			
	if [ ${ssl} -eq 0 ]; then
		#ssl_conf=`echo ${vhost} | jq -r -c --arg ssl_file ${INCLUDE_SSL_FILE} '.include |= . + [$ssl_file]'`
		ssl_conf=`echo ${vhost} | jq --arg ssl_file ${INCLUDE_SSL_FILE} '.include |= . + [$ssl_file]'`
		ssl_conf=`echo ${ssl_conf} | jq -r -c --arg ssl_file ${INCLUDE_SSL_FILE} '. |{ include: .include }'`
		#echo ${uri}
		#echo ${vhost}
		#echo ${ssl_conf}
		echo "Saving ${uri}/${index}"
		saved_vhost=`PUT /${uri}/${index} ${ssl_conf}`
		if [ $? -eq 0 ]; then
			#echo $saved_vhost | jq -R -r -c '.'
			echo 'OK!'
		else
			echo "Probkem saving, server returned:"
			echo $saved_vhost | jq -R -r -c '.'
		fi
	fi
	
	
}

process_uri (){
	local uri=$1
	local index=$2
	local root=$3
	
	#echo "GET /${uri}/${index}"

	vhost=`GET /${uri}/${index}`
	
	type=`echo ${vhost} | jq -c -r '. | type'`
	
	if [ ${type} == 'array' ]; then
		echo "error, shouldn't be an array at all"
		exit -1
	else
		include_ssl_conf "${vhost}" "${uri}" "${index}"
	fi
}

process_uri_ssl (){
	local uri=$1
	local index=$2
	local root=$3
	
	#echo "GET /${uri}/${index}"

	vhost=`GET /${uri}/${index}`
	
	type=`echo ${vhost} | jq -c -r '. | type'`
	
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
	key=`echo ${cert} | jq -r -c --arg ssl_cert_key ${SSL_CERT_KEY} '.ssl_certificate_key = $ssl_cert_key'`
	
	#echo ${ssl}
	echo "Saving NEW SSL Vhost ${uri}"
	
	saved_vhost=`echo ${key} | POST /${uri} -q 'dir=ssl'`
	
	if [ $? -eq 0 ]; then
		#echo $saved_vhost | jq -R -r -c '.'
		echo 'OK!...adding 80 port redirect...'
		redirect=`echo ${vhost} | jq --arg listen "${listen_address}:80" '.|{ listen: $listen, server_name: .server_name, rewrite: "^   https://$host$request_uri? permanent" }'`
		#echo ${redirect}
		
		echo "Saving Vhost redirect ${uri}"
		saved_redirect=`echo ${redirect} | POST /${uri} -q 'dir=ssl'`
		if [ $? -eq 0 ]; then
			echo 'Done!'
		else
			echo "Probkem saving redirect, server returned:"
			echo ${saved_vhost} | jq -R -r -c '.'
		fi
	else
		echo "Probkem saving, server returned:"
		echo ${saved_redirect} | jq -R -r -c '.'
	fi
}

create_cert(){
	local uri=$1
	local root=$2
	
	cmd_exec=`printf "${ADD_SSL_CMD}" "${root}" "${uri}"`
	#echo "executing.... "${cmd_exec}
	cmd_status=`${cmd_exec}`
	echo ${cmd_status}
	

}
