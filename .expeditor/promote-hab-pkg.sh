#!/bin/bash

set -eou pipefail

echo "--> Running the promote-hab-pkg.sh script"
HAB_AUTH_TOKEN=$(vault kv get -field auth_token account/static/habitat/chef-ci)
export HAB_AUTH_TOKEN

source_channel="workstation-build"
 hab pkg promote "${EXPEDITOR_PKG_IDENT}" "${EXPEDITOR_TARGET_CHANNEL}"  "${EXPEDITOR_PKG_TARGET}"