# frozen_string_literal: true

module Fauxhai
  # Resolves the best-matching version for a given platform directory.
  #
  # Extracted from Mocker#version to keep version-resolution logic
  # in a single, independently testable place.
  class VersionResolver
    # @param platform_path [String] absolute path to the platform directory
    # @param requested_version [String, nil] the version string from the caller
    # @return [String] the resolved version string
    def self.resolve(platform_path, requested_version)
      new(platform_path, requested_version).resolve
    end

    def initialize(platform_path, requested_version)
      @platform_path = platform_path
      @requested_version = requested_version
    end

    def resolve
      # Exact match — use as-is.
      return @requested_version if exact_match?

      # Prefix match (e.g. "7" matches "7.8.2003").
      candidates = prefix_matches
      return highest_version(candidates) unless candidates.empty?

      # Nothing matched — pass through so the caller can try GitHub
      # fetching or raise an appropriate error.
      @requested_version
    end

    private

    def exact_match?
      File.exist?(File.join(@platform_path, "#{@requested_version}.json"))
    end

    def available_versions
      @available_versions ||= Dir["#{@platform_path}/*.json"].map { |path| File.basename(path, ".json") }
    end

    def prefix_matches
      return available_versions if @requested_version.to_s == ""

      prefix_re = /^#{Regexp.escape(@requested_version)}\D/
      available_versions.grep(prefix_re)
    end

    # Pick the highest version using a heuristic that handles mixed
    # alphanumeric segments (e.g. "2012R2", "4.8-RELEASE").
    def highest_version(versions)
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
