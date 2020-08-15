#!/usr/bin/env bash
# Skript to monitor the HTTP-CODE, the HTTP response time and the TLS-TTL for any websites with mail notification
#######################################
# Author on GitHub: MoBlockbuster     #
#######################################

WEBARRAY=("")
WEBCNF="config_websiteinspector.cnf"

# System variables. Do not change this!
CURL=$(which curl)
OSSL=$(which openssl)
MAILX=$(which mailx)

# Create config for me. Do not change this!
if [ ! -f $WEBCNF ]
then
	echo -e "\e[1;33mI create my config\e[0m"
	touch $WEBCNF
fi

grep -q WEBSITE $WEBCNF || echo "WEBSITES=\"https://github.com http://www.postfix.org/\"" >> $WEBCNF
grep -q MAILFROM $WEBCNF || echo "MAILFROM=\"\"" >> $WEBCNF
grep -q MAILTO $WEBCNF || echo "MAILTO=\"\"" >> $WEBCNF
grep -q TLSTTLWARN $WEBCNF || echo "TLSTTLWARN=\"14\"" >> $WEBCNF
grep -q TLSTTLCRIT $WEBCNF || echo "TLSTTLCRIT=\"7\"" >> $WEBCNF
grep -q HTTPRESPTIME $WEBCNF || echo "HTTPRESPTIME=\"3\"" >> $WEBCNF

# Show current settings
echo -e "\e[1;31m---------------------------\e[0m"
echo -e "\e[1;33mMy current settings:\e[0m"
echo "MAILFROM: $MAILFROM"
echo "MAILTO: $MAILTO"
echo "TLSWARNING: $TLSTTLWARN"
echo "TLSCRITICAL: $TLSTTLCRIT"
echo "HTTP-RESP-TIME: $HTTPRESPTIME"
echo -e "\e[1;31m---------------------------\e[0m"

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

# Remove the last slash
for i in $WEBSITES
do
	DIRTYURL=$(echo "${i: -1}")
	if [ $DIRTYURL = "/" ]
	then
		#echo "Slash >/< detected"
		CLEANURL=${i::-1}
		WEBARRAY+=("$CLEANURL")
		#echo -e "New URL: \e[1;33m$CLEANURL\e[0m"
	else
		#echo "No slash >/< found"
		WEBARRAY+=("$i")
		#echo -e "URL is OK: \e[1;33m$i\e[0m"
	fi
done

# Adjusted URL
WEBSITES=${WEBARRAY[*]}

if [ ! -f "${TMPFILE}" ]
then
	echo -e "This file is managed by websiteinspector.sh.\nPlease do not change anything here!\nHTTP problemes:" > "${TMPFILE}"
fi

