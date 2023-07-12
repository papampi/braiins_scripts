#!/bin/bash

# Set miner username and password
USERNAME="root"
PASSWORD="root"

# Get the IP address from the first command-line argument
ip=$1

# Set the authorization token (replace with your own token)
auth=$(grpcurl -plaintext -vv -d '{"username": "$USERNAME", "password": "$PASSWORD"}' $ip:50051 braiins.bos.v1.AuthenticationService/Login | grep authorization | cut -d":" -f2 )

output=$(grpcurl -plaintext -H "authorization:$auth" "$ip":50051 braiins.bos.v1.TunerService/GetTunerState)
printf "%-15s %-20s %-30s %-15s\n" "Power Target" "Hash Rate TH/s" "Power Consumption" "Efficiency"
while read -r target_watt gigahashPerSecond estimatedPowerConsumption_watt; do
    if [ -n "$gigahashPerSecond" ]; then
        terahashPerSecond=$(echo "scale=1; $gigahashPerSecond /1000 " | bc)
        efficiency=$(echo "scale=4; $estimatedPowerConsumption_watt *1000 / ($gigahashPerSecond )" | bc)
        efficiency=$(printf "%.1f"  $(echo "$efficiency " | bc))
        printf "%-15s %-20s %-30s %-15s\n" "$target_watt" "$terahashPerSecond" "$estimatedPowerConsumption_watt" "$efficiency"
    fi
done < <(echo "$output" | jq -r '.powerTargetProfiles[] | [.target.watt, (.measuredHashrate.gigahashPerSecond | tonumber?), .estimatedPowerConsumption.watt] | @tsv')
