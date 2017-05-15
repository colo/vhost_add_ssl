#!/bin/bash

INCLUDE_SSL_FILE="/etc/nginx/conf.d/ssl.conf"

SSL_NOT_ADDED="./ssl_not_added"
TO_ADD_SSL="./to_add_ssl"

. resty
resty 'http://127.0.0.1:8081/nginx/vhosts/' -Z -v -H "Accept: application/json" -H "Content-Type: application/json" 

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
		echo ${uri}
		#echo ${vhost}
		echo ${ssl_conf}
		echo "Saving ${uri}/${index}"
		saved_vhost=`PUT /${uri}/${index} ${ssl_conf}`
		#saved_vhost=`GET /${uri}/${index}`
		#echo $saved_vhost | jq -Rrc '.'
	fi
	
	
}

process_uri (){
	local uri=$1
	local index=$2
	
	#echo "GET /${uri}/${index}"

	vhost=`GET /${uri}/${index}`
	
	type=`echo ${vhost} | jq -cr '. | type'`
	
	if [ ${type} == 'array' ]; then
		echo "error, shouldn't be an array at all"
		exit -1
		##no se procesar el array con jc, así q hago nuevamente el GET pero con indice
		#length=`echo ${vhost} | jq '.|length'`
		##echo ${length}
		#index=0
		#while [ ${index} -lt ${length} ]; do
			##echo The counter is ${index}
			##echo "I ${uri}"
			#vhost=`GET /${uri}/${index}`
			
			#include_ssl_conf "${vhost}" "${uri}/${index}"
			
			#let index=index+1
		#done
		
	else
		include_ssl_conf "${vhost}" "${uri}" "${index}"
	fi
}

while IFS=':' read -r uri root index; do
  
  process_uri "${uri}" "${index}"
  
done <${TO_ADD_SSL}

exit 0

