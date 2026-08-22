require "ohai" unless defined?(Ohai::System)
require "ohai/plugins/chef"

module Fauxhai
  # Powers the `fauxhai` command line tool.
  #
  # Runs every Ohai plugin on the local machine, then keeps only the
  # attributes in {Fauxhai::Runner::Default#whitelist_attributes} and replaces
  # the rest with sanitized stand-ins, so the result carries no usernames,
  # hostnames, IP addresses, or real SSH keys. The sanitized JSON is printed to
  # STDOUT, ready to be contributed as a new platform file.
  #
  # The sanitizing methods come from {Fauxhai::Runner::Windows} on Windows and
  # {Fauxhai::Runner::Default} everywhere else.
  class Runner
    # Collect, sanitize, and print the local Ohai data.
    #
    # @param args [Array<String>] command line arguments, currently unused;
    #   `bin/fauxhai` handles `-v` and `-h` before constructing the runner
    # @return [void]
    def initialize(args)
      @system = Ohai::System.new
      @system.all_plugins

      case @system.data["platform"]
      when "windows", :windows
        require_relative "runner/windows"
        singleton_class.send :include, ::Fauxhai::Runner::Windows
      else
        require_relative "runner/default"
        singleton_class.send :include, ::Fauxhai::Runner::Default
      end

      result = @system.data.dup.delete_if { |k, v| !whitelist_attributes.include?(k) }.merge(
        "languages" => languages,
        "counters" => counters,
        "current_user" => current_user,
        "domain" => domain,
        "hostname" => hostname,
        "machinename" => hostname,
        "fqdn" => fqdn,
        "ipaddress" => ipaddress,
        "keys" => keys,
        "macaddress" => macaddress,
        "network" => network,
        "uptime" => uptime,
        "uptime_seconds" => uptime_seconds,
        "idle" => uptime,
        "idletime_seconds" => uptime_seconds,
        "cpu" => cpu,
        "memory" => memory,
        "virtualization" => virtualization,
        "time" => time
      )

      require "json" unless defined?(JSON)
      puts JSON.pretty_generate(result.sort.to_h)
    end
  end
end
