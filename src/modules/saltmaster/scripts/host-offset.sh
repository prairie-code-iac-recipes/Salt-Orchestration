#!/bin/bash

set -eou pipefail

# -----------------------------------------------------------------------------
# Parse and Validate Inputs
# -----------------------------------------------------------------------------
eval "$(jq -r '@sh "SUBNET_COUNT=\(.subnet_count) INSTANCE_COUNT=\(.instance_count)"')"

if [ -z ${SUBNET_COUNT} ]; then
  >&2 echo "subnet_count (${SUBNET_COUNT}) must be specified."
  exit 1
elif [[ ${SUBNET_COUNT} =~ '^[0-9]+$' ]] ; then
  >&2 echo "subnet_count (${SUBNET_COUNT}) must be numeric."
  exit 2
elif [ -z "${INSTANCE_COUNT}" ]; then
  >&2 echo "instance_count (${INSTANCE_COUNT}) must be specified."
  exit 3
elif [[ ${INSTANCE_COUNT} =~ '^[0-9]+$' ]] ; then
  >&2 echo "instance_count (${INSTANCE_COUNT}) must be numeric."
  exit 2
fi

response=
subnet=0
hostnum=0
for (( i = 0; i < $INSTANCE_COUNT; i++ ))
do
  if [ ! -z "$response" ]; then
    response+=", "
  fi
  response+="\"$i\": \"$hostnum\""
  subnet=$(( $subnet + 1 ))
  if [ "$subnet" -eq "$SUBNET_COUNT" ]; then
    hostnum=$(( $hostnum + 1 ))
    subnet=0
  fi
done

  if [ ! -z "$response" ]; then
    response+=", "
  fi
  response+="\"max\": \"$((( $hostnum )))\""

# printf '%s\n' "${response[@]}" | jq -R . | jq -s .
# jq -n --arg response "$response" '{"$response"}'
echo "{ $response }"
