module Fauxhai
  # Errors raised by Fauxhai. Both inherit from `ArgumentError`, so existing
  # rescues of `ArgumentError` keep working.
  module Exception
    # Raised when platform data cannot be located: an unknown platform, a
    # `:path` pointing at a missing file, or a failed fetch from GitHub.
    class InvalidPlatform < ArgumentError; end

    # Raised when a platform is known but the requested version is not
    # available for it.
    class InvalidVersion < ArgumentError; end
  end
end
