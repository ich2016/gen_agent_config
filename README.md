# gen_agent_config
Generate Incing2 Agent and Satellite Configuration

20170203 Siegfried

Version 1.2.1
- has correct default zonenames
- config for agents or Satellites for singlemaster or clustermaster
- config Satellites single or double, like Cluster Satellites

# example listfile

comments with hash are allowed  
empty lines are allowed  

host1.firma.de win  
host2.firma.fr ubuntulinux  
host3.firma.de ubuntulinux

format of listfiles and stdin is identical

# gen_agent_scripts
mkdir: created directory ‘gen_agent_scripts.out’  
gen_icinga_agents: write file gen_agent_acripts.out/Icinga2Agent-host1.firma.de.psm1  
gen_icinga_agents: write file gen_agent_scripts.out/Icinga2Agent-host2.firma.fr.sh  
gen_icinga_agents: 2 config scripts written to gen_icinga_agents.out  


# execute a script on an agent
‘/etc/icinga2/zones.conf’ -> ‘/etc/icinga2/zones.conf.20161107_040216.bak’  
information/base: Writing private key to '/etc/icinga2/pki/host2.fr.key'.  
information/base: Writing X509 certificate to '/etc/icinga2/pki/host2.fr.crt'.  
information/pki: Writing certificate to file '/etc/icinga2/pki/trusted-master.crt'.  
information/cli: Writing signed certificate to file '/etc/icinga2/pki/host2.fr.crt'.  
information/cli: Writing CA certificate to file '/etc/icinga2/pki/ca.crt'.  

# the skript does on Agent 
setup icinga2.conf  
setup the zones.conf  
setup api.conf  
configure pki 

