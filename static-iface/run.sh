#!/usr/bin/env bash
#
# static-iface/run.sh - Configure static IPv4+IPv6 on Hetzner dedicated servers
#
# Environment variables:
#   ENABLED  - Must be true/1/y/yes/on to run (required)
#   VERBOSE  - Enable debug output (optional)
#   PERSIST  - Persist config to boot partition (optional, default: false)
#
# Phases:
#   0: Early checks (ENABLED flag, verbose mode)
#   1: Interface discovery + Hetzner check (bail if not Hetzner)
#   2: Fetch metadata from Hetzner Robot API (/server + /ip endpoints)
#   3: Apply static IPv4+IPv6 config via nmcli
#   4: Verify network connectivity (gateway, internet, DNS)
#   5: Persist validated config to /mnt/boot (if PERSIST=true)
#
# Exit codes:
#   0 = Success (configured or not Hetzner)
#   1 = Error (network tests failed, API unreachable, etc.)

set -euo pipefail

# =============================================================================
# Phase 0: Early checks
# =============================================================================

is_truthy() {
	case ${1,,} in
	true | 1 | y | yes | on) return 0 ;;
	*) return 1 ;;
	esac
}

is_truthy "${ENABLED:-}" || exit 0
is_truthy "${VERBOSE:-}" && set -x
is_truthy "${PERSIST:-}" && persist_enabled=true || persist_enabled=false

# =============================================================================
# Constants and configuration
# =============================================================================

host_conn_dir="/etc/NetworkManager/system-connections"
boot_conn_dir="/mnt/boot/system-connections"
dns_ipv4="1.1.1.1,1.0.0.1" # Cloudflare
dns_ipv6="2606:4700:4700::1111,2606:4700:4700::1001" # Cloudflare
ipv6_gateway="fe80::1"

# =============================================================================
# Utility functions
# =============================================================================

log() {
	echo "[static-iface] $*"
}

die() {
	echo "[static-iface] ERROR: $*" >&2
	exit 1
}

curl_with_opts() {
	curl --fail --silent --show-error --retry 3 --connect-timeout 3 --compressed "$@"
}

get_robot() {
	curl_with_opts -u "${ROBOT_USER}:${ROBOT_PASS}" "${ROBOT_API}"
}

# Run a network test with logging
run_test() {
	local name="$1"
	shift
	log "Testing ${name}..."
	if "$@" >/dev/null 2>&1; then
		log "  [ok] ${name}"
		return 0
	fi
	log "  [FAILED] ${name}"
	return 1
}

# =============================================================================
# Host filesystem access (via docker)
# =============================================================================

# Copy a file between host paths using docker (balenaOS doesn't allow direct mounts)
host_copy() {
	local _src="$1"
	local _dest="$2"
	local _src_dir _dest_dir
	_src_dir=$(dirname "${_src}")
	_dest_dir=$(dirname "${_dest}")

	docker run --rm \
		-v "${_src_dir}":"${_src_dir}:ro" \
		-v "${_dest_dir}":"${_dest_dir}" \
		alpine:3.22 sh -c "mkdir -p '${_dest_dir}' && cp '${_src}' '${_dest}' && chmod 600 '${_dest}'"
}

# =============================================================================
# Phase 1: Interface discovery
# =============================================================================

# Discover the active network interface and connection
iface=$(ip route show default | awk '/default/ {print $5; exit}')
if [[ -z "${iface}" ]]; then
	die "Could not determine default network interface"
fi

conn=$(nmcli -t -f NAME,DEVICE con show --active | awk -F: -v iface="${iface}" '$2 == iface {print $1}')
if [[ -z "${conn}" ]]; then
	die "Could not determine NetworkManager connection for interface ${iface}"
fi

log "Detected interface: ${iface}, connection: ${conn}"

# =============================================================================
# Phase 2: Fetch metadata from Hetzner Robot API
# =============================================================================

