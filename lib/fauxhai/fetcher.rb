require "digest/sha1"
require "json" unless defined?(JSON)

module Fauxhai
  # Collects real Ohai data from a remote host over SSH, rather than using the
  # canned platform data that {Fauxhai::Mocker} loads.
  #
  # Results are cached on disk under the gem's `tmp` directory and keyed by
  # user and host, so repeat runs skip the SSH round trip. Because the cache
  # holds real data from a real machine, treat it as sensitive.
  #
  # @see Fauxhai.fetch
  class Fetcher
    # Fetch Ohai data from a host, or read it back from the local cache.
    #
    # @example
    #   Fauxhai::Fetcher.new(host: 'server01.example.com', user: 'deploy')
    #
    # @param options [Hash] options for the fetch. Beyond the keys below, any
    #   remaining options are passed straight through to `Net::SSH.start`,
    #   so `:password`, `:key_file` and friends all work.
    # @option options [String] :host the host to collect data from (required)
    # @option options [String] :user the SSH user, defaulting to `$USER`
    #   or `$USERNAME`
    # @option options [Boolean] :force_cache_miss re-fetch over SSH even when
    #   a cached copy exists
    # @yieldparam data [Hash] the fetched data, for overriding attributes
    # @return [Fauxhai::Fetcher]
    # @raise [ArgumentError] if no `:host` was given
    def initialize(options = {}, &override_attributes)
      @options = options

      if !force_cache_miss? && cached?
        @data = cache
      else
        require "net/ssh" unless defined?(Net::SSH)
        Net::SSH.start(host, user, @options) do |ssh|
          @data = JSON.parse(ssh.exec!("ohai"))
        end

        # cache this data so we do not have to SSH again
        File.open(cache_file, "w+") { |f| f.write(@data.to_json) }
      end

      yield(@data) if block_given?

      if defined?(ChefSpec)
        data = @data
        ::ChefSpec::Runner.send :define_method, :fake_ohai do |ohai|
          data.each_pair do |attribute, value|
            ohai[attribute] = value
          end
        end
      end

      @data
    end

    # The cached Ohai data for this user and host.
    #
    # @return [Hash] the parsed contents of {#cache_file}
    def cache
      @cache ||= JSON.parse(File.read(cache_file))
    end

    # Whether a cached copy already exists for this user and host.
    #
    # @return [Boolean]
    def cached?
      File.exist?(cache_file)
    end

    # A stable digest of the user and host, used as the cache filename so
    # that different targets do not collide.
    #
    # @return [String] a hex digest
    def cache_key
      Digest::SHA2.hexdigest("#{user}@#{host}")
    end

    # The absolute path this host's cached data is written to.
    #
    # @return [String] a path under the gem's `tmp` directory
    def cache_file
      File.expand_path(File.join(Fauxhai.root, "tmp", cache_key))
    end

    # Whether the caller asked to bypass the cache. Reading this consumes the
    # `:force_cache_miss` option so it is not forwarded on to `Net::SSH`.
    #
    # @return [Boolean]
    def force_cache_miss?
      @force_cache_miss ||= @options.delete(:force_cache_miss) || false
    end

    # Return the given `@data` attribute as a Ruby hash instead of a JSON object
    #
    # @return [Hash] the `@data` represented as a Ruby hash
    def to_hash(*args)
      @data.to_hash(*args)
    end

    # @return [String] a readable representation of the fetcher
    def to_s
      "#<Fauxhai::Fetcher @host=#{host}, @options=#{@options}>"
    end

    private

    # The host to collect from. Reading this consumes the `:host` option so it
    # is not forwarded on to `Net::SSH`.
    #
    # @return [String] the hostname
    # @raise [ArgumentError] if `:host` was never given
    def host
      @host ||= begin
        raise ArgumentError, ":host is a required option for Fauxhai.fetch" unless @options[:host]

        @options.delete(:host)
      end
    end

    # The SSH user, falling back to the local `$USER` or `$USERNAME`. Reading
    # this consumes the `:user` option so it is not forwarded on to `Net::SSH`.
    #
    # @return [String] the username
    def user
      @user ||= (@options.delete(:user) || ENV["USER"] || ENV["USERNAME"]).chomp
    end
  end
end