function tlsexpire()
{
	x=$(echo ${i##*/})
	timeout 2 bash -c "</dev/tcp/$x/443" &>/dev/null
	RC_PORTCHECK=$?
	if [ $RC_PORTCHECK -ne "0" ]
	then
		echo -e "\e[1;31mHTTPS Port 443 seems to be closed\e[0m"
	else
		TLS=$(echo | $OSSL s_client -connect "$x:443" -servername $x 2>/dev/null | $OSSL x509 -noout -dates | grep notAfter | sed -e 's#notAfter=##')
                a=$(date -d "$TLS" +%s)
                b=$(date +%s)
                c=$((a-b))
                d=$((c/3600/24))
                echo -e "\e[1;33mTLS-Certificate expire in $d days\e[0m"
                if [ $d -gt $TLSTTLWARN ]
		then
			echo -e "\e[1;33mTLS-Certifikat OK\e[0m"
                        grep -q "$x TLS-Certificate" "${TMPFILE}"
                        if [ $? -eq 0 ]
                        then
                	        sed -i "\,$x TLS-Certificate,d" "${TMPFILE}"
                                echo -e "\e[1;31m$x TLS-Certificate expire in $d days -> OK\e[0m" | $MAILX -s "TLSCertificate for $x expire in $d days -> OK" -r ${MAILFROM} ${MAILTO}
                        fi
		elif [ $d -le $TLSTTLWARN ] && [ $d -gt $TLSTTLCRIT ]
                then
                        echo -e "\e[1;31mTLS-Certifikate WARNING\e[0m"
                        grep -q "$x TLS-Certificate-WARNING" "${TMPFILE}"
                        if [ $? -eq 0 ]
                        then
                                return
                        fi
                        echo -e "\e[1;31m$x TLS-Certificate-WARNING = $d Tage INFO\e[0m" >> "${TMPFILE}"
                        echo -e "\e[1;31m$x TLS-Certificate-WARNING expire in $d days for $x\e[0m" | $MAILX -s "TLS-Certifikate WARNING $x. Valid for $d days" -r ${MAILFROM} ${MAILTO}
                elif [ $d -le $TLSTTLCRIT ]
                then
                        echo -e "\e[1;31mTLS-Certificate ALARM\e[0m"
                        grep -q "$x TLS-Certificate-ALARM" "${TMPFILE}"
                        if [ $? -eq 0 ]
                        then
                                return
                        fi
                        echo -e "\e[1;31m$x TLS-Certificate-ALARM = $d Tage ALARM\e[0m" >> "${TMPFILE}"
                        echo -e "\e[1;31m$x TLS-Certificate-ALARM expire in $d days\e[0m" | $MAILX -s "TLS-Certifikate ALARM $x. Valid for $d days" -r ${MAILFROM} ${MAILTO}
                elif [ $d -eq 0 ]
                then
                        echo -e "\e[1;31mTLS-Certifikate ZERODAY-ALARM\e[0m"
                        grep -q "$x TLS-Certificate ZERODAY-ALARM" "${TMPFILE}"
                        if [ $? -eq 0 ]
                        then
                                return
                        fi
                        echo -e "\e[1;31m$x TLS-Certificate ZERODAY-ALARM = $d Tage ZERODAY-ALARM\e[0m" >> "${TMPFILE}"
                        echo -e "\e[1;31m$x TLS-Certificate ist expire. Lifetime = $d days\e[0m" | $MAILX -s "TLS-Certifikate ZERODAY-ALARM für $x" -r ${MAILFROM} ${MAILTO}
                fi
	fi
}

for i in $WEBSITES
do
	CODE=$($CURL -L --user-agent "websiteinspector" --write-out "%{http_code}\n" --silent --output /dev/null $i)
	if [ "$CODE" -eq 200  ]
	then
		echo ""
		echo -e "\e[1;34m+++URL: $i\e[0m" 
		echo -e "\e[1;33mHTTP Statuscode = $CODE OK\e[0m"
		grep -q "$i HTTP Statuscode" "${TMPFILE}"
		if [ $? -eq 0 ]
		then
			sed -i "\,$i HTTP Statuscode,d" "${TMPFILE}"
			echo "$i HTTP Statuscode = $CODE ERROR -> OK" | $MAILX -s "HTTP Statuscode for $i ERROR -> OK" -r ${MAILFROM} ${MAILTO}
	        fi
		tlsexpire
	fi
	TIME=$($CURL -L --user-agent "websiteinspector" --write-out "%{time_total}\n" "$i" --silent --output /dev/null | awk -F \, '{print $1}')
        if [ "$TIME" -lt "$HTTPRESPTIME" ]
        then
		echo -e "\e[1;33mHTTP Timetotal = $TIME OK\e[0m"
		grep -q "$i HTTP Timetotal" "${TMPFILE}"
		if [ $? -eq 0 ]
		then
			sed -i "\,$i HTTP Timetotal,d" "${TMPFILE}"
			echo -e "\e[1;31m$i HTTP Timetotal = $TIME WARNING -> OK\e[0m" | $MAILX -s "HTTP Timetotal for $i WARNING -> OK" -r ${MAILFROM} ${MAILTO}
		fi
         elif [ "$TIME" -ge 8 ]
         then
		grep -q "$i HTTP Timetotal" "${TMPFILE}"
		if [ $? -eq 0 ]
		then
			echo "$i HTTP Timetotal = $TIME WARNING (is on the list)"
			continue
		fi
		echo -e "\e[1;31mHTTP Timetotal = $TIME WARNING\e[0m"
                echo "$i HTTP Timetotal = $TIME WARNING" >> "${TMPFILE}"	
                echo "$i HTTP Timetotal = $TIME WARNING" | $MAILX -s "HTTP TIME $i = $TIME WARNING" -r ${MAILFROM} ${MAILTO}
                
	else
		echo ""
		echo "---URL: $i"
	        echo "HTTP Statuscode = $CODE ERROR"
		grep -q "$i HTTP Statuscode" "${TMPFILE}"
		if [ $? -eq 0 ]
		then
			continue
		fi
		echo "$i HTTP Statuscode = $CODE OK -> ERROR" | $MAILX -s "HTTP Statuscode for $i OK -> ERROR" -r ${MAILFROM} ${MAILTO}
		echo "$i HTTP Statuscode = $CODE ERROR" >> "${TMPFILE}"
	fi

done

echo ""

cat "${TMPFILE}"

