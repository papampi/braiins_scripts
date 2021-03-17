#!/bin/bash

LOG_FILE="/home/user_name/ip_check.log"
ip_list=/home/user_name/ip_list.csv
USERNAME=root
PASSWORD=xxxxxxxxx
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )


while true
do
  check_ip_1=$(curl -s -m 5 https://ipecho.net/plain)
  if [[ "$check_ip_1" =~ ^(([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$ ]]  && ([[ "$check_ip_1" != "" ]] || [[ "$check_ip_1" != " " ]] || [[ -z $check_ip_1 ]]) ; then
    echo "1st IP valid: $check_ip_1"
    valid_ip_1=ok
  else
    echo "1st IP not valid"
    valid_ip_1=nok
  fi
  sleep 60
  check_ip_2=$(curl -s -m 5 https://ipecho.net/plain)
  if [[ "$check_ip_2" =~ ^(([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$ ]] && ([[ "$check_ip_2" != "" ]] || [[ "$check_ip_2" != " " ]] || [[ -z $check_ip_2 ]]) ; then
    echo "2nd IP valid: $check_ip_2"
    valid_ip_2=ok
  else
    echo "2nd IP not valid"
    valid_ip_2=nok
  fi

  if [[ "$check_ip_1" != "$check_ip_2" ]] && [[ "$valid_ip_1" == "ok" ]] && [[ "$valid_ip_2" == "ok" ]] ; then
    echo "$(date) - IP changed: 1st IP: $check_ip_1 , 2nd IP: $check_ip_2 " |  tee -a ${LOG_FILE}
    echo "Checking again" |  tee -a ${LOG_FILE}

    sleep 60

    check_ip_1=$(curl -s -m 5 https://ipecho.net/plain)
    if [[ "$check_ip_1" =~ ^(([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$ ]]  && ([[ "$check_ip_1" != "" ]] || [[ "$check_ip_1" != " " ]] || [[ -z $check_ip_1 ]]) ; then
      echo "1st IP valid: $check_ip_1"
      valid_ip_1=ok
    else
      echo "1st IP not valid"
      valid_ip_1=nok
    fi
    sleep 60
    check_ip_2=$(curl -s -m 5 https://ipecho.net/plain)
    if [[ "$check_ip_2" =~ ^(([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$ ]] && ([[ "$check_ip_2" != "" ]] || [[ "$check_ip_2" != " " ]] || [[ -z $check_ip_2 ]]) ; then
      echo "2nd IP valid: $check_ip_2"
      valid_ip_2=ok
    else
      echo "2nd IP not valid"
      valid_ip_2=nok
    fi

    if [[ "$check_ip_1" != "$check_ip_2" ]] && [[ "$valid_ip_1" == "ok" ]] && [[ "$valid_ip_2" == "ok" ]] ; then
      echo "####################################################################"  |  tee -a ${LOG_FILE}
      echo "$(date) - IP changed: 1st IP: $check_ip_1 , 2nd IP: $check_ip_2 " |  tee -a ${LOG_FILE}
      echo "####################################################################"  |  tee -a ${LOG_FILE}
     "$DIR"/bos-toolbox command $ip_list -u $USERNAME -p $PASSWORD " /etc/init.d/bosminer reload"
    elif [[ "$valid_ip_1" == "nok" ]] || [[ "$valid_ip_2" == "nok" ]] ; then
      echo "Not a valid IP: 1st IP: $check_ip_1 , 2nd IP: $check_ip_2"
    else
      echo "IP not changed: 1st IP: $check_ip_1 , 2nd IP: $check_ip_2"
    fi

  elif [[ "$valid_ip_1" == "nok" ]] || [[ "$valid_ip_2" == "nok" ]] ; then
    echo "Not a valid IP: 1st IP: $check_ip_1 , 2nd IP: $check_ip_2"
  else
    echo "IP not changed: 1st IP: $check_ip_1 , 2nd IP: $check_ip_2"
  fi
  sleep 60

  echo ""
done
