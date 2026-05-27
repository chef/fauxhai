# frozen_string_literal: true

require "json" unless defined?(JSON)
require "fileutils" unless defined?(FileUtils)

module Fauxhai
  # Centralised JSON file I/O used by both Fetcher and Mocker.
  #
  # == Consumers
  # - {Fauxhai::Fetcher}  — caches SSH-captured Ohai data to `<root>/tmp/<sha>`
  # - {Fauxhai::Mocker}   — caches GitHub-fetched platform JSON to
  #   `lib/fauxhai/platforms/<platform>/<version>.json`
  #
  # == Cache locations
  # | Consumer | Path pattern                                      |
  # |----------|---------------------------------------------------|
  # | Fetcher  | `<Fauxhai.root>/tmp/<SHA2 of user@host>`           |
  # | Mocker   | `<Fauxhai.root>/lib/fauxhai/platforms/<p>/<v>.json` |
  #
  # == Risks
  # - *Directory traversal*: callers must validate `path` before passing it
  #   here. Neither method sanitises the path.
  # - *Race conditions*: concurrent writes to the same cache file are not
  #   guarded by a lock. In practice this is harmless because the content
  #   is deterministic, but be aware in multi-process test suites.
  # - *Disk quota*: cached files are never reaped automatically. If disk
  #   space is constrained (CI), callers should clear `tmp/` periodically.
  #
  # == Extension guidance
  # To add a new I/O helper (e.g. atomic writes), add a class method here
  # rather than scattering File operations across Fetcher/Mocker.
  module CacheManager
    # Read and parse a JSON file from disk.
    #
    # @param path [String] absolute path to the JSON file
    # @return [Hash] the parsed JSON data
    # @raise [Errno::ENOENT]       if the file does not exist
    # @raise [JSON::ParserError]   if the file is not valid JSON
    def self.read_json_file(path)
      Fauxhai.logger.debug("CacheManager reading: #{path}")
      JSON.parse(File.read(path))
    end

    # Write data as JSON to disk, creating parent directories as needed.
    #
    # @param path [String] absolute path to write
    # @param data [Hash, String] data to write (Hash is converted to JSON,
    #   String written as-is)
    # @return [void]
    # @raise [Errno::EACCES] if the directory or file is not writable
    def self.write_json_file(path, data)
      Fauxhai.logger.debug("CacheManager writing: #{path}")
      FileUtils.mkdir_p(File.dirname(path))
      content = data.is_a?(String) ? data : data.to_json
      File.open(path, "w") { |f| f.write(content) }
    end
  end
end
