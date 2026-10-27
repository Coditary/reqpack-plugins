return {
  name = "cocoapods info merges installed and spec data",
  request = {
    action = "info",
    system = "cocoapods",
    flags = {
      "dir=/tmp/reqpack-cocoapods-info/project",
      "home=/tmp/reqpack-cocoapods-info/home",
    },
    prompt = "AFNetworking",
  },
  fixtureDirs = {
    "/tmp/reqpack-cocoapods-info/project",
    "/tmp/reqpack-cocoapods-info/home",
  },
  fixtureFiles = {
    {
      path = "/tmp/reqpack-cocoapods-info/project/Podfile.lock",
      content = [[PODS:
  - AFNetworking (4.0.0)

DEPENDENCIES:
  - AFNetworking (~> 4.0)

SPEC REPOS:
  trunk:
    - AFNetworking

COCOAPODS: 1.16.2
]],
    },
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
      match = "cat '/tmp/reqpack-cocoapods-info/project/Podfile.lock'",
      exitCode = 0,
      stdout = "PODS:\n  - AFNetworking (4.0.0)\n\nDEPENDENCIES:\n  - AFNetworking (~> 4.0)\n\nSPEC REPOS:\n  trunk:\n    - AFNetworking\n\nCOCOAPODS: 1.16.2\n",
      stderr = "",
      success = true,
    },
    {
      match = "HOME='/tmp/reqpack-cocoapods-info/home' CP_HOME_DIR='/tmp/reqpack-cocoapods-info/home/.cocoapods' COCOAPODS_DISABLE_STATS='true' COCOAPODS_SKIP_UPDATE_MESSAGE='true' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' pod spec which AFNetworking --no-ansi",
      exitCode = 0,
      stdout = "/virtual/specs/AFNetworking.podspec.json\n",
      stderr = "",
      success = true,
    },
    {
      match = "HOME='/tmp/reqpack-cocoapods-info/home' CP_HOME_DIR='/tmp/reqpack-cocoapods-info/home/.cocoapods' COCOAPODS_DISABLE_STATS='true' COCOAPODS_SKIP_UPDATE_MESSAGE='true' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' pod ipc spec /virtual/specs/AFNetworking.podspec.json --no-ansi",
      exitCode = 0,
      stdout = [[{"name":"AFNetworking","version":"4.0.1","summary":"A delightful networking framework for Apple platforms.","description":"A delightful networking framework for Apple platforms.","homepage":"https://github.com/AFNetworking/AFNetworking","authors":{"Mattt":"mattt@afnetworking.com"},"license":{"type":"MIT"},"source":{"git":"https://github.com/AFNetworking/AFNetworking.git"},"platforms":{"ios":"9.0","osx":"10.10"},"dependencies":{}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "cat '/tmp/reqpack-cocoapods-info/project/Podfile.lock'",
      "command -v 'pod' >/dev/null 2>&1",
      "HOME='/tmp/reqpack-cocoapods-info/home' CP_HOME_DIR='/tmp/reqpack-cocoapods-info/home/.cocoapods' COCOAPODS_DISABLE_STATS='true' COCOAPODS_SKIP_UPDATE_MESSAGE='true' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' pod spec which AFNetworking --no-ansi",
      "HOME='/tmp/reqpack-cocoapods-info/home' CP_HOME_DIR='/tmp/reqpack-cocoapods-info/home/.cocoapods' COCOAPODS_DISABLE_STATS='true' COCOAPODS_SKIP_UPDATE_MESSAGE='true' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' pod ipc spec /virtual/specs/AFNetworking.podspec.json --no-ansi"
    },
    events = { "informed" },
    resultCount = 1,
    resultName = "AFNetworking",
    resultVersion = "4.0.0",
  },
}
