#!/bin/bash

# Copyright 2015 The Kubernetes Authors All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o pipefail

POD_NAMESPACE=${POD_NAMESPACE:-default}
POD_IP=${POD_IP:-127.0.0.1}
RETHINK_CLUSTER=${RETHINK_CLUSTER:-"rethinkdb"}
POD_NAME=${POD_NAME:-"NO_POD_NAME"}

# Transform - to _ to comply with requirements
SERVER_NAME=$(echo ${POD_NAME} | sed 's/-/_/g')

echo "Using additional CLI flags: ${@}"
echo "Pod IP: ${POD_IP}"
echo "Pod namespace: ${POD_NAMESPACE}"
echo "Using service name: ${RETHINK_CLUSTER}"
echo "Using server name: ${SERVER_NAME}"

echo "Checking for other nodes..."

JOIN_ENDPOINTS=`./findPeers`

echo "findPeers: ${JOIN_ENDPOINTS}"

if [ -z "$JOIN_ENDPOINTS" ]
then
  if [[ "$SERVER_NAME" == *"1"* ]];
  then
    echo "No other nodes found, but name contains 1.. so skip sleep"
  else
    echo "No other nodes found, sleep 10"
    sleep 10
    JOIN_ENDPOINTS=`./findPeers`
  fi
else
  # xargs echo removes extra spaces before/after
  # tr removes extra spaces in the middle
  JOIN_ENDPOINTS=$(echo ${JOIN_ENDPOINTS} | xargs echo | tr -s ' ')
fi

if [ -n "${JOIN_ENDPOINTS}" ]; then
  echo "Found other nodes: ${JOIN_ENDPOINTS}"

  # Now, transform join endpoints into --join ENDPOINT:29015
  # Put port after each
  JOIN_ENDPOINTS=$(echo ${JOIN_ENDPOINTS} | sed -r 's/([0-9.])+/&:29015/g')

  # Put --join before each
  JOIN_ENDPOINTS=$(echo ${JOIN_ENDPOINTS} | sed -r 's/^|[ ]/&--join /g')
else
  echo "No other nodes detected, will be a single instance."
  if [ -n "$PROXY" ]; then
    echo "Cannot start in proxy mode without endpoints."
    exit 1
  fi
fi

if [[ -n "${PROXY}" ]]; then
  echo "Starting in proxy mode"
  set -x
  exec rethinkdb \
    proxy \
    --canonical-address ${POD_IP} \
    --bind all \
    ${JOIN_ENDPOINTS} \
    ${@}
else
  set -x
  exec rethinkdb \
    --server-name ${SERVER_NAME} \
    --canonical-address ${POD_IP} \
    --bind all \
    ${JOIN_ENDPOINTS} \
    ${@}
fi
