module Fauxhai
  class Runner
    # The sanitized values {Fauxhai::Runner} substitutes into real Ohai output
    # before it is printed.
    #
    # Every method here returns a fixed stand-in rather than anything read from
    # the machine being scanned. That is the whole point: contributed platform
    # files must not leak the hostname, username, addresses, or SSH keys of the
    # box they were generated on. The constants are deliberately boring and
    # identical across platforms, so diffs between platform files show real
    # differences instead of environmental noise.
    #
    # {Fauxhai::Runner::Windows} overrides the handful of these that Ohai
    # reports differently on Windows.
    module Default
      # @return [String] the fake directory holding the Ruby binaries
      def bin_dir
        "/usr/local/bin"
      end

      # Fake network traffic counters for the loopback and default interfaces.
      #
      # All totals are zero so that platform files never carry a real machine's
      # traffic volume, and so mocks stay byte-identical between runs.
      #
      # @return [Hash] the fake counter tree, keyed by interface name
      def counters
        {
          "network" => {
            "interfaces" => {
              "lo" => {
                "tx" => {
                  "queuelen" => "1",
                  "bytes" =>  0,
                  "packets" =>  0,
                  "errors" =>  0,
                  "drop" =>  0,
                  "carrier" => 0,
                  "collisions" => 0,
                },
                "rx" =>  {
                  "bytes" => 0,
                  "packets" => 0,
                  "errors" => 0,
                  "drop" => 0,
                  "overrun" => 0,
                },
              },
              default_interface.to_s => {
                "rx" => {
                  "bytes" => 0,
                  "packets" => 0,
                  "errors" => 0,
                  "drop" => 0,
                  "overrun" => 0,
                  "frame" => 0,
                  "compressed" => 0,
                  "multicast" => 0,
                },
                "tx" => {
                  "bytes" => 0,
                  "packets" => 0,
                  "errors" => 0,
                  "drop" => 0,
                  "overrun" => 0,
                  "collisions" => 0,
                  "carrier" => 0,
                  "compressed" => 0,
                },
              },
            },
          },
        }
      end

      # @return [String] the fake name of the user running Ohai
      def current_user
        "fauxhai"
      end

      # @return [String] the fake default gateway address
      def default_gateway
        "10.0.0.1"
      end

      # The primary network interface name, which is the one piece of the fake
      # network data that has to vary: cookbooks branch on the interface
      # naming convention, so mocking `eth0` on Fedora would be wrong.
      #
      # @return [String] the interface name for the detected platform family
      def default_interface
        case @system.data["platform_family"]
        when "mac_os_x"
          "en0"
        when /bsd/
          "em0"
        when "arch", "fedora"
          "enp0s3"
        else
          "eth0"
        end
      end

      # @return [String] the fake DNS domain
      def domain
        "local"
      end

      # @return [String] the fake fully qualified domain name
      def fqdn
        "fauxhai.local"
      end

      # @return [String] the fake path to the `gem` executable
      def gem_bin
        "/usr/local/bin/gem"
      end

      # @return [String] the fake directory holding installed gems
      def gems_dir
        "/usr/local/gems"
      end

      # @return [String] the fake hostname
      def hostname
        "Fauxhai"
      end

      # @return [String] the fake IPv4 address
      def ipaddress
        "10.0.0.2"
      end

      # @return [String] the fake IPv6 address
      def ip6address
        "fe80:0:0:0:0:0:a00:2"
      end

      # The fake host key data, standing in for whatever is really in
      # `/etc/ssh` on the machine being scanned.
      #
      # @return [Hash] the fake key material
      # @see #ssh
      def keys
        {
          "ssh" => ssh,
        }
      end

      # The real language data from Ohai, with the Ruby paths swapped for the
      # fake ones. Version and platform details are genuine, since that is
      # exactly what cookbooks need to test against; only the paths, which
      # would otherwise embed a username, are replaced.
      #
      # @return [Hash] the language data for Ruby and PowerShell
      def languages
        {
          "ruby" => @system.data["languages"]["ruby"].merge("bin_dir" => bin_dir,
                                                            "gem_bin" => gem_bin,
                                                            "gems_dir" => gems_dir,
                                                            "ruby_bin" => ruby_bin),
          "powershell" => @system.data["languages"]["powershell"],
        }
      end

      # @return [String] the fake MAC address
      def macaddress
        "11:11:11:11:11:11"
      end

      # The fake network topology: a loopback interface and one default
      # interface on a 10.0.0.0/24 network, with matching routes and ARP
      # entries.
      #
      # @return [Hash] the fake interfaces, default interface, and gateway
      def network
        {
          "interfaces" => {
            "lo" => {
              "mtu" => "65536",
              "flags" => %w{LOOPBACK UP LOWER_UP},
              "encapsulation" => "Loopback",
              "addresses" => {
                "127.0.0.1" => {
                  "family" => "inet",
                  "prefixlen" => "8",
                  "netmask" => "255.0.0.0",
                  "scope" => "Node",
                  "ip_scope" => "LOOPBACK",
                },
                "::1" => {
                  "family" => "inet6",
                  "prefixlen" => "128",
                  "scope" => "Node",
                  "tags" => [],
                  "ip_scope" => "LINK LOCAL LOOPBACK",
                },
              },
              "state" => "unknown",
            },
            default_interface.to_s => {
              "type" => default_interface.chop,
              "number" => "0",
              "mtu" => "1500",
              "flags" => %w{BROADCAST MULTICAST UP LOWER_UP},
              "encapsulation" => "Ethernet",
              "addresses" => {
                macaddress.to_s => {
                  "family" => "lladdr",
                },
                ipaddress.to_s => {
                  "family" => "inet",
                  "prefixlen" => "24",
                  "netmask" => "255.255.255.0",
                  "broadcast" => "10.0.0.255",
                  "scope" => "Global",
                  "ip_scope" => "RFC1918 PRIVATE",
                },
                "fe80::11:1111:1111:1111" => {
                  "family" => "inet6",
                  "prefixlen" => "64",
                  "scope" => "Link",
                  "tags" => [],
                  "ip_scope" => "LINK LOCAL UNICAST",
                },
              },
              "state" => "up",
              "arp" => {
                "10.0.0.1" => "fe:ff:ff:ff:ff:ff",
              },
              "routes" => [
                {
                  "destination" => "default",
                  "family" => "inet",
                  "via" => default_gateway,
                },
                {
                  "destination" => "10.0.0.0/24",
                  "family" => "inet",
                  "scope" => "link",
                  "proto" => "kernel",
                  "src" => ipaddress,
                },
                {
                  "destination" => "fe80::/64",
                  "family" => "inet6",
                  "metric" => "256",
                  "proto" => "kernel",
                },
              ],
              "ring_params" => {},
            },
          },
          "default_interface" => default_interface,
          "default_gateway" => default_gateway,
        }
      end

      # @return [String] the fake path to the `ruby` executable
      def ruby_bin
        "/usr/local/bin/ruby"
      end

      # The throwaway public keys bundled with the gem, read from
      # `lib/fauxhai/keys`. They exist only so mocked nodes have plausibly
      # shaped key data; they are published in the repository and guard
      # nothing.
      #
      # @return [Hash] the fake DSA and RSA public keys
      def ssh
        {
          "host_dsa_public" => File.read(File.join(Fauxhai.root, "lib", "fauxhai", "keys", "id_dsa.pub")).strip,
          "host_rsa_public" => File.read(File.join(Fauxhai.root, "lib", "fauxhai", "keys", "id_rsa.pub")).strip,
        }
      end

      # @return [String] the fake uptime, as Ohai formats it for humans
      def uptime
        "30 days 15 hours 07 minutes 30 seconds"
      end

      # @return [Integer] the fake uptime in seconds, matching {#uptime}
      def uptime_seconds
        2646450
      end

      # @return [Hash] a fake single-core CPU
      def cpu
        {
          "real" => 1,
          "total" => 1,
          "cores" => 1,
        }
      end

      # @return [Hash] a fake 1GB of total memory
      def memory
        {
          "total" => "1048576kB",
        }
      end

      # @return [Hash] empty virtualization data, so mocks read as bare metal
      def virtualization
        {
          "systems" => {},
        }
      end

      # @return [Hash] a fake timezone, fixed to GMT
      def time
        {
          "timezone" => "GMT",
        }
      end

      # Whitelist attributes are attributes that we *actually* want from the node. Other attributes are
      # either ignored or overridden, but we ensure these are returned with the command.
      #
      # This is an allow list rather than a deny list on purpose: a new Ohai
      # plugin that starts collecting something sensitive is dropped by
      # default, instead of leaking until someone notices.
      #
      # @return [Array<String>] the attribute keys copied from the real data
      def whitelist_attributes
        %w{
          block_device
          chef_packages
          command
          dmi
          filesystem
          fips
          init_package
          kernel
          lsb
          ohai_time
          os
          os_release
          os_version
          packages
          platform
          platform_version
          platform_build
          platform_family
          root_group
          shard_seed
          shells
        }
      end
    end
  end
end
