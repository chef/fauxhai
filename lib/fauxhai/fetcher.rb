# frozen_string_literal: true

module Fauxhai
  # Connects to a remote host via SSH, runs `ohai`, and returns the parsed
  # JSON output as a Ruby Hash.
  #
  # == File paths
  # - Source: `lib/fauxhai/fetcher.rb`
  # - SSH keys: `lib/fauxhai/keys/id_rsa`, `lib/fauxhai/keys/id_dsa`
  # - Cache dir: `<Fauxhai.root>/tmp/`
  #
  # == Data flow
  #   Fauxhai.fetch(host: "node1") →
  #     1. Check local cache (`tmp/<SHA2 of user@host>`)
  #     2. On miss → `Net::SSH.start` → `ssh.exec!("ohai")` → JSON.parse
  #     3. Write result to cache via {CacheManager.write_json_file}
  #     4. If ChefSpec is loaded, monkey-patch `ChefSpec::Runner#fake_ohai`
  #
  # == Risks
  # - *SSH credential exposure*: options hash may contain `:password` or
  #   `:key_data` — these are passed directly to `Net::SSH.start`. Never
  #   log or persist the raw `@options` hash.
  # - *Stale cache*: cached data is never invalidated automatically. Use
  #   `force_cache_miss: true` to bypass the cache.
  # - *ChefSpec monkey-patch*: if ChefSpec is defined, `#fake_ohai` is
  #   injected into `ChefSpec::Runner` at runtime — this is global state
  #   and can leak between test examples.
  #
  # == Extension guidance
  # - To add new SSH-based collectors, subclass Fetcher or compose a new
  #   class that delegates `cache`/`cache_file` to {CacheManager}.
  # - Do NOT add direct `File.open`/`JSON.parse` calls — use CacheManager.
  class Fetcher
    def initialize(options = {}, &override_attributes)
      @options = options

      if !force_cache_miss? && cached?
        Fauxhai.logger.debug { "Cache hit for #{cache_key}, loading from #{cache_file}" }
        @data = cache
      else
        Fauxhai.logger.info("Cache miss for #{user}@#{host}, connecting via SSH")
        require "net/ssh" unless defined?(Net::SSH)
        Net::SSH.start(host, user, @options) do |ssh|
          @data = JSON.parse(ssh.exec!("ohai"))
        end

        # cache this data so we do not have to SSH again
        Fauxhai.logger.debug { "Caching fetched data to #{cache_file}" }
        Fauxhai::CacheManager.write_json_file(cache_file, @data)
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

    def cache
      @cache ||= Fauxhai::CacheManager.read_json_file(cache_file)
    end

    def cached?
      File.exist?(cache_file)
    end

    def cache_key
      Digest::SHA2.hexdigest("#{user}@#{host}")
    end

    def cache_file
      File.expand_path(File.join(Fauxhai.root, "tmp", cache_key))
    end

    def force_cache_miss?
      @force_cache_miss ||= @options.delete(:force_cache_miss) || false
    end

    # Return the given `@data` attribute as a Ruby hash instead of a JSON object
    #
    # @return [Hash] the `@data` represented as a Ruby hash
    def to_hash(*args)
      @data.to_hash(*args)
    end

    def to_s
      "#<Fauxhai::Fetcher @host=#{host}, @options=#{@options}>"
    end

    private

    def host
      @host ||= begin
        raise ArgumentError, ":host is a required option for Fauxhai.fetch" unless @options[:host]

        @options.delete(:host)
      end
    end

    def user
      @user ||= (@options.delete(:user) || ENV["USER"] || ENV["USERNAME"]).chomp
    end
  end
end
