#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
PASSWORD=xxxxxx
MIN_TARGET_TEMP=70
MAX_TARGET_TEMP=85
LOW_FAN_SPEED=40
HIGH_FAN_SPEED=75
NORMAL_FAN_SPEED=50

if [[ $1 == "check_temp" ]] || [[ $1 == "apply_all" ]] || [[ $1 == "apply_hot" ]] || [[ $1 == "apply_cold" ]]
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
        FAN=$(echo '{"command":"fans"}' | nc $ip 4028 | jq . | jq -r ".FANS"[]."Speed"| head -1)
        TARGET_TEMP=$(echo '{"command":"tempctrl"}' | nc $ip 4028 |jq ."TEMPCTRL"[]."Target")
        if echo '{"command":"tunerstatus"}' | nc $ip 4028 |jq ."TUNERSTATUS"[]."TunerChainStatus"[]."Status" | grep -q "Tuning individual chips"
        then
          tuning=yes
        else
          tuning=no
        fi
        if [[ $tuning == no ]]; then
          if [[ $TARGET_TEMP -lt $MIN_TARGET_TEMP ]]
          then
            echo "Target temp:$TARGET_TEMP less than min change to $MIN_TARGET_TEMP"
            if [[ $1 == apply_all ]] || [[ $1 == apply_hot ]];then
              echo "Applying new target temp"
              "$DIR"/bos-toolbox command $ip -p $PASSWORD "sed -i \"s/target_temp = [0-9][0-9].[0-9]/target_temp = $MIN_TARGET_TEMP/g\" /etc/bosminer.toml && /etc/init.d/bosminer reload"
            fi
          elif [[ $TARGET_TEMP -gt $MAX_TARGET_TEMP ]]
          then
            echo "Target temp:$TARGET_TEMP more than max change to $MAX_TARGET_TEMP"
            if [[ $1 == apply_all ]] || [[ $1 == apply_hot ]];then
              echo "Applying new target temp"
              "$DIR"/bos-toolbox command $ip -p $PASSWORD "sed -i \"s/target_temp = [0-9][0-9].[0-9]/target_temp = $MAX_TARGET_TEMP/g\" /etc/bosminer.toml && /etc/init.d/bosminer reload"
            fi
          elif ! [[ $TARGET_TEMP -lt $MIN_TARGET_TEMP ]] || ! [[ $TARGET_TEMP -gt $MAX_TARGET_TEMP ]]
          then
            if [[ $FAN -gt $HIGH_FAN_SPEED ]] ;then
              echo "$ip Target Temp: $TARGET_TEMP, Fan Speed: $FAN, More Than High $HIGH_FAN_SPEED"

              if [[ $TARGET_TEMP -gt $MIN_TARGET_TEMP ]] && [[ $TARGET_TEMP -lt $MAX_TARGET_TEMP ]]
              then
                NEW_TARGET_TEMP=$((TARGET_TEMP+5))
                if [[ $NEW_TARGET_TEMP -gt $MAX_TARGET_TEMP ]]
                then
                  NEW_TARGET_TEMP=$MAX_TARGET_TEMP
                fi
                echo "Change target temp from $TARGET_TEMP to $NEW_TARGET_TEMP"
                if [[ $1 == apply_all ]] || [[ $1 == apply_hot ]];then
                  echo "Applying new target temp"
                  "$DIR"/bos-toolbox command $ip -p $PASSWORD "sed -i \"s/target_temp = [0-9][0-9].[0-9]/target_temp = $NEW_TARGET_TEMP/g\" /etc/bosminer.toml && /etc/init.d/bosminer reload"
                fi
              fi
            elif [[ $FAN -lt $LOW_FAN_SPEED ]] && [[ $TARGET_TEMP -gt $MIN_TARGET_TEMP ]] ;then
              echo "$ip Target Temp: $TARGET_TEMP, Fan Speed: $FAN, Less Than Low: $LOW_FAN_SPEED"
              if [[ $TARGET_TEMP -gt $MIN_TARGET_TEMP ]]
              then
                echo "Change target temp from $TARGET_TEMP to $MIN_TARGET_TEMP"
                if [[ $1 == apply_all ]] || [[ $1 == apply_cold ]];then
                  echo "Applying new target temp"
                  "$DIR"/bos-toolbox command $ip -p $PASSWORD "sed -i \"s/target_temp = [0-9][0-9].[0-9]/target_temp = $MIN_TARGET_TEMP/g\" /etc/bosminer.toml && /etc/init.d/bosminer reload"
                fi
              fi
            elif [[ $FAN -lt $NORMAL_FAN_SPEED ]] && [[ $TARGET_TEMP -gt $MIN_TARGET_TEMP ]] ;then
              echo "$ip Target Temp: $TARGET_TEMP, Fan Speed: $FAN, Less Than Normal: $NORMAL_FAN_SPEED"
              if [[ $TARGET_TEMP -gt $MIN_TARGET_TEMP ]]
              then
                NEW_TARGET_TEMP=$((TARGET_TEMP-5))
                if [[ $NEW_TARGET_TEMP -lt $MIN_TARGET_TEMP ]]
                then
                  NEW_TARGET_TEMP=$MIN_TARGET_TEMP
                fi
                echo "Target Temp $TARGET_TEMP, Change it to $NEW_TARGET_TEMP"
                if [[ $1 == apply_all ]] || [[ $1 == apply_cold ]];then
                  echo "Applying new target temp"
                  "$DIR"/bos-toolbox command $ip -p $PASSWORD "sed -i 's/target_temp = 75.0/target_temp = 70.0/g' /etc/bosminer.toml && /etc/init.d/bosminer reload"
                fi
              fi
            else
              echo "$ip Target Temp: $TARGET_TEMP, Fan Speed: $FAN"
            fi
          fi
        else
          echo "$ip Target Temp: $TARGET_TEMP, Fan Speed: $FAN, Tuning individual chips"
        fi
      fi
    else
      echo "$ip OFFLINE"
    fi
  done
else
  echo "Ivalid Input, Use: check_temp, apply_all, apply_hot, apply_cold"
fi
