pkg_name=fauxhai
pkg_origin=chef
pkg_version="9.3.16"
pkg_description="Easily mock full ohai data"
pkg_license=('Apache-2.0')
pkg_deps=(
  core/ruby31
  core/bash
)
pkg_build_deps=(
  core/gcc
  core/make
)
pkg_bin_dirs=(bin)

# Setup environment variables for Ruby Gems
do_setup_environment() {
  build_line "Setting up GEM_HOME and GEM_PATH"
  export GEM_HOME="$pkg_prefix/lib"
  export GEM_PATH="$GEM_HOME"
}

# Unpack the source files into the cache directory
do_unpack() {
  local unpack_dir="$HAB_CACHE_SRC_PATH/$pkg_dirname"
  build_line "Creating unpack directory: $unpack_dir"
  mkdir -pv "$unpack_dir"
  cp -RT "$PLAN_CONTEXT"/.. "$unpack_dir/"
}

# Build the gem from the gemspec file
do_build() {
  build_line "Building the gem from the gemspec file"
  pushd "$HAB_CACHE_SRC_PATH/$pkg_dirname" > /dev/null
  gem build fauxhai-chef.gemspec
  popd > /dev/null
}

# Install the built gem into the package directory
do_install() {
  build_line "Installing the gem"
  pushd "$HAB_CACHE_SRC_PATH/$pkg_dirname" > /dev/null
  gem install fauxhai-*.gem --no-document
  popd > /dev/null

  wrap_fauxhai_bin
}

# Create a wrapper script to properly set paths and execute the fauxhai command
wrap_fauxhai_bin() {
  local bin="$pkg_prefix/bin/$pkg_name"
  local real_bin="$GEM_HOME/gems/fauxhai-chef-${pkg_version}/bin/fauxhai"

  build_line "Creating wrapper script: $bin"
  cat <<EOF > "$bin"
#!$(pkg_path_for core/bash)/bin/bash
set -e

# Set the PATH for Fauxhai to include necessary binaries
export PATH="/sbin:/usr/sbin:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin:\$PATH"

# Set Ruby paths defined from 'do_setup_environment()'
export GEM_HOME="$GEM_HOME"
export GEM_PATH="$GEM_PATH"

# Execute the Fauxhai binary
exec $(pkg_path_for core/ruby31)/bin/ruby $real_bin "\$@"
EOF

  # Ensure the wrapper script is executable
  chmod -v 755 "$bin"
}

# No additional stripping needed
do_strip() {
  return 0
}
