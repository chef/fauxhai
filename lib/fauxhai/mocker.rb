module Fauxhai
  # Loads mock Ohai data from bundled JSON fixtures or, as a fallback,
  # from the GitHub repository's `main` branch.
  #
  # == File paths
  # - Source: `lib/fauxhai/mocker.rb`
  # - Platform data: `lib/fauxhai/platforms/<platform>/<version>.json`
  # - Platform list: `PLATFORMS.md` (auto-generated — do not edit)
  #
  # == Data resolution order
  #   1. If `:path` option given → load that exact file
  #   2. Else → resolve `<platform>/<version>.json` under `lib/fauxhai/platforms/`
  #   3. If file not found locally and `github_fetching: true` (default) →
  #      HTTP GET from `https://raw.githubusercontent.com/chef/fauxhai/main/…`
  #      and cache the response locally via {CacheManager.write_json_file}
  #   4. If HTTP also fails → raise {Exception::InvalidPlatform}
  #
  # == Version prefix matching
  # When an exact `<version>.json` file is not found, Mocker searches for
  # files whose name starts with the supplied version string followed by a
  # non-digit character (`/^<version>\D/`). Among matches it picks the
  # highest version using a flexible comparator that handles dotted
  # versions, dash-suffixed releases (`4.8-RELEASE`), and Windows
  # identifiers (`2012R2`).
  #
  # Examples:
  #   version: "20"   → matches 20.04 (Ubuntu)
  #   version: "7"    → matches 7.8.2003, not 7.10 (prefix + \D guard)
  #   version: nil    → picks the highest available version
  #
  # == Risks
  # - *Network dependency*: GitHub fetching makes an outbound HTTP call.
  #   Set `github_fetching: false` in CI or air-gapped environments.
  # - *Write failures*: `Errno::EACCES` on the local cache write is
  #   rescued and logged to stdout — the data is still returned, but
  #   every subsequent run will re-fetch from GitHub.
  # - *Deprecated data*: JSON files may contain `"deprecated": true`.
  #   A warning is printed to STDERR but data is still returned.
  #   Deprecated platforms will be removed in a future major release.
  # - *Stale gem data*: platform JSON ships with the gem. New platforms
  #   merged to `main` are only available via GitHub fetching until the
  #   next gem release.
  #
  # == Extension guidance
  # - To add a new platform: create `lib/fauxhai/platforms/<name>/<ver>.json`
  #   using `bin/fauxhai`, then run `rake update_json_list` and
  #   `rake documentation:update_platforms`.
  # - To change resolution logic: modify `#version` (private). Add tests
  #   in `spec/mocker_spec.rb` covering prefix matching edge cases.
  # - Do NOT add direct File I/O for caching — use {CacheManager}.
  class Mocker
    # The base URL for the GitHub project (raw)
    RAW_BASE = "https://raw.githubusercontent.com/chef/fauxhai/main".freeze

    # A message about where to find a list of platforms
    PLATFORM_LIST_MESSAGE = "A list of available platforms is available at https://github.com/chef/fauxhai/blob/main/PLATFORMS.md".freeze

    # Create a new Ohai Mock with fauxhai.
    #
    # @param [Hash] options
    #   the options for the mocker
    # @option options [String] :platform
    #   the platform to mock
    # @option options [String] :version
    #   the version of the platform to mock
    # @option options [String] :path
    #   the path to a local JSON file
    # @option options [Bool] :github_fetching
    #   whether to try loading from Github
    def initialize(options = {}, &override_attributes)
      @options = { github_fetching: true }.merge(options)

      yield(data) if block_given?
    end

    def data
      @fauxhai_data ||= lambda do
        # If a path option was specified, use it
        if @options[:path]
          filepath = File.expand_path(@options[:path])

          unless File.exist?(filepath)
            raise Fauxhai::Exception::InvalidPlatform.new("You specified a path to a JSON file on the local system that does not exist: '#{filepath}'")
          end
        else
          filepath = File.join(platform_path, "#{version}.json")
        end

        if File.exist?(filepath)
          parse_and_validate(File.read(filepath))
        elsif @options[:github_fetching]
          # Try loading from github (in case someone submitted a PR with a new file, but we haven't
          # yet updated the gem version). Cache the response locally so it's faster next time.
          require "net/http" unless defined?(Net::HTTP)
          begin
            uri = URI("#{RAW_BASE}/lib/fauxhai/platforms/#{platform}/#{version}.json")
            response = Net::HTTP.get_response(uri)
          rescue StandardError
            raise Fauxhai::Exception::InvalidPlatform.new("Could not find platform '#{platform}/#{version}' on the local disk and an HTTP error was encountered when fetching from Github. #{PLATFORM_LIST_MESSAGE}")
          end

          if response.code.to_i == 200
            response_body = response.body

            begin
              Fauxhai::CacheManager.write_json_file(filepath, response_body)
            rescue Errno::EACCES # a pretty common problem in CI systems
              puts "Fetched '#{platform}/#{version}' from GitHub, but could not write to the local path: #{filepath}. Fix the local file permissions to avoid downloading this file every run."
            end
            return parse_and_validate(response_body)
          else
            raise Fauxhai::Exception::InvalidPlatform.new("Could not find platform '#{platform}/#{version}' on the local disk and an Github fetching returned http error code #{response.code}! #{PLATFORM_LIST_MESSAGE}")
          end
        else
          raise Fauxhai::Exception::InvalidPlatform.new("Could not find platform '#{platform}/#{version}' on the local disk and Github fetching is disabled! #{PLATFORM_LIST_MESSAGE}")
        end
      end.call
    end

    private

    # As major releases of Ohai ship it's difficult and sometimes impossible
    # to regenerate all fauxhai data. This allows us to deprecate old releases
    # and eventually remove them while giving end users ample warning.
    def parse_and_validate(unparsed_data)
      parsed_data = JSON.parse(unparsed_data)
      if parsed_data["deprecated"]
        STDERR.puts "WARNING: Fauxhai platform data for #{parsed_data["platform"]} #{parsed_data["platform_version"]} is deprecated and will be removed in the 10.0 release 3/2022. #{PLATFORM_LIST_MESSAGE}"
      end
      parsed_data
    end

    def platform
      @options[:platform] ||= begin
                                STDERR.puts "WARNING: you must specify a 'platform' and optionally a 'version' for your ChefSpec Runner and/or Fauxhai constructor, in the future omitting the platform will become a hard error. #{PLATFORM_LIST_MESSAGE}"
                                "chefspec"
                              end
    end

    def platform_path
      File.join(Fauxhai.root, "lib", "fauxhai", "platforms", platform)
    end

    def version
      @version ||= begin
        if File.exist?("#{platform_path}/#{@options[:version]}.json")
          # Whole version, use it as-is.
          @options[:version]
        else
          # Check if it's a prefix of an existing version.
          versions = Dir["#{platform_path}/*.json"].map { |path| File.basename(path, ".json") }
          unless @options[:version].to_s == ""
            # If the provided version is nil or '', that means take anything,
            # otherwise run the prefix match with an extra \D to avoid the
            # case where "7.1" matches "7.10.0".
            prefix_re = /^#{Regexp.escape(@options[:version])}\D/
            versions.select! { |ver| ver =~ prefix_re }
          end

          if versions.empty?
            # No versions available, either an unknown platform or nothing matched
            # the prefix check. Pass through the option as given so we can try
            # github fetching.
            @options[:version]
          else
            # Take the highest version available, trying to use rules that should
            # probably mostly work on all OSes. Famous last words. The idea of
            # the regex is to split on any punctuation (the common case) and
            # also any single letter with digit on either side (2012r2). This
            # leaves any long runs of letters intact (4.2-RELEASE). Then convert
            # any run of digits to an integer to get version-ish comparison.
            # This is basically a more flexible version of Gem::Version.
            versions.max_by do |ver|
              ver.split(/[^a-z0-9]|(?<=\d)[a-z](?=\d)/i).map do |part|
                if part =~ /^\d+$/
                  part.to_i
                else
                  part
                end
              end
            end
          end
        end
      end
    end

  end
end
