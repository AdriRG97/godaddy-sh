#!/bin/bash -e

key="$GODADDY_API_KEY"
secret="$GODADDY_API_SECRET"
records=()
ttl=600

if ! command -v jq &>/dev/null; then
  echo '[Error] jq utility is required. Install it via apt'
  exit 2
fi

while getopts ':gsdD:T:t:n:r:k:S:' opt; do
  case $opt in
    g) method="GET";;
    s) method="PUT";;
    d) method="DELETE";;
    D) domain="${OPTARG}";;
    T) type="${OPTARG}";;
    t) ttl="${OPTARG}";;
    n) name="${OPTARG}";;
    r) records+=("${OPTARG}");;
    k) key="${OPTARG}";;
    S) secret="${OPTARG}";;
    :)
      echo "[Error] Option ${OPTARG} requires an argument"
      exit 1
      ;;
    *)
      echo "[Warning] Unknown option ${OPTARG}"
      ;;
  esac
done

if [ -z $method ]; then
  echo "[Error] Action is required (-g, -s, -d)"
  exit 1
fi

if [ -z "$domain" ]; then
  echo "[Error] Domain is required (-D)"
  exit 1
fi

if [ -z "$key" ] || [ -z "$secret" ]; then
  echo "[Error] Auth is required (-k, GODADDY_API_KEY env, -S, GODADDY_API_SECRET env)"
  exit 1
fi

if [ $method != 'GET' ] && { [ -z "$name" ] || [ -z "$type" ]; }; then
  echo '[Error] Record name and type are required (-n, -T)'
  exit 1
fi

if [ $method == 'GET' ] && [ -n "$name" ] && [ -z "$type" ]; then
  echo '[Error] In get mode, record type is required if name is set (-T)'
  exit 1
fi

if [ $method == 'PUT' ] && [ ${#records[@]} -eq 0 ]; then
  echo '[Error] Record ips are required (-r)'
  exit 1
fi

base_url="https://api.godaddy.com"
query="v1/domains/$domain/records${type:+/}${type}${name:+/}${name}"

if [ $method == 'PUT' ]; then
  data=$(
    for ip in "${records[@]}"; do
      jq -n --arg ip "$ip" --argjson ttl "$ttl" '{data: $ip, ttl: $ttl}'
    done | jq -n '. |= [inputs]'
  )
fi

curl -s -X "$method" -H "Content-Type: application/json" -H "Authorization: sso-key ${key}:${secret}" ${data:+-d "$data"} "${base_url}/${query}" | jq

