#!/bin/bash
# 
#
# siegfried 20161107
#


# config script
time_stamp=$(date +%Y%m%d_%H%M%S)
script_name=${0##*/}
ICINGA_PKI_DIR=/etc/icinga2/pki
api_conf="/etc/icinga2/features-available/api.conf"
zones_conf="/etc/icinga2/zones.conf"


# setup zonnes.conf
function set_zones_conf() {

  if [ -e $zones_conf ] ; then
    mv -v $zones_conf ${zones_conf}.${time_stamp}.bak
    if [ $? -gt 0 ] ; then
      echo "connot acces file $zones_conf" 1>&2
      exit 1
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


}


# config api to accept commands from Icinga2 server
function set_api_conf() {

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
}


# config agent pki
function create_pki_setup() {

  install -o nagios -g nagios -m 0755 -d $ICINGA_PKI_DIR

  icinga2 pki new-cert --cn ${AgentName} \
    --key ${ICINGA_PKI_DIR}/${AgentName}.key \
    --cert ${ICINGA_PKI_DIR}/${AgentName}.crt

  icinga2 pki save-cert --key ${ICINGA_PKI_DIR}/${AgentName}.key \
    --trustedcert ${ICINGA_PKI_DIR}/trusted-master.crt \
    --host ${CAServer}

  icinga2 pki request --host ${ParentEndpoints} --port 5665 \
    --key ${ICINGA_PKI_DIR}/${AgentName}.key \
    --cert ${ICINGA_PKI_DIR}/${AgentName}.crt \
    --trustedcert ${ICINGA_PKI_DIR}/trusted-master.crt \
    --ca ${ICINGA_PKI_DIR}/ca.crt \
    --ticket "${Ticket}"


}

#    AgentName="myagent.firma.de"
#    Ticket="1234567890123456789012345678901234567890"
#    ParentZone="master"
#    ParentEndpoints="myicingaserver"
#    CAServer="myicingaserver"
#
#set_zones_conf
#set_api_conf
#create_pki_setup


