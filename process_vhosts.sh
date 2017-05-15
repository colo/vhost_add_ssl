#!/bin/bash

. resty
resty http://127.0.0.1:8081/nginx/vhosts/
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
			includes=$( get_value "${vhost}" "include" )
			type=`echo ${includes} | jq -cr '.|type'`
			
			if [ ${type} == 'array' ]; then
				#ssl=`echo ${includes} | jq -cr '.|if map(contains("/etc/nginx/conf.d/ssl.conf") == true then halt end)'`
				ssl=`echo ${includes} | jq -cr '.|map(contains("/etc/nginx/conf.d/ssl.conf"))' | egrep -c 'true'`
				
			else
				ssl=`echo ${includes} | jq -cr '.|map(contains("/etc/nginx/conf.d/ssl.conf"))' | egrep -c 'true'`
			fi
			
			if [ ${ssl} -eq 1 ]; then
				echo 1
			else 
				echo 0
			fi
			
			
		fi
		
	fi
	
	
}

process_vhost (){
	local vhost=$1
	type=`echo ${vhost} | jq -cr '. | type'`
	
	if [ ${type} == 'array' ]; then
		#no se procesar el array con jc, así q hago nuevamente el GET pero con indice
		length=`echo ${vhost} | jq '.|length'`
		#echo ${length}
		index=0
		
		while [ ${index} -lt ${length} ]; do
			#echo The counter is ${index}
			vhost=`GET /${i}/${index}`
			
			server_name=$( get_value "${vhost}" "server_name" )
			root=$( get_value "${vhost}" "root" )
			is_ssl=$( is_ssl "${vhost}" )
			#echo "${server_name}:${root}:${is_ssl}"
			
			#si no tiene ssl & tiene un root, podemos hacer el certificado
			if [ ${is_ssl} -lt 1 -a ${root} != "null" ]; then
				echo "${server_name}:${root}:${is_ssl}"
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
			echo "${server_name}:${root}:${is_ssl}"
		fi
		
	fi
}

for i in ${VHOSTS[@]}; do
	
	vhost=`GET /${i}`
	
	process_vhost "${vhost}"
	
done

exit 0

