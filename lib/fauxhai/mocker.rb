require "json" unless defined?(JSON)
require "pathname" unless defined?(Pathname)

module Fauxhai
  class Mocker
    # The base URL for the GitHub project (raw)
    RAW_BASE = "https://raw.githubusercontent.com/chef/fauxhai/main".freeze

    # A message about where to find a list of platforms
    PLATFORM_LIST_MESSAGE = "A list of available platforms is available at https://github.com/chef/fauxhai/blob/main/PLATFORMS.md".freeze

    # Class-level cache for parsed platform JSON. Avoids re-reading and
    # re-parsing the same file when the same platform/version is mocked
    # repeatedly (the common case in ChefSpec suites).
    @json_cache = {}

    class << self
      attr_reader :json_cache

      # Clear the cache (useful in tests or when platform files change).
      def clear_cache!
        @json_cache = {}
      end
    end

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
          cached_read(filepath)
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
            path = Pathname.new(filepath)
            FileUtils.mkdir_p(path.dirname)

            begin
              File.open(filepath, "w") { |f| f.write(response_body) }
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

    # Read and parse a platform JSON file, using the class-level cache to
    # avoid redundant File.read calls for the same path. JSON.parse is
    # still called each time to produce an independent Hash that callers
    # (e.g. ChefSpec override blocks) can mutate freely.
    def cached_read(filepath)
      raw = self.class.json_cache[filepath] ||= File.read(filepath)
      parse_and_validate(raw)
    end

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
      @version ||= Fauxhai::VersionResolver.resolve(platform_path, @options[:version])
    end

  end
end
