#!/bin/sh
cd $($dirname $0)
./load.pl \
	--interval=5 \
	--hosts_file=load-hosts.txt \
	--zone_file=/var/named/sg.edu.ofs.rr.ldap \
	--zone=ldap.rr.ofs.edu.sg \
	--bot_file=load-ldap-bot.pl 
