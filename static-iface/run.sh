#!/usr/bin/env bash

set -eu

[[ "${VERBOSE:-false}" =~ on|On|Yes|yes|true|True ]] && set -x

[[ $ENABLED == 'true' ]] || exit

curl_with_opts() {
	curl --fail --silent --retry 3 --connect-timeout 3 --compressed "$@"
}

function get_robot() {
	local robot_json
	robot_json="$(curl_with_opts -u "${ROBOT_USER}:${ROBOT_PASS}" "${ROBOT_API}")"
	echo "${robot_json}"
}

which curl || apk add curl --no-cache
which jq || apk add jq --no-cache
which nmcli || apk add networkmanager --no-cache

myip="$(curl_with_opts https://ipinfo.io/ip)"
flat_json="$(get_robot | jq -rc --arg ip "${myip}" '.[].server | select(.server_ip==$ip)')"
ipv6_addresses="$(nmcli -f ipv6.addresses c s 'Wired connection 1' | awk '{print $2}')"

if [[ -z $ipv6_addresses ]] || [[ $ipv6_addresses == '--' ]]; then
	ip="$(echo "${flat_json}" | jq -r '.subnet[].ip')"
	mask="$(echo "${flat_json}" | jq -r '.subnet[].mask')"
	ipv6_addresses="${ip}/${mask}"
	nmcli connection modify 'Wired connection 1' ipv6.addresses "${ipv6_addresses}"
	nmcli connection modify 'Wired connection 1' ipv6.gateway fe80::1
	nmcli connection modify 'Wired connection 1' ipv6.dns '2001:4860:4860::8888 2001:4860:4860::8844'
	nmcli connection modify 'Wired connection 1' ipv6.method manual
	nmcli connection up 'Wired connection 1'
fi
