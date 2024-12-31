#!/bin/bash

#
# when using the following workflow, the following env vars are available to us for use.

#   # subscription to fire off any other promotions that you may need for an additional channnel like LTS or something. 
#   - workload: staged_workload_released:{{agent_id}}:hab_unstable_promote:*
#     actions:
#     - bash:.expeditor/scripts/promote-hab-pkgs.sh:
#         post_commit: true
#
# PROMOTABLE - in promotion artifact actions this is a reference to the
#              source channel.
# EXPEDITOR_CHANNEL - Read from the expeditor config, this should be the "lowest" channel in your promotion. IE: unstable 
# EXPEDITOR_TARGET_CHANNEL - the channel which we are promoting to
# HAB_AUTH_TOKEN - GitHub Auth token used to communicate with the
#                  Habitat depot and private repos in Chef's GitHub org
#
set -eou pipefail

# Export the HAB_AUTH_TOKEN for use of promoting habitat packages to {{EXPEDITOR_TARGET_CHANNEL}}
HAB_AUTH_TOKEN=$(vault kv get -field auth_token account/static/habitat/chef-ci)
export HAB_AUTH_TOKEN


# when this workflow runs, there are env vars that are available to us in the running pod, we are grabbing the source ENV, then assigning it to our next channel
if [[ "${EXPEDITOR_CHANNEL}" == "unstable" ]]; then
  echo "This file does not support actions for artifacts promoted to unstable, that should happen in the /expeditor promote AGENT VERSION command from slack"
  exit 1
elif [[ "${EXPEDITOR_CHANNEL}" == "stable" ]]; then
  export EXPEDITOR_TARGET_CHANNEL="workstation-LTS"
  echo "My current package is in channel: ${EXPEDITOR_CHANNEL}. I am promoting to ${EXPEDITOR_TARGET_CHANNEL}"
# elif [[ "${EXPEDITOR_CHANNEL}" == "acceptance" ]]; then
#   export EXPEDITOR_TARGET_CHANNEL="current"
#   echo "My current package is in channel: ${EXPEDITOR_CHANNEL}. I am promoting to ${EXPEDITOR_TARGET_CHANNEL}"
# elif [[ "${EXPEDITOR_CHANNEL}" == "current" ]]; then
#   export EXPEDITOR_TARGET_CHANNEL="stable"
#   echo "My current package is in channel: ${EXPEDITOR_CHANNEL}. I am promoting to ${EXPEDITOR_TARGET_CHANNEL}"
else
  echo "Unknown EXPEDITOR_CHANNEL: ${EXPEDITOR_CHANNEL}"
  exit 1
fi

# Promote the artifacts in Habitat Depot
  if [[ "${EXPEDITOR_PKG_ORIGIN}" == "core" ]];
  then
    echo "Skipping promotion of core origin package ${EXPEDITOR_PKG_ORIGIN}"
  else
    echo "Promoting ${EXPEDITOR_PKG_IDENT} to the ${EXPEDITOR_TARGET_CHANNEL} channel"
    hab pkg promote "${EXPEDITOR_PKG_IDENT}" "${EXPEDITOR_TARGET_CHANNEL}"
  fi
