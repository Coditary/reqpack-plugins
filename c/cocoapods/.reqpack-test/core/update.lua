return {
  name = "cocoapods update dependency constraint",
  request = {
    action = "update",
    system = "cocoapods",
    flags = {
      "dir=/tmp/reqpack-cocoapods-update/project",
      "home=/tmp/reqpack-cocoapods-update/home",
    },
    packages = {
      { name = "AFNetworking", version = "4.0.1" }
    },
  },
  fixtureDirs = {
    "/tmp/reqpack-cocoapods-update/project",
    "/tmp/reqpack-cocoapods-update/home",
  },
  fixtureFiles = {
    {
      path = "/tmp/reqpack-cocoapods-update/project/Podfile",
      content = [[target 'Demo' do
  pod 'AFNetworking', '4.0.0'
end
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
      match = "cat '/tmp/reqpack-cocoapods-update/project/Podfile'",
      exitCode = 0,
      stdout = "target 'Demo' do\n  pod 'AFNetworking', '4.0.0'\nend\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/reqpack-cocoapods-update/project' && python3 -c \"import pathlib; pathlib.Path(\"/tmp/reqpack-cocoapods-update/project/Podfile\").write_text(\"target 'Demo' do\\n  pod 'AFNetworking', '4.0.1'\\nend\\n\")\"",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "HOME='/tmp/reqpack-cocoapods-update/home' CP_HOME_DIR='/tmp/reqpack-cocoapods-update/home/.cocoapods' COCOAPODS_DISABLE_STATS='true' COCOAPODS_SKIP_UPDATE_MESSAGE='true' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' pod update AFNetworking --project-directory=/tmp/reqpack-cocoapods-update/project --no-ansi --no-repo-update",
      exitCode = 0,
      stdout = "Updating local specs repositories\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'pod' >/dev/null 2>&1",
      "cat '/tmp/reqpack-cocoapods-update/project/Podfile'",
      "cat '/tmp/reqpack-cocoapods-update/project/Podfile'",
      "mkdir -p '/tmp/reqpack-cocoapods-update/project' && python3 -c \"import pathlib; pathlib.Path(\"/tmp/reqpack-cocoapods-update/project/Podfile\").write_text(\"target 'Demo' do\\n  pod 'AFNetworking', '4.0.1'\\nend\\n\")\"",
      "HOME='/tmp/reqpack-cocoapods-update/home' CP_HOME_DIR='/tmp/reqpack-cocoapods-update/home/.cocoapods' COCOAPODS_DISABLE_STATS='true' COCOAPODS_SKIP_UPDATE_MESSAGE='true' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' pod update AFNetworking --project-directory=/tmp/reqpack-cocoapods-update/project --no-ansi --no-repo-update"
    },
    events = { "updated", "success" },
  },
}
