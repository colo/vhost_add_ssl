#!/bin/bash

INCLUDE_SSL_FILE="/etc/nginx/conf.d/ssl.conf;"
INCLUDE_SSL_CERT="/etc/letsencrypt/live/%s/fullchain.pem;"
INCLUDE_SSL_CERT_KEY="/etc/letsencrypt/live/%s/privkey.pem;"

SSL_NOT_ADDED="./ssl_not_added"
rm ${SSL_NOT_ADDED}
touch ${SSL_NOT_ADDED}
echo "SERVER_NAME:ROOT:SSL" > ${SSL_NOT_ADDED}

TO_ADD_SSL="./to_add_ssl"
rm ${TO_ADD_SSL}
touch ${TO_ADD_SSL}
echo "SERVER_NAME:ROOT:SSL" > ${TO_ADD_SSL}

SSL_FAILED="./ssl_failed"
rm ${SSL_FAILED}
touch ${SSL_FAILED}
echo "SERVER_NAME:ROOT:SSL" > ${SSL_FAILED}

ADD_SSL_CMD="./certbot certonly --email certs.infraestructura@e-ducativa.com --no-self-upgrade --webroot -w %s -d %s"

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

copy_include_ssl (){
	local vhost=$1
	local uri=$2
	#local index=$2
	#echo "index...." ${vhost} ${index}
	
	SSL_CERT=`printf "${INCLUDE_SSL_CERT}" "${uri}"`
	SSL_CERT_KEY=`printf "${INCLUDE_SSL_CERT_KEY}" "${uri}"`
	
	#add ssl include
	ssl=`echo ${vhost} | jq --arg ssl_file ${INCLUDE_SSL_FILE} '.include |= . + [$ssl_file]'`
	cert=`echo ${ssl} | jq --arg ssl_cert ${SSL_CERT} '.ssl_certificate = $ssl_cert'`
	key=`echo ${cert} | jq --arg ssl_cert_key ${SSL_CERT_KEY} '.ssl_certificate_key = $ssl_cert_key'`
	#echo ${ssl}
	echo ${key}
}
process_vhost (){
	local vhost=$1
	local uri=$2
	
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
			
			#si no tiene ssl & tiene un root, podemos hacer el certificado
			if [ ${is_ssl} -lt 1 -a ${root} != "null" ]; then
				echo "${server_name}:${root}:${is_ssl}" >> ${TO_ADD_SSL}
				cmd_exec=`printf "${ADD_SSL_CMD}" "${server_name}" "${root}"`
				echo "executing.... "${cmd_exec}
				cmd_status=`${cmd_exec}`
				echo ${cmd_status}
				if [ ${cmd_status} -ne 0 ]; then
					echo "${server_name}:${root}:${is_ssl}" >> ${SSL_FAILED}
				else
					copy_include_ssl "${vhost}" "${uri}"
				fi
			else
				echo "${server_name}:${root}:${is_ssl}" >> ${SSL_NOT_ADDED}
			
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
			echo "${server_name}:${root}:${is_ssl}" >> ${TO_ADD_SSL}
			cmd_exec=`printf "${ADD_SSL_CMD}" "${server_name}" "${root}"`
			echo "executing.... "${cmd_exec}
			cmd_status=`${cmd_exec}`
			echo ${cmd_status}
			if [ ${cmd_status} -ne 0 ]; then
				echo "${server_name}:${root}:${is_ssl}" >> ${SSL_FAILED}
			else
				copy_include_ssl "${vhost}" "${uri}"
			fi
				
		else
			echo "${server_name}:${root}:${is_ssl}" >> ${SSL_NOT_ADDED}
		fi
		
	fi
}

for uri in ${VHOSTS[@]}; do
	
	vhost=`GET /${uri}`
	
	process_vhost "${vhost}" "${uri}"
	
done

exit 0

