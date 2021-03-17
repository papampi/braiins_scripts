#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
PASSWORD=xxxxxx
MIN_TARGET_TEMP=70
MAX_TARGET_TEMP=85
LOW_FAN_SPEED=40
HIGH_FAN_SPEED=75
NORMAL_FAN_SPEED=50
NORMAL_POWER=1400
#ip range a.b.c.{d1...d2}
a=192
b=168
c=1
d1=20
d2=101

d2=$((d2+1))
if [[ $1 == "check_temp" ]] || [[ $1 == "apply_temp" ]] || [[ $1 == "apply_hot" ]] || [[ $1 == "apply_cold" ]]
then
for ((i=$d1; i<$d2; i++))
  do
    ip="$a.$b.$c.$i"
    fping -c1 -t100 $ip 2>/dev/null 1>/dev/null
    if [ "$?" = 0 ]
    then
      if ! echo '{"command":"version"}' | nc $ip 4028 |jq ."VERSION"[]."BOSminer"  | grep -q bosminer
      then
        echo "$ip no bosminer found"
      else
        FAN=$(echo '{"command":"fans"}' | nc $ip 4028 | jq . | jq -r ".FANS"[]."Speed"| head -1)
        TARGET_TEMP=$(echo '{"command":"tempctrl"}' | nc $ip 4028 |jq ."TEMPCTRL"[]."Target")

        elapsed_time=$(echo '{"command":"summary"}' | nc $ip 4028 | jq ."SUMMARY"[]."Elapsed")

        if echo '{"command":"tunerstatus"}' | nc $ip 4028 |jq ."TUNERSTATUS"[]."TunerChainStatus"[]."Status" | grep -q "Tuning individual chips"
        then
          tuning_chips=yes
        elif echo '{"command":"tunerstatus"}' | nc $ip 4028 |jq ."TUNERSTATUS"[]."TunerChainStatus"[]."Status" | grep -q "Testing performance profile"
        then
          testing_profile=yes
        else
          tuning_chips=no
          testing_profile=no
        fi

        if [[ $elapsed_time -lt 120 ]]
        then
          warm_up=yes
        else
          warm_up=no
        fi

        if [[ $TARGET_TEMP =~ ^[+-]?[0-9]+$ ]]; then
        #echo "Input is an integer."
          TARGET_TEMP_FORMAT=integer
        elif [[ $TARGET_TEMP =~ ^[+-]?[0-9]+\.$ ]]; then
        #echo "Input is a string."
          TARGET_TEMP_FORMAT=string
        elif [[ $TARGET_TEMP =~ ^[+-]?[0-9]+\.?[0-9]*$ ]]; then
          TARGET_TEMP_FORMAT=float
        #echo "Input is a float."
        fi

        if [[ $warm_up == no ]]; then
          if [[ $tuning_chips == no ]] && [[ $testing_profile == no ]]; then
            if [[ $TARGET_TEMP -lt $MIN_TARGET_TEMP ]]
            then
              echo "$ip Target Temp: $TARGET_TEMP, Fan Speed: $FAN, less than min change to $MIN_TARGET_TEMP"
              if [[ $1 == apply_temp ]] || [[ $1 == apply_hot ]];then
                echo "Applying new target temp $MIN_TARGET_TEMP to $ip"
                if [[ $TARGET_TEMP_FORMAT == float ]];then
                  "$DIR"/bos-toolbox command $ip -p $PASSWORD "sed -i \"s/target_temp = [0-9][0-9].[0-9]/target_temp = $MIN_TARGET_TEMP/g\" /etc/bosminer.toml && /etc/init.d/bosminer reload"
                elif [[ $TARGET_TEMP_FORMAT == integer ]];then
                  "$DIR"/bos-toolbox command $ip -p $PASSWORD "sed -i \"s/target_temp = [0-9][0-9]/target_temp = $MIN_TARGET_TEMP/g\" /etc/bosminer.toml && /etc/init.d/bosminer reload"
                fi
              fi
            elif [[ $TARGET_TEMP -gt $MAX_TARGET_TEMP ]]
            then
              echo "$ip Target temp:$TARGET_TEMP more than max change to $MAX_TARGET_TEMP"
              if [[ $1 == apply_temp ]] || [[ $1 == apply_hot ]];then
                echo "Applying new target temp $MAX_TARGET_TEMP to $ip"
                if [[ $TARGET_TEMP_FORMAT == float ]];then
                  "$DIR"/bos-toolbox command $ip -p $PASSWORD "sed -i \"s/target_temp = [0-9][0-9].[0-9]/target_temp = $MAX_TARGET_TEMP/g\" /etc/bosminer.toml && /etc/init.d/bosminer reload"
                elif [[ $TARGET_TEMP_FORMAT == integer ]];then
                  "$DIR"/bos-toolbox command $ip -p $PASSWORD "sed -i \"s/target_temp = [0-9][0-9]/target_temp = $MAX_TARGET_TEMP/g\" /etc/bosminer.toml && /etc/init.d/bosminer reload"
                fi
              fi
            elif ! [[ $TARGET_TEMP -lt $MIN_TARGET_TEMP ]] || ! [[ $TARGET_TEMP -gt $MAX_TARGET_TEMP ]]
            then
              if [[ $FAN -gt $HIGH_FAN_SPEED ]] ;then
                echo "$ip Target Temp: $TARGET_TEMP, Fan Speed: $FAN, More Than High $HIGH_FAN_SPEED"

                if [[ $TARGET_TEMP -ge $MIN_TARGET_TEMP ]] && [[ $TARGET_TEMP -lt $MAX_TARGET_TEMP ]]
                then
                  NEW_TARGET_TEMP=$((TARGET_TEMP+5))
                  if [[ $NEW_TARGET_TEMP -gt $MAX_TARGET_TEMP ]]
                  then
                    NEW_TARGET_TEMP=$MAX_TARGET_TEMP
                  fi
                  echo "Change target temp from $TARGET_TEMP to $NEW_TARGET_TEMP"
                  if [[ $1 == apply_temp ]] || [[ $1 == apply_hot ]];then
                    echo "Applying new target temp $NEW_TARGET_TEMP to $ip"

                    if [[ $TARGET_TEMP_FORMAT == float ]];then
                      "$DIR"/bos-toolbox command $ip -p $PASSWORD "sed -i \"s/target_temp = [0-9][0-9].[0-9]/target_temp = $NEW_TARGET_TEMP/g\" /etc/bosminer.toml && /etc/init.d/bosminer reload"
                    elif [[ $TARGET_TEMP_FORMAT == integer ]];then
                      "$DIR"/bos-toolbox command $ip -p $PASSWORD "sed -i \"s/target_temp = [0-9][0-9]/target_temp = $NEW_TARGET_TEMP/g\" /etc/bosminer.toml && /etc/init.d/bosminer reload"
                    fi

                  fi
                fi
              elif [[ $FAN -lt $LOW_FAN_SPEED ]] && [[ $TARGET_TEMP -gt $MIN_TARGET_TEMP ]] ;then
                echo "$ip Target Temp: $TARGET_TEMP, Fan Speed: $FAN, Less Than Low: $LOW_FAN_SPEED"
                if [[ $TARGET_TEMP -gt $MIN_TARGET_TEMP ]]
                then
                  echo "Change target temp from $TARGET_TEMP to $MIN_TARGET_TEMP"
                  if [[ $1 == apply_temp ]] || [[ $1 == apply_cold ]];then
                    echo "Applying new target temp $NEW_TARGET_TEMP to $ip"
                    if [[ $TARGET_TEMP_FORMAT == float ]];then
                      "$DIR"/bos-toolbox command $ip -p $PASSWORD "sed -i \"s/target_temp = [0-9][0-9].[0-9]/target_temp = $MIN_TARGET_TEMP/g\" /etc/bosminer.toml && /etc/init.d/bosminer reload"
                    elif [[ $TARGET_TEMP_FORMAT == integer ]];then
                      "$DIR"/bos-toolbox command $ip -p $PASSWORD "sed -i \"s/target_temp = [0-9][0-9]/target_temp = $MIN_TARGET_TEMP/g\" /etc/bosminer.toml && /etc/init.d/bosminer reload"
                    fi
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
                  echo "$ip Target Temp $TARGET_TEMP, Change it to $NEW_TARGET_TEMP"
                  if [[ $1 == apply_temp ]] || [[ $1 == apply_cold ]];then
                    echo "Applying new target temp $NEW_TARGET_TEMP to $ip"
                    if [[ $TARGET_TEMP_FORMAT == float ]];then
                      "$DIR"/bos-toolbox command $ip -p $PASSWORD "sed -i \"s/target_temp = [0-9][0-9].[0-9]/target_temp = $NEW_TARGET_TEMP/g\" /etc/bosminer.toml && /etc/init.d/bosminer reload"
                    elif [[ $TARGET_TEMP_FORMAT == integer ]];then
                      "$DIR"/bos-toolbox command $ip -p $PASSWORD "sed -i \"s/target_temp = [0-9][0-9]/target_temp = $NEW_TARGET_TEMP/g\" /etc/bosminer.toml && /etc/init.d/bosminer reload"
                    fi
                  fi
                fi
              else
                echo "$ip Target Temp: $TARGET_TEMP, Fan Speed: $FAN"
              fi
            fi
          elif [[ $tuning_chips == yes ]] ;then
            echo "$ip Target Temp: $TARGET_TEMP, Fan Speed: $FAN, Tuning individual chips"
          elif [[ $testing_profile == yes ]];then
            echo "$ip Target Temp: $TARGET_TEMP, Fan Speed: $FAN, Testing performance profile"
          fi
        else
          echo "$ip Target Temp: $TARGET_TEMP, Fan Speed: $FAN, Miner Warming Up"
        fi
      fi
    else
      echo "$ip No Miner"
    fi
  done

