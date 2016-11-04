#!/bin/bash
# 
# 20161104 Siegfried


time_stamp=$(date +%Y%m%d_%H%M%S)
script_name=${0##*/}
ICINGA_PKI_DIR=/etc/icinga2/pki
api_conf="/etc/icinga2/features-available/api.conf"
zones_conf="/etc/icinga2/zones.conf"


function set_zone_conf() {

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
  echo "  parent = ${ParentZone}"
  echo "  endpoints = [ NodeName ]"
  echo "}"
  echo ""
  echo "object Endpoint ${ParentEndpoint} {}"
  echo ""
  echo "object Zone ${ParentZone} {"
  echo "  endpoints = [ \"$ParentEndpoints\" ]"
  echo "}"
  echo ""
  echo "object Zone \"director-global\" { global = true }"
  echo ""

  exec 1>&3-

}


function set_api.conf() {
  sed -i '
    /accept_commands/d
    /accept_config/d
    /}/d
  ' ${api_conf}

  exec 3>&1
  exec 1>> $api_conf

  echo ""
  echo "  accept_commands = true"
  echo "  accept_config = true"
  echo ""
  echo "}"
  echo ""

  exec 1>&3-

}


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

# from here first coment out

    AgentName="myagent"
    Ticket="myticket"
    ParentZone="master"
    ParentEndpoints="myicingaserver"
    CAServer="myicingaserver"

set_zone_conf
set_api.conf
create_pki_setup


