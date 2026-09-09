require "json" unless defined?(JSON)
require "pathname" unless defined?(Pathname)

module Fauxhai
  # Loads mock Ohai data for a platform and version.
  #
  # Data is looked up on disk first, under `lib/fauxhai/platforms`. If it is not
  # there and `:github_fetching` is enabled, it is downloaded from the project's
  # main branch and cached locally, so platforms contributed after the installed
  # gem was released still resolve.
  #
  # @see Fauxhai.mock
  class Mocker
    # The base URL for the GitHub project (raw)
    # @return [String]
    RAW_BASE = "https://raw.githubusercontent.com/chef/fauxhai/main".freeze

    # A message about where to find a list of platforms
    # @return [String]
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
    # @yieldparam data [Hash] the loaded platform data, for overriding
    #   attributes in place
    # @return [Fauxhai::Mocker]
    # @raise [Fauxhai::Exception::InvalidPlatform] if a block is given and the
    #   platform data cannot be resolved
    def initialize(options = {}, &override_attributes)
      @options = { github_fetching: true }.merge(options)

      yield(data) if block_given?
    end

    # The mock Ohai data, loaded on first call and memoized after that.
    #
    # Resolution order is `:path` if given, then the on-disk platform file,
    # then GitHub when `:github_fetching` is enabled.
    #
    # @return [Hash] the parsed Ohai data
    # @raise [Fauxhai::Exception::InvalidPlatform] if the data cannot be found
    #   on disk, or the GitHub fetch is disabled or fails
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
            raise Fauxhai::Exception::InvalidPlatform.new("Could not find platform '#{platform}/#{version}' on the local disk and an HTTP error was encountered when fetching from GitHub. #{PLATFORM_LIST_MESSAGE}")
          end

          if response.code.to_i == 200
            response_body = response.body
            path = Pathname.new(filepath)
            FileUtils.mkdir_p(path.dirname)

            begin
              File.open(filepath, "w") { |f| f.write(response_body) }
            rescue Errno::EACCES # a pretty common problem in CI systems
              puts "Fetched '#{platform}/#{version}' from GitHub, but could not write to the local path: #{filepath}. Fix the local file permissions to avoid downloading this file every run."
            end
            return parse_and_validate(response_body)
          else
            raise Fauxhai::Exception::InvalidPlatform.new("Could not find platform '#{platform}/#{version}' on the local disk and GitHub fetching returned an http error code #{response.code}! #{PLATFORM_LIST_MESSAGE}")
          end
        else
          raise Fauxhai::Exception::InvalidPlatform.new("Could not find platform '#{platform}/#{version}' on the local disk and GitHub fetching is disabled! #{PLATFORM_LIST_MESSAGE}")
        end
      end.call
    end

    private

    # As major releases of Ohai ship it's difficult and sometimes impossible
    # to regenerate all fauxhai data. This allows us to deprecate old releases
    # and eventually remove them while giving end users ample warning.
    #
    # Data marked `deprecated` still loads; it only warns on STDERR.
    #
    # @param unparsed_data [String] the raw JSON read from disk or GitHub
    # @return [Hash] the parsed data
    # @raise [JSON::ParserError] if the data is not valid JSON
    def parse_and_validate(unparsed_data)
      parsed_data = JSON.parse(unparsed_data)
      if parsed_data["deprecated"]
        STDERR.puts "WARNING: Fauxhai platform data for #{parsed_data["platform"]} #{parsed_data["platform_version"]} is deprecated and will be removed in the 10.0 release 3/2022. #{PLATFORM_LIST_MESSAGE}"
      end
      parsed_data
    end

    # The platform being mocked, defaulting to the synthetic "chefspec"
    # platform with a warning when the caller omitted one.
    #
    # @return [String] the platform name
    def platform
      @options[:platform] ||= begin
                                STDERR.puts "WARNING: you must specify a 'platform' and optionally a 'version' for your ChefSpec Runner and/or Fauxhai constructor, in the future omitting the platform will become a hard error. #{PLATFORM_LIST_MESSAGE}"
                                "chefspec"
                              end
    end

    # The directory holding the JSON files for the current platform.
    #
    # @return [String] an absolute path, which may not exist yet
    def platform_path
      File.join(Fauxhai.root, "lib", "fauxhai", "platforms", platform)
    end

    # The platform version to load.
    #
    # An exact filename match wins. Otherwise the option is treated as a
    # prefix, so `"6"` resolves to CentOS `6.10`; a trailing `\D` in the
    # prefix match keeps `"7.1"` from matching `"7.10.0"`. A nil or empty
    # version matches anything. When several candidates remain, the highest
    # wins under a version comparison loose enough to cope with the range of
    # formats in use (`4.8-RELEASE`, `2012R2`, `10.15`).
    #
    # If nothing matches, the caller's option is passed through unchanged so
    # that GitHub fetching still gets a chance.
    #
    # @return [String, nil] the resolved version
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
