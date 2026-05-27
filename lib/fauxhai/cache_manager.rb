require "json" unless defined?(JSON)
require "fileutils" unless defined?(FileUtils)

module Fauxhai
  module CacheManager
    # Read and parse a JSON file from disk.
    #
    # @param path [String] absolute path to the JSON file
    # @return [Hash] the parsed JSON data
    # @raise [Errno::ENOENT] if the file does not exist
    def self.read_json_file(path)
      JSON.parse(File.read(path))
    end

    # Write data as JSON to disk, creating parent directories as needed.
    #
    # @param path [String] absolute path to write
    # @param data [Hash, String] data to write (Hash is converted to JSON, String written as-is)
    # @return [void]
    def self.write_json_file(path, data)
      FileUtils.mkdir_p(File.dirname(path))
      content = data.is_a?(String) ? data : data.to_json
      File.open(path, "w") { |f| f.write(content) }
    end
  end
end
