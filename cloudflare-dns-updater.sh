#!/bin/bash

# CHANGE THESE
declare -A EMAILKEY=(
  # Login email and Global API key
  # [auth_email]=auth_key
)

declare -A RECORDEMAIL=(
  # [domain]=auth_email
)

declare -A RECORDZONE=(
  # [record_name]=zone_identifier
)

ip=$(curl -s https://ipv4.icanhazip.com/)

for record_name in "${!RECORDZONE[@]}"
do
  # Get all the required values from associative arrays
  zone_identifier=${RECORDZONE[$record_name]}
  auth_email=${RECORDEMAIL[$record_name]}
  auth_key=${EMAILKEY[$auth_email]}
  echo "[Cloudflare DDNS] Check Initiated for $record_name"

  # Seek for the record
  record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?name=$record_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json")

  # Can't do anything without the record
  if [[ $record == *"\"count\":0"* ]]; then
    >&2 echo -e "[Cloudflare DDNS] Record does not exist, perhaps create one first?"
    continue
  fi

  # Set existing IP address from the fetched record
  old_ip=$(echo "$record" | grep -Po '(?<="content":")[^"]*' | head -1)

  # Compare if they're the same
  if [ $ip == $old_ip ]; then
    echo "[Cloudflare DDNS] IP for $record_name has not changed."
    continue
  fi

  # Set the record identifier from result
  echo "[Cloudflare DDNS] Old IP was $old_ip, trying to set new IP $ip"
  record_identifier=$(echo "$record" | grep -Po '(?<="id":")[^"]*' | head -1)

  # Execute update
  update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" --data "{\"id\":\"$zone_identifier\",\"type\":\"A\",\"proxied\":true,\"name\":\"$record_name\",\"content\":\"$ip\"}")

  case "$update" in
  *"\"success\":false"*)
    >&2 echo -e "[Cloudflare DDNS] Update failed for $record_identifier. IP is still $old_ip. DUMPING RESULTS:\n$update"
    continue;;
  *)
    echo "[Cloudflare DDNS] IPv4 context '$ip' for $record_name has been synced to Cloudflare.";;
  esac

done
