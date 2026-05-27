require "spec_helper"
require "json"

# Contract test: verifies that every non-deprecated platform JSON file
# conforms to the schema expected by ChefSpec consumers.
#
# The golden schema lives at spec/fixtures/platform_schema.json.
# If a platform legitimately adds/removes a top-level key, update the
# schema file and note the change in the PR description.

describe "Platform JSON contract" do
  let(:schema) do
    JSON.parse(File.read(File.join(Fauxhai.root, "spec", "fixtures", "platform_schema.json")))
  end

  let(:platform_files) do
    Dir.glob(File.join(Fauxhai.root, "lib", "fauxhai", "platforms", "**", "*.json")).reject do |f|
      f.include?("chefspec") # chefspec is a minimal fixture, not a real platform
    end
  end

  it "has at least one platform file to validate" do
    expect(platform_files).not_to be_empty
  end

  platform_dir = File.join(File.expand_path("../lib/fauxhai/platforms", __dir__))
  Dir.glob(File.join(platform_dir, "**", "*.json")).reject { |f| f.include?("chefspec") }.each do |filepath|
    relative = filepath.sub("#{platform_dir}/", "")

    context relative do
      let(:data) { JSON.parse(File.read(filepath)) }

      # Skip deprecated platforms — they are frozen and may not match current schema.
      before do
        skip "deprecated platform" if data["deprecated"]
      end

      it "contains all required string keys" do
        schema["required_string_keys"].each do |key|
          expect(data).to have_key(key), "missing key '#{key}' in #{relative}"
          expect(data[key]).to be_a(String), "'#{key}' should be a String in #{relative}, got #{data[key].class}"
        end
      end

      it "contains all required numeric keys" do
        schema["required_numeric_keys"].each do |key|
          expect(data).to have_key(key), "missing key '#{key}' in #{relative}"
          expect(data[key]).to be_a(Numeric), "'#{key}' should be Numeric in #{relative}, got #{data[key].class}"
        end
      end

      it "contains all required hash keys" do
        schema["required_hash_keys"].each do |key|
          expect(data).to have_key(key), "missing key '#{key}' in #{relative}"
          expect(data[key]).to be_a(Hash), "'#{key}' should be a Hash in #{relative}, got #{data[key].class}"
        end
      end

      it "has consistent platform metadata" do
        # platform and platform_version must be non-empty strings
        expect(data["platform"]).not_to be_empty, "platform must not be empty in #{relative}"
        expect(data["platform_version"]).not_to be_empty, "platform_version must not be empty in #{relative}"
      end
    end
  end
end