elif [[ $1 == "check_power" ]]
then
for ((i=$d1; i<$d2; i++))
  do
    ip="$a.$b.$c.$i"
    fping -c1 -t100 $ip 2>/dev/null 1>/dev/null
    if [ "$?" = 0 ]
    then
      if ! echo '{"command":"version"}' | nc $ip 4028 |jq ."VERSION"[]."BOSminer"  | grep -q bosminer
      then
        echo "$ip no bosminer found"
      else
        tunerstatus=$(echo '{"command":"tunerstatus"}' | nc $ip 4028 | jq ."TUNERSTATUS"[])      
        powerlimit=$(echo $tunerstatus | jq ."PowerLimit")
        powerconsumption=$(   echo $tunerstatus | jq ."ApproximateMinerPowerConsumption")
        if [[ $powerlimit -lt $NORMAL_POWER ]]
        then
          echo "$ip - Power Limit: $powerlimit - Apprx Power Consumption: $powerconsumption - Low Power "
        else
          echo "$ip - Power Limit: $powerlimit - Apprx Power Consumption: $powerconsumption"
        fi
      fi
    else
      echo "$ip No Miner"
    fi
  done

elif [[ $1 == "check_share" ]] || [[ $1 == "share_reload" ]]
then
for ((i=$d1; i<$d2; i++))
  do
    ip="$a.$b.$c.$i"
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
          echo "$ip Accepted Shares in $elapsed seconds is $accepted_shares, Restart miner"
          if [[ $1 == "check_reload" ]]
          then
            "$DIR"/bos-toolbox command $ip -p $PASSWORD "/etc/bosminer.toml && /etc/init.d/bosminer reload"
          fi
        else
          echo "$ip Accepted Shares in $elapsed seconds is $accepted_shares"
        fi
      fi
    else
      echo "$ip No Miner"
    fi
  done

