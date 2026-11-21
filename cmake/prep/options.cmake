# Publisher Metadata
set(SUNSHINE_PUBLISHER_NAME "Third Party Publisher"
        CACHE STRING "The name of the publisher (not developer) of the application.")
set(SUNSHINE_PUBLISHER_WEBSITE ""
        CACHE STRING "The URL of the publisher's website.")
set(SUNSHINE_PUBLISHER_ISSUE_URL ""
        CACHE STRING "The URL of the publisher's support site or issue tracker.")

option(BUILD_TESTS "Build tests" ON)
option(NPM_OFFLINE "Use offline npm packages. You must ensure packages are in your npm cache." OFF)

option(BUILD_WERROR "Enable -Werror flag." OFF)

# The tray needs Qt from Homebrew at run time, so it is off: the app must start on a Mac without Homebrew.
option(SUNSHINE_ENABLE_TRAY "Enable system tray icon (needs Qt)." OFF)

option(BOOST_USE_STATIC "Use static boost libraries." ON)

option(SUNSHINE_BUILD_HOMEBREW "Enable a Homebrew build." OFF)
