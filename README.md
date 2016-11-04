# gen_agent_config #
Generate Incing2 Agent Configuration

20161104 Siegfried

# example listfile #  
comments are allowed  
host1.firma.de win  
host2.firma.fr ubuntulinux  
host3.firma.de ubuntulinux


# gen_agent_scripts
mkdir: created directory ‘test14.out’  
test14: write file test14.out/Icinga2Agent-host1.firma.de.psm1  
test14: write file test14.out/Icinga2Agent-host2.firma.fr.sh  
test14: 2 config scripts written to test14.out  


# execute a script on an agent #
‘/etc/icinga2/zones.conf’ -> ‘/etc/icinga2/zones.conf.20161104_040216.bak’  
information/base: Writing private key to '/etc/icinga2/pki/host2.fr.key'.  
information/base: Writing X509 certificate to '/etc/icinga2/pki/host2.fr.crt'.  
information/pki: Writing certificate to file '/etc/icinga2/pki/trusted-master.crt'.  
information/cli: Writing signed certificate to file '/etc/icinga2/pki/host2.fr.crt'.  
information/cli: Writing CA certificate to file '/etc/icinga2/pki/ca.crt'.  
‘/etc/icinga2/zones.conf’ -> ‘/etc/icinga2/zones.conf.20161104_040216.bak’  
information/base: Writing private key to '/etc/icinga2/pki/host2.fr.key'.  
information/base: Writing X509 certificate to '/etc/icinga2/pki/host2.fr.crt'.  
information/pki: Writing certificate to file '/etc/icinga2/pki/trusted-master.crt'.  
information/cli: Writing signed certificate to file '/etc/icinga2/pki/host2.fr.crt'.  
information/cli: Writing CA certificate to file '/etc/icinga2/pki/ca.crt'.  

the skript does  
configure pki  
setup the zones on agent  
setup api.conf  

setup the zone on  icingaserver is not yet part of the skript  
