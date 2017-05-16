#!/bin/bash

INCLUDE_SSL_FILE="/etc/nginx/conf.d/ssl.conf"

SSL_NOT_ADDED="./ssl_not_added"
rm ${SSL_NOT_ADDED}
touch ${SSL_NOT_ADDED}
#echo "SERVER_NAME:ROOT:SSL" > ${SSL_NOT_ADDED}

TO_ADD_SSL="./to_add_ssl"
rm ${TO_ADD_SSL}
touch ${TO_ADD_SSL}
#echo "SERVER_NAME:ROOT:SSL" > ${TO_ADD_SSL}


. resty
resty 'http://127.0.0.1:8081/nginx/vhosts/' -Z -v -H "Accept: application/json" -H "Content-Type: application/json" 
VHOSTS=`GET /| jq -cr '.[]'`

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
			#includes=$( get_json_value "${vhost}" "include" )
			#type=`echo ${includes} | jq -cr '.|type'`
			
			##if [ ${type} == 'array' ]; then
				###ssl=`echo ${includes} | jq -cr '.|if map(contains("/etc/nginx/conf.d/ssl.conf") == true then halt end)'`
				##ssl=`echo ${vhost} | jq --arg ssl_file ${INCLUDE_SSL_FILE} '.include|map(contains($ssl_file))' | egrep -c 'true'`
				###ssl=`echo ${includes} | jq --arg ssl_file ${INCLUDE_SSL_FILE} -cr '.|map(contains($ssl_file))' | egrep -c 'true'`
				
			##else
				##ssl=`echo ${includes} | jq -cr '.|map(contains("/etc/nginx/conf.d/ssl.conf"))' | egrep -c 'true'`
			##fi
			##echo "${includes}|${type}"
			
			
			#if [ ${type} == 'array' ]; then
				#ssl=`echo ${includes} | jq --arg ssl_file "${INCLUDE_SSL_FILE}" -cr '.|map(contains($ssl_file))' | egrep -c 'true'`
			#elif [ ${type} == 'string' ]; then
				##echo "TYPE STRING: "${type}
				#ssl=`echo ${includes} | jq --arg ssl_file "${INCLUDE_SSL_FILE}" -cr '.|contains($ssl_file)' | egrep -c 'true'`
			#else
				##echo "TYPE NULL: "${type}
				#ssl=0
			#fi
			
			##echo "SSL: ${ssl}"
			
			#if [ ${ssl} -ne 0 ]; then
				#echo 1
			#else 
				#echo 0
			#fi
			
			
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
		server_name=$( get_value "${vhost}" "server_name" )
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

for uri in ${VHOSTS[@]}; do
	
	#vhost=`GET /${uri}`
	
	process_vhost "${uri}"
	
done

echo "Now run 01_add_ssl_conf.sh"

exit 0

