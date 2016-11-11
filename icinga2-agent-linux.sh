#!/bin/bash
# 
#
# siegfried 20161111
#

time_stamp=$(date +%Y%m%d_%H%M%S)
script_name=${0##*/}
ICINGA_PKI_DIR=/etc/icinga2/pki
api_conf="/etc/icinga2/features-available/api.conf"
zones_conf="/etc/icinga2/zones.conf"
icinga2_conf="/etc/icinga2/icinga2.conf"


declare -i status_zones_conf=0
declare -i status_pki_setup=0
declare -i status_api_conf=0
declare -i status_icinga2_conf=0
declare -i remove_backup=0


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
  rm -v ${api_conf}.${time_stamp}.bak 1>&2
  cp -pdv ${api_conf}.${time_stamp}.bak ${api_conf} 1>&2
}


function rollback_icinga2_conf() {
  echo "rollback icinga2.conf" 1>&2
  rm -v ${icinga2_conf}.${time_stamp}.bak 1>&2
  cp -pdv ${icinga2_conf}.${time_stamp}.bak ${icinga2_conf} 1>&2
}


# remove backup if wanted
function remove_backups() {
  rm -v ${zones_conf}.${time_stamp}.bak
  rm -rv ${ICINGA_PKI_DIR}.${time_stamp}.bak
  rm -v ${api_conf}.${time_stamp}.bak
  rm -v ${icinga2_conf}.${time_stamp}.bak
}


# setup zones.conf
function set_zones_conf() {

  if [ -e $zones_conf ] ; then
    mv -v $zones_conf ${zones_conf}.${time_stamp}.bak
    if [ $? -gt 0 ] ; then
      echo "connot access file $zones_conf" 1>&2
    fi
  fi

  exec 3>&1
  exec 1> $zones_conf

  echo ""
  echo "object Endpoint NodeName {"
  echo "  host = NodeName"
  echo "}"
  echo ""
  echo "object Zone ZoneName {"
  echo "  parent = \"${ParentZone}\""
  echo "  endpoints = [ NodeName ]"
  echo "}"
  echo ""
  echo "object Endpoint \"${ParentEndpoints}\" {"
  echo "  host = \"${ParentEndpoints}\""
  echo "}"
  echo ""
  echo "object Zone \"${ParentZone}\" {"
  echo "  endpoints = [ \"${ParentEndpoints}\" ]"
  echo "}"
  echo ""
  echo "object Zone \"director-global\" {"
  echo "   global = true"
  echo "}"
  echo ""

  exec 1>&3-

  # check file for change success
  local search_string="object\ Zone\ \"${ParentZone}\" {"
  grep "$search_string" $zones_conf > /dev/null
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

    /conf.d/d

  ' ${icinga2_conf}

  # check file for change success
  local search_string="conf.d"
  grep "$search_string" $icinga2_conf > /dev/null
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
  local search_string="accept_commands"
  grep "$search_string" $api_conf > /dev/null
  if [ $? -gt 0 ] ; then
    (( status_api_conf++ ))
  fi

}



# config agent pki
function create_pki_setup() {

  user=$1
  group=$2

  if [ -d $ICINGA_PKI_DIR ] ; then
    cp -Rpdv ${ICINGA_PKI_DIR} ${ICINGA_PKI_DIR}.${time_stamp}.bak
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
    --trustedcert ${ICINGA_PKI_DIR}/trusted-master.crt \
    --host ${CAServer}

  if [ $? -gt 0 ] ; then
    (( status_pki_setup++ ))
  fi

  icinga2 pki request --host ${ParentEndpoints} --port 5665 \
    --key ${ICINGA_PKI_DIR}/${AgentName}.key \
    --cert ${ICINGA_PKI_DIR}/${AgentName}.crt \
    --trustedcert ${ICINGA_PKI_DIR}/trusted-master.crt \
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
  if [ $status_pki_setup -lt 1 ] ; then
    echo "set pki config successfull"
  else
    echo "set pki config failed"
  fi
  if [ $status_api_conf -lt 1 ] ; then
    echo "set ${api_conf} successfull"
  else
    echo "set ${api_conf} failed"
  fi
  if [ $status_icinga2_conf -lt 1 ] ; then
    echo "set ${icinga2_conf} successfull"
  else
    echo "set ${icinga2_conf} failed"
  fi

  # echo "$status_zones_conf $status_pki_setup $status_api_conf $status_icinga2_conf" 

  if [ $status_zones_conf -gt 0 ] || [ $status_pki_setup -gt 0 ] || [ $status_api_conf -gt 0 ] || [ $status_icinga2_conf -gt 0 ] ; then
    rollback_zones_conf
    rollback_pki_setup
    rollback_api_conf
    rollback_icinga2_conf
  fi
}


#    AgentName="srv05.meiner.de"
#    Ticket="1234567890123456789012345678901234567890"
#    ParentZone="master"
#    ParentEndpoints="myicinga2.firma.de"
#    CAServer="myicinga2.firma.de"
#
# set_icinga2_conf
# set_zones_conf
# set_api_conf
# create_pki_setup nagios nagios
# check_rollback
# # remove_backups


