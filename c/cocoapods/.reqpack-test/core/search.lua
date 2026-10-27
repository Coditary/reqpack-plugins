return {
  name = "cocoapods search remote pod",
  request = {
    action = "search",
    system = "cocoapods",
    flags = {
      "home=/tmp/reqpack-cocoapods-search/home",
    },
    prompt = "AFNetworking",
  },
  fixtureDirs = {
    "/tmp/reqpack-cocoapods-search/home",
  },
  fakeExec = {
    {
      match = "command -v 'pod' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "HOME='/tmp/reqpack-cocoapods-search/home' CP_HOME_DIR='/tmp/reqpack-cocoapods-search/home/.cocoapods' COCOAPODS_DISABLE_STATS='true' COCOAPODS_SKIP_UPDATE_MESSAGE='true' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' pod search AFNetworking --simple --no-pager --no-ansi",
      exitCode = 0,
      stdout = [[-> AFNetworking (4.0.1)
   A delightful networking framework for Apple platforms.
   pod 'AFNetworking', '~> 4.0'
   - Homepage: https://github.com/AFNetworking/AFNetworking
   - Source:   https://github.com/AFNetworking/AFNetworking.git
   - Versions: 4.0.1, 4.0.0
]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "AFNetworking",
    resultVersion = "4.0.1",
  },
}
