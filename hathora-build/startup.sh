#!/usr/bin/env bash

# Use awk to round the cpu to an int
HATHORA_ALLOCATED_CPU_ROUND=$(echo ${HATHORA_ALLOCATED_CPU} | awk '{ x = $1; print sprintf("%.f", x) }')

# use awk to divide memory by 1000 and truncate to an int
HATHORA_ALLOCATED_MEMORY_GB=$(echo ${HATHORA_ALLOCATED_MEMORY_MB} | awk '{ x = $1; print int(x / 1000) }')

echo "Running wineboot --init"

WINEPREFIX=/home/user/.wine WINEARCH=win64 wineboot --init

echo "Starting and HordeAgent with UBA port ${HATHORA_UBA_PORT}"

pushd HordeAgent

if [ -z "${HATHORA_HOSTNAME}" ]; then
  echo "No HATHORA_HOSTNAME found in environment; using default ComputeIp"
else
  LISTEN_IP=$(host -4 ${HATHORA_HOSTNAME} | awk '{print $NF}')
  jq ".Horde.ComputeIp = \"${LISTEN_IP}\"" appsettings.json > appsettings.json.tmp && mv appsettings.json.tmp appsettings.json
fi

# check if COMPUTE_IP_OVERRIDE is set
if [ -n "${COMPUTE_IP_OVERRIDE}" ]; then
  echo "COMPUTE_IP_OVERRIDE is set to ${COMPUTE_IP_OVERRIDE}"
  jq ".Horde.ComputeIp = \"${COMPUTE_IP_OVERRIDE}\"" appsettings.json > appsettings.json.tmp && mv appsettings.json.tmp appsettings.json
fi

jq ".Horde.Name = \"HATHORA-${HATHORA_PROCESS_ID}\"" appsettings.json > appsettings.json.tmp && mv appsettings.json.tmp appsettings.json
jq ".Horde.ComputePort = ${HORDE_COMPUTE_LISTEN_PORT}" appsettings.json > appsettings.json.tmp && mv appsettings.json.tmp appsettings.json
jq '.Horde.wineExecutablePath = "/usr/bin/uba-wine64.sh"' appsettings.json > appsettings.json.tmp && mv appsettings.json.tmp appsettings.json
jq '.Horde.Ephemeral = true' appsettings.json > appsettings.json.tmp && mv appsettings.json.tmp appsettings.json
jq ".Horde.Properties.ExposedComputePort = ${HATHORA_DEFAULT_PORT}" appsettings.json > appsettings.json.tmp && mv appsettings.json.tmp appsettings.json
jq ".Horde.Properties.UbaPort = ${HORDE_UBA_LISTEN_PORT}" appsettings.json > appsettings.json.tmp && mv appsettings.json.tmp appsettings.json
jq ".Horde.Properties.ExposedUbaPort = ${HATHORA_UBA_PORT}" appsettings.json > appsettings.json.tmp && mv appsettings.json.tmp appsettings.json
jq ".Horde.Properties.UbaProxyPort = ${HORDE_UBA_PROXY_LISTEN_PORT}" appsettings.json > appsettings.json.tmp && mv appsettings.json.tmp appsettings.json
jq ".Horde.Properties.ExposedUbaProxyPort = ${HATHORA_PROXY_PORT}" appsettings.json > appsettings.json.tmp && mv appsettings.json.tmp appsettings.json
jq ".Horde.Properties.HordePoolName = \"${HORDE_POOL_NAME}\"" appsettings.json > appsettings.json.tmp && mv appsettings.json.tmp appsettings.json

if [ -z "${DISABLE_RESOURCE_OVERRIDE}" ]; then
  # if 5.6
  # jq ".Horde.CpuCount = \"${HATHORA_ALLOCATED_CPU_ROUND}\"" appsettings.json > appsettings.json.tmp && mv appsettings.json.tmp appsettings.json
  # jq ".Horde.CpuMultiplier = 1" appsettings.json > appsettings.json.tmp && mv appsettings.json.tmp appsettings.json
  # jq ".Horde.RamGb = \"${HATHORA_ALLOCATED_MEMORY_GB}\"" appsettings.json > appsettings.json.tmp && mv appsettings.json.tmp appsettings.json
  # else
  jq ".Horde.Properties.LogicalCoresOverride = \"${HATHORA_ALLOCATED_CPU_ROUND}\"" appsettings.json > appsettings.json.tmp && mv appsettings.json.tmp appsettings.json
  jq ".Horde.Properties.LogicalCoreRatio = \"2\"" appsettings.json > appsettings.json.tmp && mv appsettings.json.tmp appsettings.json
  jq ".Horde.Properties.AvailableMemoryOverride = \"${HATHORA_ALLOCATED_MEMORY_GB}\"" appsettings.json > appsettings.json.tmp && mv appsettings.json.tmp appsettings.json
  # end if
fi

dotnet HordeAgent.dll SetServer -Name=HordeServer -Url=${HORDE_SERVER_URL} -Default -Token=${HORDE_SERVER_TOKEN}

dotnet HordeAgent.dll

continue_loop="true"

# Function to handle SIGTERM
handle_sigterm() {
  echo "Received SIGTERM, exiting..."
  continue_loop="false"
}

# Set up the trap for SIGTERM
trap handle_sigterm SIGTERM

# Loop until continue_loop is set to false
while [ "$continue_loop" = "true" ]; do
  sleep 1
done

popd

