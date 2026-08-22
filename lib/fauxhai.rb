# Fauxhai provides mock Ohai data for testing Chef cookbooks with ChefSpec.
#
# Platform data ships with the gem as JSON files under `lib/fauxhai/platforms`,
# one file per platform version. {mock} loads that canned data; {fetch} collects
# real Ohai output from a running host instead.
#
# @see https://github.com/chef/fauxhai
module Fauxhai
  autoload :Exception, "fauxhai/exception"
  autoload :Fetcher, "fauxhai/fetcher"
  autoload :Mocker, "fauxhai/mocker"
  autoload :VERSION, "fauxhai/version"

  # The absolute path to the root of the installed gem. Used to locate the
  # bundled platform data and the fake SSH keys.
  #
  # @return [String] the gem's root directory
  def self.root
    @@root ||= File.expand_path("../../", __FILE__)
  end

  # Build mock Ohai data for a platform and version.
  #
  # The platform data is resolved lazily: passing a block forces the load
  # immediately, otherwise it happens on the first call to
  # {Fauxhai::Mocker#data}.
  #
  # @example Mock Ubuntu 20.04
  #   Fauxhai.mock(platform: 'ubuntu', version: '20.04')
  #
  # @example Override an attribute on the mocked node
  #   Fauxhai.mock(platform: 'ubuntu', version: '20.04') do |node|
  #     node['languages']['ruby']['version'] = 'ree'
  #   end
  #
  # @param args [Array] options forwarded to {Fauxhai::Mocker#initialize}
  # @yieldparam node [Hash] the mocked data, for overriding attributes in place
  # @return [Fauxhai::Mocker] a mocker wrapping the platform data
  # @see Fauxhai::Mocker#initialize
  def self.mock(*args, &block)
    Fauxhai::Mocker.new(*args, &block)
  end

  # Collect real Ohai data from a remote host over SSH.
  #
  # Unlike {mock}, this runs immediately: the SSH connection is opened (or the
  # local cache read) during construction.
  #
  # @example Fetch from a running server
  #   Fauxhai.fetch(host: 'server01.example.com')
  #
  # @param args [Array] options forwarded to {Fauxhai::Fetcher#initialize}
  # @yieldparam node [Hash] the fetched data, for overriding attributes in place
  # @return [Fauxhai::Fetcher] a fetcher wrapping the collected Ohai data
  # @raise [ArgumentError] if no `:host` option is given
  # @see Fauxhai::Fetcher#initialize
  def self.fetch(*args, &block)
    Fauxhai::Fetcher.new(*args, &block)
  end
end