log "Fetching current public IP..."
my_ip=$(curl_with_opts https://ipinfo.io/ip) || die "Failed to fetch public IP from ipinfo.io"
log "Current public IP: ${my_ip}"

log "Querying Hetzner Robot API for server metadata..."
robot_json=$(get_robot) || die "Failed to query Hetzner Robot API"

# Find this server in the Robot API response
server_json=$(echo "${robot_json}" | jq -rc --arg ip "${my_ip}" '.[].server | select(.server_ip==$ip)')
if [[ -z "${server_json}" ]]; then
	log "Server IP ${my_ip} not found in Hetzner Robot API - not a Hetzner server or different provider"
	exit 0
fi

server_ip=$(echo "${server_json}" | jq -r '.server_ip')
server_number=$(echo "${server_json}" | jq -r '.server_number')
log "Found Hetzner server: #${server_number} (${server_ip})"

# Get IPv6 details from /server endpoint
ipv6_addr=$(echo "${server_json}" | jq -r '.subnet[0].ip')
ipv6_mask=$(echo "${server_json}" | jq -r '.subnet[0].mask')

if [[ -z "${ipv6_addr}" || "${ipv6_addr}" == "null" ]]; then
	log "Warning: No IPv6 subnet found for this server"
	ipv6_addr=""
fi

# Query /ip endpoint for IPv4 gateway and mask details
log "Fetching IPv4 details from Hetzner Robot /ip endpoint..."
robot_api_base="${ROBOT_API%/server}"
ip_json=$(curl_with_opts -u "${ROBOT_USER}:${ROBOT_PASS}" "${robot_api_base}/ip/${server_ip}") ||
	die "Failed to fetch IP details from Robot API"

ipv4_addr=$(echo "${ip_json}" | jq -r '.ip.ip')
ipv4_gw=$(echo "${ip_json}" | jq -r '.ip.gateway')
ipv4_mask=$(echo "${ip_json}" | jq -r '.ip.mask')

[[ -z "${ipv4_addr}" || "${ipv4_addr}" == "null" ]] && die "Could not retrieve IPv4 address from Robot API"
[[ -z "${ipv4_gw}" || "${ipv4_gw}" == "null" ]] && die "Could not retrieve IPv4 gateway from Robot API"

# =============================================================================
# Phase 3: Apply static configuration
# =============================================================================

log "Applying static configuration:"
log "  IPv4: ${ipv4_addr}/${ipv4_mask}, GW: ${ipv4_gw}, DNS: ${dns_ipv4}"
if [[ -n "${ipv6_addr}" ]]; then
	log "  IPv6: ${ipv6_addr}/${ipv6_mask}, GW: ${ipv6_gateway}, DNS: ${dns_ipv6}"
fi

# Apply IPv4 configuration
nmcli con mod "${conn}" \
	ipv4.method manual \
	ipv4.addresses "${ipv4_addr}/${ipv4_mask}" \
	ipv4.gateway "${ipv4_gw}" \
	ipv4.dns "${dns_ipv4}"

# Apply IPv6 configuration if available
if [[ -n "${ipv6_addr}" ]]; then
	nmcli con mod "${conn}" \
		ipv6.method manual \
		ipv6.addresses "${ipv6_addr}/${ipv6_mask}" \
		ipv6.gateway "${ipv6_gateway}" \
		ipv6.dns "${dns_ipv6}"
fi

log "Activating connection..."
nmcli con up "${conn}"

# =============================================================================
# Phase 4: Verify network connectivity
# =============================================================================

log "Verifying network connectivity..."
tests_passed=true

# IPv4 tests
run_test "IPv4 gateway ping" ping -c 2 -W 3 "${ipv4_gw}" || tests_passed=false
run_test "IPv4 internet ping" ping -c 2 -W 3 8.8.8.8 || tests_passed=false
run_test "IPv4 DNS resolution" host -4 -W 3 google.com "${dns_ipv4%%,*}" || tests_passed=false

# IPv6 tests (if configured)
if [[ -n "${ipv6_addr}" ]]; then
	run_test "IPv6 internet ping" ping6 -c 2 -W 3 2606:4700:4700::1111 || tests_passed=false
	run_test "IPv6 DNS resolution" host -6 -W 3 google.com "${dns_ipv6%%,*}" || tests_passed=false
fi

if [[ "${tests_passed}" != "true" ]]; then
	die "Network verification failed after applying static config - reboot to restore settings"
fi

log "All network tests passed"

# =============================================================================
# Phase 5: Persist configuration to boot partition (optional)
# =============================================================================

conn_file="${host_conn_dir}/${conn}.nmconnection"
boot_file="${boot_conn_dir}/${conn}.nmconnection"

if "${persist_enabled}"; then
	log "Persisting configuration to ${boot_file}"
	host_copy "${conn_file}" "${boot_file}" ||
		log "Warning: Failed to persist - config will need to be reapplied after reboot"
else
	log "Persistence disabled (set PERSIST=true to enable)"
fi

log "Static IP configuration complete"
log "  IPv4: ${ipv4_addr}/${ipv4_mask}, GW: ${ipv4_gw}, DNS: ${dns_ipv4}"
if [[ -n "${ipv6_addr}" ]]; then
	log "  IPv6: ${ipv6_addr}/${ipv6_mask}, GW: ${ipv6_gateway}, DNS: ${dns_ipv6}"
fi
