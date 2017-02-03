#!/bin/bash
# 
# siegfried 20170203
# version 1.2.1
# advanced for Incinga 2 Cluster
# advanced for Rollback in case of an error
# several Bugs fixed
# advanced for
#   Icinga 2 Satellite
#   aktive/passive Satellite
# advanced for
#   several satelliteserver in one zone
#   enable api feature
#   icinga2 restart integratet
# NodeName/ZoneName replaced with the real Names
# enable_checker for Satellites integrated
# 1.2.1 korrekt zone names
#


# script config
time_stamp=$(date +%Y%m%d_%H%M%S)
script_name=${0##*/}
ICINGA_PKI_DIR=/etc/icinga2/pki
api_conf="/etc/icinga2/features-available/api.conf"
checker_conf="/etc/icinga2/features-available/checker.conf"
zones_conf="/etc/icinga2/zones.conf"
icinga2_conf="/etc/icinga2/icinga2.conf"


# set control vars
declare -i status_zones_conf=0
declare -i status_pki_setup=0
declare -i status_api_conf=0
declare -i status_icinga2_conf=0
declare -i remove_backup=0
declare -i zones_conf_num=0
declare -i status_api=0
declare -i status_config=0
declare -i status_script=0


# fetch an icinga ticket from server
function get_ticket() {
  aa=$(curl -k -s -u ${apiuser}:${apipassword} -H 'Accept: application/json' -X POST 'https://'${CAServer}':5665/v1/actions/generate-ticket' -d '{ "cn": "'${AgentName}'" }')
  set -- $aa
  while [ $# -gt 0 ] ; do
    if [ $1 == "ticket" ] ; then
      Ticket=${2//\'/}
      return 0
    fi
    shift
  done
}


# rollback
function rollback_zones_conf() {
  echo rollback $zones_conf 1>&2
  cp -pdfv ${zones_conf}.${time_stamp}.bak $zones_conf 1>&2
}


function rollback_pki_setup() {
  echo "rollback PKI Setup" 1>&2
  rm -rv ${ICINGA_PKI_DIR} 1>&2
  cp -Rpdv ${ICINGA_PKI_DIR}.${time_stamp}.bak ${ICINGA_PKI_DIR} 1>&2
}


function rollback_api_conf() {
  echo "rollback api.conf" 1>&2
  cp -pdv ${api_conf}.${time_stamp}.bak ${api_conf} 1>&2
}


function rollback_icinga2_conf() {
  echo "rollback icinga2.conf" 1>&2
  cp -pdv ${icinga2_conf}.${time_stamp}.bak ${icinga2_conf} 1>&2
}


# remove backup if wanted
function remove_backups() {
  rm -v ${zones_conf}.${time_stamp}.bak
  rm -rv ${ICINGA_PKI_DIR}.${time_stamp}.bak
  rm -v ${api_conf}.${time_stamp}.bak
  rm -v ${icinga2_conf}.${time_stamp}.bak
}


# setup zones.conf aktiv agent calls
function set_zones_aktiv_conf() {

  if [ $zones_conf_num -gt 0 ] ; then
    (( status_zones_conf++ ))
    (( status_script++ ))
    echo "set_zones_conf is called two times" 1>&2
    return 1
  fi

  (( zones_conf_num++ ))

  if [ -e $zones_conf ] ; then
    mv -v $zones_conf ${zones_conf}.${time_stamp}.bak
    if [ $? -gt 0 ] ; then
      echo "connot access file $zones_conf" 1>&2
    fi
  fi

  exec 3>&1
  exec 1> $zones_conf

  set -- ${AgentEndpoints}
  local -i i=1

  echo ""
  while [ $i -le $# ] ; do
    echo "object Endpoint \"${!i}\" {"
    if [ "$AgentName" != "${!i}" ] ; then
      echo "  host = \"${!i}\""
      echo "  port = \"5665\""
    fi
    echo "}"
    echo ""
    (( i++ ))
  done
  echo ""
  echo "object Zone \"${AgentZoneName}\" {"
  echo "  parent = \"${ParentZone}\""
  echo "  endpoints = [ \"${AgentEndpoints// /\", \"}\" ]"
  echo "}"
  echo ""

  set -- ${ParentEndpoints}
  local -i i=1

  while [ $i -le $# ] ; do
    echo "object Endpoint \"${!i}\" {"
    echo "  host = \"${!i}\""
    echo "  port = \"5665\""
    echo "}"
    echo ""
    (( i++ ))
  done

  echo "object Zone \"${ParentZone}\" {"
  echo "  endpoints = [ \"${ParentEndpoints// /\", \"}\" ]"
  echo "}"
  echo ""
  echo "object Zone \"director-global\" {"
  echo "   global = true"
  echo "}"
  echo ""
  echo "object Zone \"service-global\" {"
  echo "   global = true"
  echo "}"
  echo ""
  
  exec 1>&3-

  # check file for change success
  grep 'object\ Zone\ "'${ParentZone}'" {' $zones_conf > /dev/null 2>&1
  if [ $? -gt 0 ] ; then
    (( status_zones_conf++ ))
  fi

}


# setup zones.conf passiv master calls
function set_zones_passiv_conf() {

  if [ $zones_conf_num -gt 0 ] ; then
    (( status_zones_conf++ ))
    echo "set_zones_conf is called two times" 1>&2
    return 1
  fi

  (( zones_conf_num ))

  if [ -e $zones_conf ] ; then
    mv -v $zones_conf ${zones_conf}.${time_stamp}.bak
    if [ $? -gt 0 ] ; then
      echo "connot access file $zones_conf" 1>&2
    fi
  fi

  exec 3>&1
  exec 1> $zones_conf

  set -- ${AgentEndpoints}
  local -i i=1

  echo ""
  while [ $i -le $# ] ; do
    echo "object Endpoint \"${!i}\" {"
    echo "}"
    echo ""
    (( i++ ))
  done
  echo ""
  echo "object Zone \"${AgentZoneName}\" {"
  echo "  parent = \"${ParentZone}\""
  echo "  endpoints = [ \"${AgentEndpoints// /\", \"}\" ]"
  echo "}"
  echo ""

  set -- ${ParentEndpoints}
  local -i i=1

  while [ $i -le $# ] ; do
    echo "object Endpoint \"${!i}\" {"
    echo "}"
    echo ""
    (( i++ ))
  done

  echo "object Zone \"${ParentZone}\" {"
  echo "  endpoints = [ \"${ParentEndpoints// /\", \"}\" ]"
  echo "}"
  echo ""
  echo "object Zone \"director-global\" {"
  echo "   global = true"
  echo "}"
  echo ""
  echo "object Zone \"service-global\" {"
  echo "   global = true"
  echo "}"
  echo ""
  
  exec 1>&3-

  # check file for change success
  grep 'object\ Zone\ "'${ParentZone}'" {' $zones_conf > /dev/null 2>&1
  if [ $? -gt 0 ] ; then
    (( status_zones_conf++ ))
  fi

}


# config icinga2 to ignore conf.d
function set_icinga2_conf() {

  if [ -e $icinga2_conf ] ; then
    cp -pdv $icinga2_conf ${icinga2_conf}.${time_stamp}.bak
    if [ $? -gt 0 ] ; then
      echo "connot acces file $icinga2_conf" 1>&2
    fi
  fi

  sed -i '

    #  /conf.d/d
    s/^ *include.*conf\.d/\/\/ &/

  ' ${icinga2_conf}

  # check file for change success
  grep '^ *include.*conf\.d' $icinga2_conf
  if [ $? -lt 1 ] ; then
    (( status_icinga2_conf++ ))
  fi

}


# config api to accept commands from Icinga2 server
function set_api_conf() {

  if [ -e $api_conf ] ; then
    cp -pdv $api_conf ${api_conf}.${time_stamp}.bak
    if [ $? -gt 0 ] ; then
      echo "connot acces file $api_conf" 1>&2
    fi
  fi

  sed -i '

    /accept_commands/d
    /accept_config/d

    /}/{
      i
      i\ \ accept_commands = true
      i\ \ accept_config = true
      i
    }

  ' ${api_conf}

  # check file for change success
  grep 'accept_commands *= *true' $api_conf > /dev/null 2>&1
  if [ $? -gt 0 ] ; then
    (( status_api_conf++ ))
  fi

  grep 'accept_config *= *true' $api_conf > /dev/null 2>&1
  if [ $? -gt 0 ] ; then
    (( status_api_conf++ ))
  fi

}


# config agent pki
function create_pki_setup() {

  user=$1
  group=$2

  if [ -d $ICINGA_PKI_DIR ] ; then
    mv -v ${ICINGA_PKI_DIR} ${ICINGA_PKI_DIR}.${time_stamp}.bak
    if [ $? -gt 0 ] ; then
      echo "connot create backup ${ICINGA_PKI_DIR}.${time_stamp}.bak" 1>&2
    fi
  fi

  install -o $user -g $group -m 0755 -d $ICINGA_PKI_DIR

  if [ $? -gt 0 ] ; then
    (( status_pki_setup++ ))
  fi

  icinga2 pki new-cert --cn ${AgentName} \
    --key ${ICINGA_PKI_DIR}/${AgentName}.key \
    --cert ${ICINGA_PKI_DIR}/${AgentName}.crt

  if [ $? -gt 0 ] ; then
    (( status_pki_setup++ ))
  fi

  icinga2 pki save-cert --key ${ICINGA_PKI_DIR}/${AgentName}.key \
    --trustedcert ${ICINGA_PKI_DIR}/${CAServer}.crt \
    --host ${CAServer}

  if [ $? -gt 0 ] ; then
    (( status_pki_setup++ ))
  fi

  icinga2 pki request --host ${CAServer} --port 5665 \
    --key ${ICINGA_PKI_DIR}/${AgentName}.key \
    --cert ${ICINGA_PKI_DIR}/${AgentName}.crt \
    --trustedcert ${ICINGA_PKI_DIR}/${CAServer}.crt \
    --ca ${ICINGA_PKI_DIR}/ca.crt \
    --ticket "${Ticket}"

  if [ $? -gt 0 ] ; then
    (( status_pki_setup++ ))
  fi

}


function check_rollback() {
    
  if [ $status_zones_conf -lt 1 ] ; then
    echo "set ${zones_conf} successfull"
  else
    echo "set ${zones_conf} failed"
  fi

  if [ $status_icinga2_conf -lt 1 ] ; then
    echo "set ${icinga2_conf} successfull"
  else
    echo "set ${icinga2_conf} failed"
  fi

  if [ $status_api_conf -lt 1 ] ; then
    echo "set ${api_conf} successfull"
  else
    echo "set ${api_conf} failed"
  fi

  if [ $status_pki_setup -lt 1 ] ; then
    echo "set pki config successfull"
  else
    echo "set pki config failed"
  fi

  # echo "$status_zones_conf $status_icinga2_conf $status_api_conf $status_pki_setup" 

  if [ $status_zones_conf -gt 0 ] || [ $status_pki_setup -gt 0 ] || [ $status_api_conf -gt 0 ] || [ $status_icinga2_conf -gt 0 ] ; then
    (( status_script++ ))
    (( status_config++ ))
    rollback_zones_conf
    rollback_icinga2_conf
    rollback_api_conf
    rollback_pki_setup
  fi
}


function display_status() {
    
  if [ $status_zones_conf -lt 1 ] ; then
    echo "set ${zones_conf} successfull"
  else
    echo "set ${zones_conf} failed"
  fi

  if [ $status_icinga2_conf -lt 1 ] ; then
    echo "set ${icinga2_conf} successfull"
  else
    echo "set ${icinga2_conf} failed"
  fi

  if [ $status_api_conf -lt 1 ] ; then
    echo "set ${api_conf} successfull"
  else
    echo "set ${api_conf} failed"
  fi

  if [ $status_pki_setup -lt 1 ] ; then
    echo "set pki config successfull"
  else
    echo "set pki config failed"
  fi

  if [ $status_api -lt 1 ] ; then
    echo "api is disabled"
  else
    echo "api is enabled"
  fi

  if [ $status_checker -lt 1 ] ; then
    echo "checker is disabled"
  else
    echo "checker is enabled"
  fi

   icinga2 feature list

  if [ $status_script -lt 1 ] ; then
    echo "script run was successfull"
  else
    echo "script run failed"
  fi

  return $status_script

}


function enable_api() {
  # check api enable status
  if [ $status_script -lt 1 ] ; then
    local -i feature_api_enabled=0
    grep 'object *ApiListener' ${api_conf//features-available/features-enabled} > /dev/null 2>&1
    if [ $? -lt 1 ] ; then
      (( feature_api_enabled++ ))
    fi

    if [ $feature_api_enabled -lt 1 ] ; then
      echo "enable feature api"
      icinga2 feature enable api
    fi

    grep 'object *ApiListener' ${api_conf//feature-available/features-enabled} > /dev/null 2>&1
    if [ $? -lt 1 ] ; then
      (( feature_api_enabled++ ))
      (( status_api++ ))
    else
      (( status_script++ ))
    fi
  fi
}


function enable_checker() {
  # check checker enable status
  if [ $status_script -lt 1 ] ; then
    local -i feature_checker_enabled=0
    grep 'object *CheckerComponent' ${checker_conf//features-available/features-enabled} > /dev/null 2>&1
    if [ $? -lt 1 ] ; then
      (( feature_checker_enabled++ ))
    fi

    if [ $feature_checker_enabled -lt 1 ] ; then
      echo "enable feature checker"
      icinga2 feature enable checker
    fi

    grep 'object *CheckerComponent' ${checker_conf//features-available/features-enabled} > /dev/null 2>&1
    if [ $? -lt 1 ] ; then
      (( feature_checker_enabled++ ))
      (( status_checker++ ))
    else
      (( status_script++ ))
    fi
  fi
}


function script_status_dep_run() {
  if [ $status_script -lt 1 ] ; then
    env $@
  fi
  return $?
}


##### Example 1 for config via Rest API #####
#
# # restapi icinga CAServer
# apiuser="myapiuser"
# apipassword="myapipassword"
# 
# ParentZone=master
# ParentEndpoints="master1.localdomain master2.localdomain"
# CAServer="master1.localdomain"
#
# AgentName=$( hostname -f )
# AgentEndpoints="agent1.localdomain agent2.localdomain"
# AgentZoneName=$AgentName
#
# get_ticket
#
# set_icinga2_conf
#
# # only one
# set_zones_aktiv_conf
# set_zones_passiv_conf
#
# set_api_conf
# create_pki_setup nagios nagios
# check_rollback
# enable_api
#
# for Satellite
# enable_checker
#
# script_status_dep_run service icinga2 restart
# # remove_backups
# display_status
###########################################

##### Example 2 for config via Rest API #####
#
# # restapi icinga CAServer
# apiuser="myapiuser"
# apipassword="myapipassword"
#  
# ParentZone=master
# ParentEndpoints="master1.localdomain master2.localdomain"
# CAServer="master1.localdomain"
# 
# AgentName=$( hostname -f )
# AgentEndpoints="$AgentName"
# AgentZoneName="$AgentName"
# 
# get_ticket
# 
# set_icinga2_conf
# 
# # only one
# set_zones_aktiv_conf
# set_zones_passiv_conf
#
# set_api_conf
# create_pki_setup nagios nagios
# check_rollback
# enable_api
#
# for Satellite
# enable_checker
#
# script_status_dep_run service icinga2 restart
# # remove_backups
# display_status
###########################################

##### Example 3 for config via gen_agent_script #####
#
# ParentZone=master
# ParentEndpoints="master1.localdomain master2.localdomain"
# CAServer="master1.localdomain"
# 
# AgentName="agent1.localdomain"
# AgentEndpoints="agent1.localdomain agent2.localdomain"
# AgentZoneName=$AgentName
# 
# Ticket="1234567890123456789012345678901234567890"
# 
# # get_ticket
# 
# set_icinga2_conf
#
# # only one
# set_zones_aktiv_conf
# set_zones_passiv_conf
#
# set_api_conf
# create_pki_setup nagios nagios
# check_rollback
# enable_api
#
# for Satellite
# enable_checker
#
# script_status_dep_run service icinga2 restart
# # remove_backups
# display_status
###########################################

##### Example 4 for config via gen_agent_script #####
# 
# ParentZone=master
# ParentEndpoints="master1.localdomain master2.localdomain"
# CAServer="master1.localdomain"

# AgentName="agent1.localdomain"
# AgentEndpoints="$AgentName"
# AgentZoneName=$AgentName

# Ticket="1234567890123456789012345678901234567890"

# get_ticket

# set_icinga2_conf
#
# # only one
# set_zones_aktiv_conf
# set_zones_passiv_conf
#
# set_api_conf
# create_pki_setup nagios nagios
# check_rollback
# enable_api
#
# for Satellite
# enable_checker
#
# script_status_dep_run service icinga2 restart
# # remove_backups
# display_status
###########################################

