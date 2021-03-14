#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
PASSWORD=xxxxxx

if [[ $1 == "check" ]] || [[ $1 == "check_reload" ]]
then
  for i in {20..101}
  do
    ip="192.168.1.$i"
    fping -c1 -t100 $ip 2>/dev/null 1>/dev/null
    if [ "$?" = 0 ]
    then
      if ! echo '{"command":"version"}' | nc $ip 4028 |jq ."VERSION"[]."BOSminer"  | grep -q bosminer
      then
        echo "$ip no bosminer found"
      else
        accepted_shares=$(echo '{"command":"summary"}' | nc $ip 4028 | jq ."SUMMARY"[]."Accepted")
        elapsed=$(echo '{"command":"summary"}' | nc $ip 4028 | jq ."SUMMARY"[]."Elapsed")
        if [[ $accepted_shares == 0 ]] && [[ $elapsed -gt 120 ]]
        then
          echo "$ip Accepted Shares in $elapsed Sec is $accepted_shares, Restart miner"
          if [[ $1 == "check_reload" ]]
          then
            "$DIR"/bos-toolbox command $ip -p $PASSWORD "/etc/bosminer.toml && /etc/init.d/bosminer restart"
          fi
        else
          echo "$ip Accepted Shares in $elapsed Sec is $accepted_shares"
        fi
      fi
    else
      echo "$ip OFFLINE"
    fi
  done
else
  echo "Ivalid Input, Use: check or check_reload"
fi