elif [[ $1 == "MHS_av" ]] || [[ $1 == "MHS_5s" ]] || [[ $1 == "MHS_1m" ]] || [[ $1 == "MHS_5m" ]] || [[ $1 == "MHS_15m" ]] || [[ $1 == "MHS_24h" ]] || [[ $1 == "MHS_all" ]]
then
for ((i=$d1; i<$d2; i++))
  do
    ip="$a.$b.$c.$i"
    fping -c1 -t100 $ip 2>/dev/null 1>/dev/null
    if [ "$?" = 0 ]
    then
      if ! echo '{"command":"version"}' | nc $ip 4028 |jq ."VERSION"[]."BOSminer"  | grep -q bosminer
      then
        echo "$ip no bosminer found"
      else
        summary=$(echo '{"command":"summary"}' | nc $ip 4028 | jq ."SUMMARY"[])
        MHS_av=$(echo $summary | jq '."MHS av"')
        MHS_av=$(echo "scale=2;$MHS_av/1000000" | bc )
        MHS_5s=$(echo $summary | jq '."MHS 5s"')
        MHS_5s=$(echo "scale=2;$MHS_5s/1000000" | bc )
        MHS_1m=$(echo $summary | jq '."MHS 1m"')
        MHS_1m=$(echo "scale=2;$MHS_1m/1000000" | bc )
        MHS_5m=$(echo $summary | jq '."MHS 5m"')
        MHS_5m=$(echo "scale=2;$MHS_5m/1000000" | bc )
        MHS_15m=$(echo $summary | jq '."MHS 15m"')
        MHS_15m=$(echo "scale=2;$MHS_15m/1000000" | bc )
        MHS_24h=$(echo $summary | jq '."MHS 24h"')
        MHS_24h=$(echo "scale=2;$MHS_24h/1000000" | bc )

        if [[ $1 == "MHS_av" ]]
        then
          echo "$ip,  $MHS_av"
        elif [[ $1 == "MHS_5s" ]]
        then
          echo "$ip,  $MHS_5s"
        elif [[ $1 == "MHS_1m" ]]
        then
          echo "$ip,  $MHS_1m"
        elif [[ $1 == "MHS_5m" ]]
        then
          echo "$ip,  $MHS_5m"
        elif [[ $1 == "MHS_15m" ]]
        then
          echo "$ip,  $MHS_15m"
        elif [[ $1 == "MHS_24h" ]]
        then
          echo "$ip,  $MHS_24h"
        elif [[ $1 == "MHS_all" ]]
        then
          echo "$ip, MHS_av: $MHS_av | MHS_5s: $MHS_5s | MHS_1m: $MHS_1m | MHS_5m: $MHS_5m | MHS_15m: $MHS_15m | MHS_24h: $MHS_24h"
        fi
      fi
    else
      echo "$ip OFFLINE"
    fi
  done

else
  echo "Ivalid Input, Use: check_temp, apply_temp, apply_hot, apply_cold, check_share, share_reload, check_power, MHS_av, MHS_5s, MHS_1m, MHS_5m, MHS_15m, MHS_24h, MHS_all"
  echo " Usage:"



fi
