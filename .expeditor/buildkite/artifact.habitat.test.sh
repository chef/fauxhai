#!/usr/bin/env bash

set -eo pipefail

export PLAN='fauxhai'
export CHEF_LICENSE="accept-no-persist"
export HAB_LICENSE="accept-no-persist"
export HAB_BLDR_CHANNEL='base-2025'
export HAB_REFRESH_CHANNEL="base-2025"

echo "--- checking if git is installed"
if ! command -v git &> /dev/null; then
    echo "Git is not installed. Installing Git..."
    sudo yum install -y git
else
    echo "Git is already installed."
    git --version
fi

echo "--- add an exception for this directory since detected dubious ownership in repository at /workdir"
git config --global --add safe.directory /workdir

echo "--- git status for this workdir"
git status

echo "--- checking ruby version"
ruby -v

export project_root="$(git rev-parse --show-toplevel)"
echo "The value for project_root is: $project_root"

export HAB_NONINTERACTIVE=true
export HAB_NOCOLORING=true
export HAB_STUDIO_SECRET_HAB_NONINTERACTIVE=true

echo "--- system details"
uname -a

echo "--- Installing Habitat"
id -a
curl https://raw.githubusercontent.com/habitat-sh/habitat/main/components/hab/install.sh | bash

# Set HAB_ORIGIN after Habitat installation
echo "--- Setting HAB_ORIGIN to 'ci' after installation"
export HAB_ORIGIN='ci'

echo "--- :key: Generating fake origin key"
hab origin key generate "$HAB_ORIGIN"


echo "--- Building $PLAN"
cd "$project_root"
DO_CHECK=true hab pkg build .

echo "--- Sourcing 'results/last_build.sh'"
if [ -f ./results/last_build.env ]; then
    cat ./results/last_build.env
    . ./results/last_build.env
    export pkg_artifact
fi
echo "+++ Installing ${pkg_ident:?is undefined}"
echo "++++"
echo $project_root
echo "+++"
hab pkg install -b "${project_root:?is undefined}/results/${pkg_artifact:?is undefined}"

echo "+++ Testing $PLAN"

PATH="$(hab pkg path ci/fauxhai)/bin:$PATH"
export PATH
echo "PATH is $PATH"

echo "--- :mag_right: Testing $PLAN"
${project_root}/habitat/tests/test.sh "$pkg_ident" || error 'failures during test of executables'