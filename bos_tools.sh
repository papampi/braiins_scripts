#!/bin/bash

#Edit these values:

PASSWORD=root                 # Change your Password if needed
MIN_TARGET_TEMP=70
MAX_TARGET_TEMP=80
LOW_FAN_SPEED=30
HIGH_FAN_SPEED=80
NORMAL_FAN_SPEED=45
NORMAL_POWER=1400


#Set your ip range a.b.c.{d1...d2}
a=192
b=168
c=1
d1=20
d2=101

#############################################################################
##### Do Not Edit Bellow This Line If You Dont Know What You Are Doing"######
#############################################################################

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
d2=$((d2+1))
if [[ $1 == "check_temp" ]] || [[ $1 == "apply_temp" ]] || [[ $1 == "apply_higher_temp" ]] || [[ $1 == "apply_lower_temp" ]] || [[ $1 == "check_power" ]] || [[ $1 == "check_share" ]] || [[ $1 == "share_reload" ]] || [[ $1 == "THS_av" ]] || [[ $1 == "THS_5s" ]] || [[ $1 == "THS_1m" ]] || [[ $1 == "THS_5m" ]] || [[ $1 == "THS_15m" ]] || [[ $1 == "THS_24h" ]] || [[ $1 == "THS_all" ]] || [[ $1 == "efficiency" ]]
then
  for ((i=d1; i<d2; i++))
  do
    ip="$a.$b.$c.$i"

    if fping -c1 -t100 $ip 2>/dev/null 1>/dev/null
    then
      if ! echo '{"command":"version"}' | nc $ip 4028 |jq ."VERSION"[]."BOSminer"  | grep -q bosminer
      then
        echo "$ip no bosminer found"
      else
        SUMMARY=$(echo '{"command":"summary"}' | nc $ip 4028 | jq ."SUMMARY"[])
        TUNERSTATUS=$(echo '{"command":"tunerstatus"}' | nc $ip 4028 | jq ."TUNERSTATUS"[])
        TEMPCTRL=$(echo '{"command":"tempctrl"}' | nc $ip 4028 |jq ."TEMPCTRL"[])
        FANS=$(echo '{"command":"fans"}' | nc $ip 4028 | jq . | jq -r ".FANS"[])
        elapsed_time=$(echo "$SUMMARY" | jq ."Elapsed")

        if echo "$TUNERSTATUS" | jq ."TunerChainStatus"[]."Status" | grep -q "Tuning individual chips"
        then
          tuning_chips=yes
        elif echo "$TUNERSTATUS" | jq ."TunerChainStatus"[]."Status" | grep -q "Testing performance profile"
        then
          testing_profile=yes
        else
          tuning_chips=no
          testing_profile=no
        fi
        if [[ $elapsed_time -lt 180 ]]
        then
          warm_up=yes
        else
          warm_up=no
        fi
        if [[ $1 == "check_temp" ]] || [[ $1 == "apply_temp" ]] || [[ $1 == "apply_higher_temp" ]] || [[ $1 == "apply_lower_temp" ]]
        then
          fan=$(echo "$FANS" | jq -r ."Speed"| head -1)
          target_temp=$(echo "$TEMPCTRL" |jq ."Target")
          if [[ $warm_up == no ]]; then
            if [[ $tuning_chips == no ]] && [[ $testing_profile == no ]]; then
              if [[ $target_temp == 89 ]]
              then
                "$DIR"/bos-toolbox command $ip -p $PASSWORD "sed -i \"s/^target_temp = .*/target_temp = $MAX_TARGET_TEMP/g\" /etc/bosminer.toml"
                "$DIR"/bos-toolbox command $ip -p $PASSWORD "sed -i '/\[temp_control\]/a target_temp = $MAX_TARGET_TEMP' /etc/bosminer.toml "
                "$DIR"/bos-toolbox command $ip -p $PASSWORD " /etc/init.d/bosminer reload"
              fi
              if [[ $target_temp -lt $MIN_TARGET_TEMP ]]
              then
                echo "$ip Target Temp: $target_temp, Fan Speed: $fan, less than min change to $MIN_TARGET_TEMP"
                if [[ $1 == apply_temp ]] || [[ $1 == apply_higher_temp ]];then
                  echo "Applying new target temp $MIN_TARGET_TEMP to $ip"
                  "$DIR"/bos-toolbox command $ip -p $PASSWORD "sed -i \"s/^target_temp = .*/target_temp = $MIN_TARGET_TEMP/g\" /etc/bosminer.toml && /etc/init.d/bosminer reload"
                fi
              elif [[ $target_temp -gt $MAX_TARGET_TEMP ]]
              then
                echo "$ip Target temp:$target_temp more than max change to $MAX_TARGET_TEMP"
                if [[ $1 == apply_temp ]] || [[ $1 == apply_higher_temp ]];then
                  echo "Applying new target temp $MAX_TARGET_TEMP to $ip"
                  "$DIR"/bos-toolbox command $ip -p $PASSWORD "sed -i \"s/^target_temp = .*/target_temp = $MAX_TARGET_TEMP/g\" /etc/bosminer.toml && /etc/init.d/bosminer reload"
                fi
              elif ! [[ $target_temp -lt $MIN_TARGET_TEMP ]] || ! [[ $target_temp -gt $MAX_TARGET_TEMP ]]
              then
                if [[ $fan -gt $HIGH_FAN_SPEED ]] ;then
                  echo "$ip Target Temp: $target_temp, Fan Speed: $fan, More Than High $HIGH_FAN_SPEED"
                  if [[ $target_temp -ge $MIN_TARGET_TEMP ]] && [[ $target_temp -lt $MAX_TARGET_TEMP ]]
                  then
                    NEW_TARGET_TEMP=$((target_temp+5))
                    if [[ $NEW_TARGET_TEMP -gt $MAX_TARGET_TEMP ]]
                    then
                      NEW_TARGET_TEMP=$MAX_TARGET_TEMP
                    fi
                    echo "Change target temp from $target_temp to $NEW_TARGET_TEMP"
                    if [[ $1 == apply_temp ]] || [[ $1 == apply_higher_temp ]];then
                      echo "Applying new target temp $NEW_TARGET_TEMP to $ip"
                      "$DIR"/bos-toolbox command $ip -p $PASSWORD "sed -i \"s/^target_temp = .*/target_temp = $NEW_TARGET_TEMP/g\" /etc/bosminer.toml && /etc/init.d/bosminer reload"
                    fi
                  fi
                elif [[ $fan -lt $LOW_FAN_SPEED ]] && [[ $target_temp -gt $MIN_TARGET_TEMP ]] ;then
                  echo "$ip Target Temp: $target_temp, Fan Speed: $fan, Less Than Low: $LOW_FAN_SPEED"
                  if [[ $target_temp -gt $MIN_TARGET_TEMP ]]
                  then
                    echo "Change target temp from $target_temp to $MIN_TARGET_TEMP"
                    if [[ $1 == apply_temp ]] || [[ $1 == apply_lower_temp ]];then
                      echo "Applying new target temp $NEW_TARGET_TEMP to $ip"
                      "$DIR"/bos-toolbox command $ip -p $PASSWORD "sed -i \"s/^target_temp = .*/target_temp = $MIN_TARGET_TEMP/g\" /etc/bosminer.toml && /etc/init.d/bosminer reload"
                    fi
                  fi
                elif [[ $fan -lt $NORMAL_FAN_SPEED ]] && [[ $target_temp -gt $MIN_TARGET_TEMP ]] ;then
                  echo "$ip Target Temp: $target_temp, Fan Speed: $fan, Less Than Normal: $NORMAL_FAN_SPEED"
                  if [[ $target_temp -gt $MIN_TARGET_TEMP ]]
                  then
                    NEW_TARGET_TEMP=$((target_temp-5))
                    if [[ $NEW_TARGET_TEMP -lt $MIN_TARGET_TEMP ]]
                    then
                      NEW_TARGET_TEMP=$MIN_TARGET_TEMP
                    fi
                    echo "$ip Target Temp $target_temp, Change it to $NEW_TARGET_TEMP"
                    if [[ $1 == apply_temp ]] || [[ $1 == apply_lower_temp ]];then
                      echo "Applying new target temp $NEW_TARGET_TEMP to $ip"
                      "$DIR"/bos-toolbox command $ip -p $PASSWORD "sed -i \"s/^target_temp = .*/target_temp = $NEW_TARGET_TEMP/g\" /etc/bosminer.toml && /etc/init.d/bosminer reload"
                    fi
                  fi
                else
                  echo "$ip Target Temp: $target_temp, Fan Speed: $fan"
                fi
              fi
            elif [[ $tuning_chips == yes ]] ;then
              echo "$ip Target Temp: $target_temp, Fan Speed: $fan, Tuning individual chips"
            elif [[ $testing_profile == yes ]];then
              echo "$ip Target Temp: $target_temp, Fan Speed: $fan, Testing performance profile"
            fi
          else
            echo "$ip Target Temp: $target_temp, Fan Speed: $fan, Miner Warming Up"
          fi
        elif [[ $1 == "check_power" ]]
        then
          powerlimit=$(echo "$TUNERSTATUS" | jq ."PowerLimit")
          powerconsumption=$(echo "$TUNERSTATUS" | jq ."ApproximateMinerPowerConsumption")
          if [[ $powerlimit -lt $NORMAL_POWER ]]
          then
            echo "$ip - Power Limit: $powerlimit - Apprx Power Consumption: $powerconsumption - Low Power "
          else
            echo "$ip - Power Limit: $powerlimit - Apprx Power Consumption: $powerconsumption"
          fi
        elif [[ $1 == "check_share" ]] || [[ $1 == "share_reload" ]]
        then
          accepted_shares=$(echo "$SUMMARY" | jq ."Accepted")
          if [[ $accepted_shares == 0 ]] && [[ $elapsed_time -gt 120 ]]
          then
            echo "$ip Accepted Shares in $elapsed_time seconds is $accepted_shares, Restart miner"
            if [[ $1 == "check_reload" ]]
            then
              "$DIR"/bos-toolbox command $ip -p $PASSWORD "/etc/bosminer.toml && /etc/init.d/bosminer reload"
            fi
          else
            echo "$ip Accepted Shares in $elapsed_time seconds is $accepted_shares"
          fi
        elif [[ $1 == "THS_av" ]] || [[ $1 == "THS_5s" ]] || [[ $1 == "THS_1m" ]] || [[ $1 == "THS_5m" ]] || [[ $1 == "THS_15m" ]] || [[ $1 == "THS_24h" ]] || [[ $1 == "THS_all" ]]
        then
          MHS_av=$(echo "$SUMMARY" | jq '."MHS av"')
          THS_av=$(echo "scale=2;$MHS_av/1000000" | bc )
          MHS_5s=$(echo "$SUMMARY" | jq '."MHS 5s"')
          THS_5s=$(echo "scale=2;$MHS_5s/1000000" | bc )
          MHS_1m=$(echo "$SUMMARY" | jq '."MHS 1m"')
          THS_1m=$(echo "scale=2;$MHS_1m/1000000" | bc )
          MHS_5m=$(echo "$SUMMARY" | jq '."MHS 5m"')
          THS_5m=$(echo "scale=2;$MHS_5m/1000000" | bc )
          MHS_15m=$(echo "$SUMMARY" | jq '."MHS 15m"')
          THS_15m=$(echo "scale=2;$MHS_15m/1000000" | bc )
          MHS_24h=$(echo "$SUMMARY" | jq '."MHS 24h"')
          THS_24h=$(echo "scale=2;$MHS_24h/1000000" | bc )
          if [[ $1 == "THS_av" ]]
          then
            echo "$ip,  $THS_av"
          elif [[ $1 == "THS_5s" ]]
          then
            echo "$ip,  $THS_5s"
          elif [[ $1 == "THS_1m" ]]
          then
            echo "$ip,  $THS_1m"
          elif [[ $1 == "THS_5m" ]]
          then
            echo "$ip,  $THS_5m"
          elif [[ $1 == "THS_15m" ]]
          then
            echo "$ip,  $THS_15m"
          elif [[ $1 == "THS_24h" ]]
          then
            echo "$ip,  $THS_24h"
          elif [[ $1 == "THS_all" ]]
          then
            echo "$ip, THS_av: $THS_av | THS_5s: $THS_5s | THS_1m: $THS_1m | THS_5m: $THS_5m | THS_15m: $THS_15m | THS_24h: $THS_24h"
          fi
        elif [[ $1 == "efficiency" ]]
        then
          powerconsumption=$(echo "$TUNERSTATUS" | jq ."ApproximateMinerPowerConsumption")
          MHS_av=$(echo "$SUMMARY" | jq '."MHS av"')
          THS_av=$(echo "scale=2;$MHS_av/1000000" | bc )
          MHS_24h=$(echo "$SUMMARY" | jq '."MHS 24h"')
          THS_24h=$(echo "scale=2;$MHS_24h/1000000" | bc )
          JperTH_24=$(echo "scale=2;$powerconsumption/$THS_24h" | bc )
          JperTH_av=$(echo "scale=2;$powerconsumption/$THS_av" | bc )
          echo "$ip, Power: $powerconsumption, TH/s_24h: $THS_24h,  J/TH/24: $JperTH_24, TH/s_av: $THS_av, J/TH/AV: $JperTH_av"
        fi
      fi
    else
      echo "$ip - No Miner Found"
    fi
  done
else
  echo "Ivalid Input, Use: check_temp, apply_temp, apply_higher_temp, apply_lower_temp, check_share, share_reload, check_power, THS_av, THS_5s, THS_1m, THS_5m, THS_15m, THS_24h, THS_all, efficiency"
  echo " Usage:"
fi
