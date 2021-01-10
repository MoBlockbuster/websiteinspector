#!/usr/bin/env bash
# Skript to monitor the HTTP-CODE, the HTTP response time and the TLS-TTL for any websites with mail notification
#######################################
# Author on GitHub: MoBlockbuster     #
#######################################

VERSION="2021011001"
WEBARRAY=("")
WEBCNF="config_websiteinspector.cnf"
DATE=$(date +%Y-%m-%d)

# Change dir for cron
cd "$(dirname "$0")"

function config_file
{
	grep -q WEBSITE $WEBCNF || echo "WEBSITES=\"https://github.com http://www.postfix.org\"" >> $WEBCNF
	grep -q MAILFROM $WEBCNF || echo "MAILFROM=\"\"" >> $WEBCNF
	grep -q MAILTO $WEBCNF || echo "MAILTO=\"\"" >> $WEBCNF
	grep -q TLSTTLWARN $WEBCNF || echo "TLSTTLWARN=\"14\"" >> $WEBCNF
	grep -q TLSTTLCRIT $WEBCNF || echo "TLSTTLCRIT=\"7\"" >> $WEBCNF
	grep -q HTTPRESPTIME $WEBCNF || echo "HTTPRESPTIME=\"3\"" >> $WEBCNF
	grep -q TMPFILE $WEBCNF || echo "TMPFILE=\"/tmp/websiteinspector.log\"" >> $WEBCNF
	grep -q CURLTIMEOUT $WEBCNF || echo "CURLTIMEOUT=\"8\"" >> $WEBCNF
}

# Create config for me. Do not change this!
if [ ! -f $WEBCNF ]
then
	echo -e "\e[1;33mI create my config. Please check first my config: $WEBCNF\e[0m"
	touch $WEBCNF
	config_file
	exit 0
fi

config_file

source $WEBCNF

function current_settings()
{
	# Show my current settings
	echo -e "\e[1;31m---------------------------\e[0m"
	echo -e "\e[1;33mMy current settings:\e[0m"
	echo "MAILFROM: $MAILFROM"
	echo "MAILTO: $MAILTO"
	echo "TLSWARNING: $TLSTTLWARN"
	echo "TLSCRITICAL: $TLSTTLCRIT"
	echo "HTTP-RESP-TIME: $HTTPRESPTIME"
	echo "TMPFILE: $TMPFILE"
	echo "CURLTIMEOUT: $CURLTIMEOUT"
	echo -e "\e[1;31m---------------------------\e[0m"
}

case "$1" in
	"")
		# For no parameter
		;;
	-h)
		# Show usage
		echo -e "\e[1;33mWebsiteinspector usage:\e[0m"
		echo -e "\e[1;33m-h Show usage\n-v Show version\n-s Show all monitored websites\n-f Show content of websiteinspector.log\n-r Remove the websiteinspector.log\n-u Update me from git\n-x Show my current settings\e[0m"
		exit 0
		;;
	-v)
		# Show version of websiteinspector with parameter -v
		echo -e "\e[1;33mWebsiteinspector version: \e[1;31m$VERSION\e[0m"
		exit 0
		;;
	-s)
		# Show all monitored websites with parameter -s
		echo -e "\e[1;33mShow all monitored websites:\e[0m"
		for i in $WEBSITES
		do
			echo -e "\e[1;33m-> \e[1;34m$i\e[0m"
		done
		exit 0
		;;
	-f)
		# Show content of websiteinspector.log
		echo -e "\e[1;33mShow content of $TMPFILE:\e[0m"
		cat $TMPFILE
		exit 0
		;;
	-r)
		# Remove the log
		echo -e "\e[1;33mRemove $TMPFILE\e[0m"
		rm $TMPFILE -f
		exit 0
		;;
	-u)
		# Update me
		echo -e "\e[1;33mNow i will update me!\e[0m"
		git pull
		exit 0
		;;
	-x)
		# Show my current settings
		current_settings
		exit 0
		;;
	*)
		# I dont get it
		echo -e "\e[1;31mI dont get the parameter "$1"\e[0m"
		exit 1
		;;
esac

# System variables. Do not change this!
CURL=$(which curl)
OSSL=$(which openssl)
MAILX=$(which mailx)
HOST=$(which host)

# Check whether the required tools are available
[ -z $CURL ] && echo -e "\e[1;31mPlease install curl!\e[0m" && exit 1
[ -z $OSSL ] && echo -e "\e[1;31mPlease install openssl!\e[0m" && exit 1
[ -z $MAILX ] && echo -e "\e[1;31mPlease install mailx!\e[0m" && exit 1
[ -z $HOST ] && echo -e "\e[1;31mPlease install host!\e[0m" && exit 1

# Show my current settings
current_settings

# Validate domain
function validate_domain()
{
                DOM=$(echo $i | awk -F "//" '{ print $2 }')
                host "$DOM" 2>&1 > /dev/null || { echo ""; echo -e "\e[1;5;31mDomain $DOM not found!\e[0m"; continue ;}
}

