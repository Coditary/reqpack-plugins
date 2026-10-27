return {
  name = "cocoapods outdated project dependencies",
  request = {
    action = "outdated",
    system = "cocoapods",
    flags = {
      "dir=/tmp/reqpack-cocoapods-outdated/project",
      "home=/tmp/reqpack-cocoapods-outdated/home",
    },
  },
  fixtureDirs = {
    "/tmp/reqpack-cocoapods-outdated/project",
    "/tmp/reqpack-cocoapods-outdated/home",
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
      match = "HOME='/tmp/reqpack-cocoapods-outdated/home' CP_HOME_DIR='/tmp/reqpack-cocoapods-outdated/home/.cocoapods' COCOAPODS_DISABLE_STATS='true' COCOAPODS_SKIP_UPDATE_MESSAGE='true' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' pod outdated --project-directory=/tmp/reqpack-cocoapods-outdated/project --no-ansi --no-repo-update",
      exitCode = 0,
      stdout = [[The following pod updates are available:
- AFNetworking 4.0.0 -> 4.0.1 (latest version 4.0.1)
]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "AFNetworking",
    resultVersion = "4.0.0",
  },
}
