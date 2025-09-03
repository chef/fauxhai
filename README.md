# Fauxhai-ng

![CI](https://github.com/chef/fauxhai/workflows/CI/badge.svg) [![Gem Version](https://badge.fury.io/rb/fauxhai-ng.svg)](https://badge.fury.io/rb/fauxhai-ng)

Note: fauxhai-ng is an updated version of the original fauxhai gem. The CLI and library namespaces have not changed, but you will want to update to use the new gem.

Fauxhai is a gem for mocking out [ohai](https://github.com/chef/ohai) data in your chef testing. Fauxhai is community supported, so we need **your help** to populate our dataset. Here's an example for testing my "awesome_cookbook" on Ubuntu 20.04:

```ruby
require 'chefspec'

describe 'awesome_cookbook::default' do
  before do
    Fauxhai.mock(platform: 'ubuntu', version: '20.04')
  end

  it 'should install awesome' do
    @runner = ChefSpec::ChefRunner.new.converge('tmpreaper::default')
    expect(@runner).to install_package 'awesome'
  end
end
```

Alternatively, you can pull "real" Ohai data from an existing server:

```ruby
require 'chefspec'

describe 'awesome_cookbook::default' do
  before do
    Fauxhai.fetch(host: 'server01.example.com')
  end

  it 'should install awesome' do
    @runner = ChefSpec::ChefRunner.new.converge('tmpreaper::default')
    expect(@runner).to install_package 'awesome'
  end
end
```

## Important Note

Fauxhai ships with a command line tool - `fauxhai`. This is **not** the same as Fauxhai.mock. Running `fauxhai` on a machine effectively runs `ohai`, but then sanitizes the data, removing/replacing things like:

- users
- ssh keys
- usernames in paths
- sensitive system information

`fauxhai` should only be used by developers wishing to submit a new json file.

## Platform and Versions

For a complete list of platforms and versions available for mocking via Fauxhai see [PLATFORMS.MD](https://github.com/chef/fauxhai/blob/master/PLATFORMS.md) in this repository.

## Usage

Fauxhai provides a bunch of default attributes so that you don't need to mock out your entire infrastructure to write a simple test. That being said, not all configurations will suit your needs. Because of that, Fauxhai provides two ways to configure your mocks:

### Overriding

`Fauxhai.mock` will also accept a block with override attributes that are merged with all the default attributes. For example, the default Ubuntu 12.04 mock uses `Ruby 1.9.3`. Maybe your system is using `ree`, and you want to verify that the cookbooks work with that data as well:

```ruby
require 'chefspec'

describe 'awesome_cookbook::default' do
  before do
    Fauxhai.mock(platform: 'ubuntu', version: '12.04') do |node|
      node['languages']['ruby']['version'] = 'ree'
    end
  end

  it 'should install awesome' do
    @runner = ChefSpec::ChefRunner.new.converge('tmpreaper::default')
    expect(@runner).to install_package 'awesome'
  end
end
```

The `node` block variable allows you to set any Ohai attribute on the mock that you want. This provides an easy way to manage your environments. If you find that you are overriding attributes like OS or platform, you should see the section on Contributing.

### Fetching

Alternatively, if you do not want to mock the data, Fauxhai provides a `fetch` mechanism for collecting "real" Ohai data from a remote server or local file. Maybe you want to test against the fully-replicated environment for a front-facing server in your pool. Just pass in the `url` option instead of a `platform`:

The `fetch` method supports all the same options as the Net-SSH command, such as `:user`, `:password`, `:key_file`, etc.

The `fetch` method will cache the JSON file in a temporary path on your local machine. Similar to gems like VCR, this allows Fauxhai to use the cached copy, making your test suite run faster. You can optionally force a cache miss by passing the `:force_cache_miss => true` option to the `fetch` initializer. **Because this is real data, there may be a security concern. Secure your laptop accordingly.**

```ruby
require 'chefspec'

describe 'awesome_cookbook::default' do
  before do
    Fauxhai.fetch(host: 'server01.example.com')
  end

  it 'should install awesome' do
    @runner = ChefSpec::ChefRunner.new.converge('tmpreaper::default')
    expect(@runner).to install_package 'awesome'
  end
end
```

This will ssh into the machine (you must have authorization to run `sudo ohai` on that machine), download a copy of the Ohai output, and optionally cache that data inside the test directory (speeding up future tests).

### Overriding + Fetching

As you might expect, you can combine overriding and fetching like so:

```ruby
require 'chefspec'

describe 'awesome_cookbook::default' do
  before do
    Fauxhai.fetch(host: 'server01.example.com') do |node|
      node['languages']['ruby']['version'] = 'ree'
    end
  end

  it 'should install awesome' do
    @runner = ChefSpec::ChefRunner.new.converge('tmpreaper::default')
    expect(@runner).to install_package 'awesome'
  end
end
```

### Fixturing

If you want to use Fauxhai as "fixture" data, you can store real JSON in your project and use the `:path` option:

```ruby
require 'chefspec'

describe 'awesome_cookbook::default' do
  before do
    Fauxhai.mock(path: 'fixtures/my_node.json')
  end
end
```

### Overriding + Fixturing

You can also change specific attributes in your fixture:

```ruby
require 'chefspec'

describe 'awesome_cookbook::default' do
  before do
    Fauxhai.mock(path: 'fixtures/my_node.json') do |node|
      node['languages']['ruby']['version'] = 'ree'
    end
  end
end
```

### Disabling Fetching from Github

On environments that does not have access to the internet, you can disable fetching Fauxhai data from GitHub as follow:

```ruby
require 'chefspec'

describe 'awesome_cookbook::default' do
  before do
    Fauxhai.mock(platform: 'ubuntu', version: '12.04', github_fetching: false)
  end
end
```

## Testing Multiple Versions

It's a common use case to test multiple version of the same operating system. Here's a simple example to get your started. This is more rspec-related that Fauxhai related, but here ya go:

```ruby
require 'chefspec'

describe 'awesome_cookbook::default' do
  ['18.04', '20.04'].each do |version|
    context "on Ubuntu #{version}" do
      before do
        Fauxhai.mock(platform: 'ubuntu', version: version)
      end

      it 'should install awesome' do
        @runner = ChefSpec::ChefRunner.new.converge('tmpreaper::default')
        expect(@runner).to install_package 'awesome'
      end
    end
  end
end
```


## Contributing to Fauxhai

Fauxhai is community-maintained and updated. Aside from the initial files, all of the ohai system mocks have been created by the community. If you have a system that you think would benefit the community, here's how you get it into [fauxhai](https://github.com/chef/fauxhai):

1. Build a system to your liking (on a virtual machine, for example)
2. Install chef, ohai, and fauxhai
3. Run the following at the command line:

  Unix:

  ```
   sudo fauxhai > /tmp/fauxhai.json
  ```

  Windows (in Administrator mode):

  ```
   fauxhai > C:\SomePath\fauxhai.json
  ```

4. This will create a file `fauxhai.json` at the specified path. As with any tool, inspect the contents of the file before continuing

5. Copy the contents of this file to your local development machine (using scp or sftp, for example)
6. Fork, clone and `bundle`:

  ```
   git clone https://github.com/<your username>/fauxhai.git
   cd fauxhai
   bundle
  ```

7. Create a new branch named `add_[platform]_[version]` (e.g. `add_ubuntu_12_04`) without dashes and dots replaced with underscores. Be sure to use the official version number, not a package name (e.g. '12_04', not 'precise') if available:

  ```
   Ubuntu Precise, 12.04       add_ubuntu_12_04
   Ubuntu Lucid, 10.04         add_ubuntu_10_04
   OSX Lion, 10.7.4            add_osx_10_7_4
   Windows XP                  add_windows_xp
  ```

  **Q:** Is there a reason for this super-specific naming convention?

  **A:** No, but it helps in tracking problems and analyzing pull requests. Ultimately it just ensures your pull request is merged as quickly as possible

8. Create a new json file in `lib/fauxhai/platforms/[os]/[version].json` (e.g. `lib/fauxhai/platforms/ubuntu/12.04.json`)

9. Copy-paste the contents of the file from `Step 4` into this file and save
10. Verify the installation was successful by doing the following:

  ```
  bundle console
  requiure "fauxhai"
  Fauxhai.mock(platform: '[os]', version: '[version]') # e.g. Fauxhai.mock(platform: 'ubuntu', version: '12.04').data
  ```

  As long as that does not throw an error, you're good to go!

11. Submit a pull request on github

**Note:** I do _not_ need to release a new version of Fauxhai for your changes to be pulled and used. Unless you are updating an existing platform, Fauxhai will automatically pull new versions from GitHub via HTTP and cache them.

## Contributing

See [CONTRIBUTING.md](https://github.com/chef/fauxhai/blob/master/CONTRIBUTING.md).