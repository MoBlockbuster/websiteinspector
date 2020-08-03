#!/usr/bin/env bash
# Skript to monitor the HTTP-CODE, the HTTP response time  and the TLS-TTL for any websites with mail notification

WEBSITES="https://github.com"
MAILFROM=""
MAILTO=""
TMPFILE="/tmp/websiteinspector.log"
TLSTTLWARN="14"
TLSTTLCRIT="7"

# Show all monitored websites with parameter -s
if [ "$1" == "-s" ]
then
	echo -e "\e[1;33mShow all monitored websites:\e[0m"
	for i in $WEBSITES
	do
		echo -e "\e[1;33m-> \e[1;34m$i\e[0m"
	done
	exit 0
fi

if [ ! -f "${TMPFILE}" ]
then
	echo -e "This file is managed by websiteinspector.sh.\nPlease do not change anything here!\nHTTP problemes:" > "${TMPFILE}"
fi

function tlsexpire()
{
	x=$(echo ${i##*/})
	timeout 2 bash -c "</dev/tcp/"$x"/443"
	RC_PORTCHECK=$?
	if [ $RC_PORTCHECK -ne "0" ]
	then
		echo "HTTPS Port 443 seems to be closed"
	else
		TLS=$(echo | openssl s_client -connect "$x:443" -servername $x 2>/dev/null | openssl x509 -noout -dates | grep notAfter | sed -e 's#notAfter=##')
                a=$(date -d "$TLS" +%s)
                b=$(date +%s)
                c=$((a-b))
                d=$((c/3600/24))
                echo -e "\e[1;33mTLS-Certificate expire in $d days\e[0m"
                if [ $d -gt 14 ]
		then
			echo -e "\e[1;34mTLS-Certifikat OK\e[0m"
                        grep -q "$x TLS-Certificate" "${TMPFILE}"
                        if [ $? -eq 0 ]
                        then
                	        sed -i "\,$x TLS-Certificate,d" "${TMPFILE}"
                                echo -e "\e[1;31m$x TLS-Certificate expire in $d days -> OK\e[0m" | mailx -s "TLSCertificate for $x expire in $d days -> OK" -r ${MAILFROM} ${MAILTO}
                        fi
		elif [ $d -le 14 ] && [ $d -gt 7 ]
                then
                        echo -e "\e[1;31mTLS-Certifikate WARNING\e[0m"
                        grep -q "$x TLS-Certificate-WARNING" "${TMPFILE}"
                        if [ $? -eq 0 ]
                        then
                                continue
                        fi
                        echo -e "\e[1;31m$x TLS-Certificate-WARNING = $d Tage INFO\e[0m" >> "${TMPFILE}"
                        echo -e "\e[1;31m$x TLS-Certificate-WARNING expire in $d days for $x\e[0m" | mailx -s "TLS-Certifikate WARNING $x. Valid for $d days" -r ${MAILFROM} ${MAILTO}
                elif [ $d -le 7 ]
                then
                        echo -e "\e[1;31mTLS-Certificate ALARM\e[0m"
                        grep -q "$x TLS-Certificate-ALARM" "${TMPFILE}"
                        if [ $? -eq 0 ]
                        then
                                continue
                        fi
                        echo -e "\e[1;31m$x TLS-Certificate-ALARM = $d Tage ALARM\e[0m" >> "${TMPFILE}"
                        echo -e "\e[1;31m$x TLS-Certificate-ALARM expire in $d days\e[0m" | mailx -s "TLS-Certifikate ALARM $x. Valid for $d days" -r ${MAILFROM} ${MAILTO}
                elif [ $d -eq 0 ]
                then
                        echo -e "\e[1;31mTLS-Certifikate ZERODAY-ALARM\e[0m"
                        grep -q "$x TLS-Certificate ZERODAY-ALARM" "${TMPFILE}"
                        if [ $? -eq 0 ]
                        then
                                return
                        fi
                        echo -e "\e[1;31m$x TLS-Certificate ZERODAY-ALARM = $d Tage ZERODAY-ALARM\e[0m" >> "${TMPFILE}"
                        echo -e "\e[1;31m$x TLS-Certificate ist expire. Lifetime = $d days\e[0m" | mailx -s "TLS-Certifikate ZERODAY-ALARM für $x" -r ${MAILFROM} ${MAILTO}
                fi
	fi
}

for i in $WEBSITES
do
	CODE=$(curl -L --user-agent "websiteinspector" --write-out "%{http_code}\n" --silent --output /dev/null $i)
	if [ "$CODE" -eq 200  ]
	then
		echo ""
		echo "+++URL: $i" 
		echo "HTTP Statuscode = $CODE OK"
		grep -q "$i HTTP Statuscode" "${TMPFILE}"
		if [ $? -eq 0 ]
		then
			sed -i "\,$i HTTP Statuscode,d" "${TMPFILE}"
			echo "$i HTTP Statuscode = $CODE ERROR -> OK" | mailx -s "HTTP Statuscode for $i ERROR -> OK" -r ${MAILFROM} ${MAILTO}
	        fi
		tlsexpire
	fi
	TIME=$(curl -L --user-agent "websiteinspector" --write-out "%{time_total}\n" "$i" --silent --output /dev/null | awk -F \, '{print $1}')
        if [ "$TIME" -lt 3 ]
        then
		echo "HTTP Timetotal = $TIME OK"
		grep -q "$i HTTP Timetotal" "${TMPFILE}"
		if [ $? -eq 0 ]
		then
			sed -i "\,$i HTTP Timetotal,d" "${TMPFILE}"
			echo "$i HTTP Timetotal = $TIME WARNING -> OK" | mailx -s "HTTP Timetotal for $i WARNING -> OK" -r ${MAILFROM} ${MAILTO}
		fi
         elif [ "$TIME" -ge 8 ]
         then
		grep -q "$i HTTP Timetotal" "${TMPFILE}"
		if [ $? -eq 0 ]
		then
			echo "$i HTTP Timetotal = $TIME WARNING (is on the list)"
			continue
		fi
		echo "HTTP Timetotal = $TIME WARNING"
                echo "$i HTTP Timetotal = $TIME WARNING" >> "${TMPFILE}"	
                echo "$i HTTP Timetotal = $TIME WARNING" | mailx -s "HTTP TIME $i = $TIME WARNING" -r ${MAILFROM} ${MAILTO}
                
	else
		echo ""
		echo "---URL: $i"
	        echo "HTTP Statuscode = $CODE ERROR"
		grep -q "$i HTTP Statuscode" "${TMPFILE}"
		if [ $? -eq 0 ]
		then
			continue
		fi
		echo "$i HTTP Statuscode = $CODE OK -> ERROR" | mailx -s "HTTP Statuscode for $i OK -> ERROR" -r ${MAILFROM} ${MAILTO}
		echo "$i HTTP Statuscode = $CODE ERROR" >> "${TMPFILE}"
	fi

done

echo ""

cat "${TMPFILE}"