# Remove the last slash
for i in $WEBSITES
do
	DIRTYURL=$(echo "${i: -1}")
	if [ $DIRTYURL = "/" ]
	then
		CLEANURL=${i::-1}
		WEBARRAY+=("$CLEANURL")
	else
		WEBARRAY+=("$i")
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
			echo -e "\e[1;33mTLS-Certificat OK\e[0m"
                        grep -q "$x TLS-Certificate" "${TMPFILE}"
                        if [ $? -eq 0 ]
                        then
                	        sed -i "\,$x TLS-Certificate,d" "${TMPFILE}"
                                echo "$x TLS-Certificate expire in $d days -> OK" | $MAILX -s "TLSCertificate for $x expire in $d days -> OK" -r ${MAILFROM} ${MAILTO}
                        fi
		elif [ $d -le $TLSTTLWARN ] && [ $d -gt $TLSTTLCRIT ]
                then
                        echo -e "\e[1;31mTLS-Certificate WARNING\e[0m"
                        grep -q "$x TLS-Certificate-WARNING" "${TMPFILE}"
                        if [ $? -eq 0 ]
                        then
                                return
                        fi
                        echo -e "\e[1;31m$x TLS-Certificate-WARNING = $d days INFO. Date: $DATE\e[0m" >> "${TMPFILE}"
                        echo "$x TLS-Certificate-WARNING expire in $d days for $x" | $MAILX -s "TLS-Certificate WARNING $x. Valid for $d days" -r ${MAILFROM} ${MAILTO}
                elif [ $d -le $TLSTTLCRIT ]
                then
                        echo -e "\e[1;31mTLS-Certificate ALARM\e[0m"
                        grep -q "$x TLS-Certificate-ALARM" "${TMPFILE}"
                        if [ $? -eq 0 ]
                        then
                                return
                        fi
                        echo -e "\e[1;31m$x TLS-Certificate-ALARM = $d days ALARM. Date: $DATE\e[0m" >> "${TMPFILE}"
                        echo "$x TLS-Certificate-ALARM expire in $d days" | $MAILX -s "TLS-Certifikate ALARM $x. Valid for $d days" -r ${MAILFROM} ${MAILTO}
                elif [ $d -eq 0 ]
                then
                        echo -e "\e[1;31mTLS-Certificate ZERODAY-ALARM\e[0m"
                        grep -q "$x TLS-Certificate ZERODAY-ALARM" "${TMPFILE}"
                        if [ $? -eq 0 ]
                        then
                                return
                        fi
                        echo -e "\e[1;31m$x TLS-Certificate ZERODAY-ALARM = $d Tage ZERODAY-ALARM. Date: $DATE\e[0m" >> "${TMPFILE}"
                        echo "$x TLS-Certificate ist expire. Lifetime = $d days" | $MAILX -s "TLS-Certifikate ZERODAY-ALARM für $x" -r ${MAILFROM} ${MAILTO}
                fi
	fi
}

for i in $WEBSITES
do
	validate_domain
	CODE=$($CURL -L --user-agent "websiteinspector" --write-out "%{http_code}\n" --silent --output /dev/null --max-time $CURLTIMEOUT $i)
	if [ "$CODE" -eq 200 ]
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
	else
		echo ""
		echo -e "\e[1;34m---URL: $i\e[0m"
		echo -e "\e[1;31;5mHTTP Statuscode = $CODE NOK\e[0m"
		continue
	fi
	TIME=$($CURL -L --user-agent "websiteinspector" --write-out "%{time_total}\n" "$i" --silent --output /dev/null --max-time $CURLTIMEOUT | awk -F \, '{print $1}')
        if [ "$TIME" -lt "$HTTPRESPTIME" ]
        then
		echo -e "\e[1;33mHTTP Timetotal = $TIME OK\e[0m"
		grep -q "$i HTTP Timetotal" "${TMPFILE}"
		if [ $? -eq 0 ]
		then
			sed -i "\,$i HTTP Timetotal,d" "${TMPFILE}"
			echo "$i HTTP Timetotal = $TIME WARNING -> OK" | $MAILX -s "HTTP Timetotal for $i WARNING -> OK" -r ${MAILFROM} ${MAILTO}
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
                echo "$i HTTP Timetotal = $TIME WARNING. Date $DATE" >> "${TMPFILE}"
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
		echo "$i HTTP Statuscode = $CODE ERROR. Date: $DATE" >> "${TMPFILE}"
	fi
done

# Check for updates
ORILANG=$(echo $LANG)
export LANG=en_US.UTF-8
cd `dirname $0` && git remote show origin | grep -q "up to date"
if [ $? -eq 0 ]
then
	export LANG=$ORILANG
	echo ""
	echo -e "\e[1;32mI am up to date with version: $VERSION\e[0m"
	echo ""
	grep -q "Updates" $TMPFILE
	if [ $? -eq 0 ]
	then
		sed -i '/Updates/d' $TMPFILE
		echo "Now i am up to date with version $VERSION" | $MAILX -s "websiteinspector is now up to date" -r ${MAILFROM} ${MAILTO}
	fi
else
	echo ""
	echo -e "I detected updates for me.\nPlease update websiteinspector with parameter -u" | $MAILX -s "websiteinspector needs update" -r ${MAILFROM} ${MAILTO}
	grep -q "Updates" $TMPFILE
	if [ $? -ne 0 ]
	then
		echo -e "\e[1;5;31mUpdates are available for me! Start me with parameter -u. Date: $DATE\e[0m" >> ${TMPFILE}
	fi
	export LANG=$ORILANG
fi

cat "${TMPFILE}"
