return {
  name = "cocoapods remove dependency from project",
  request = {
    action = "remove",
    system = "cocoapods",
    flags = {
      "dir=/tmp/reqpack-cocoapods-remove/project",
      "home=/tmp/reqpack-cocoapods-remove/home",
    },
    packages = {
      { name = "AFNetworking" }
    },
  },
  fixtureDirs = {
    "/tmp/reqpack-cocoapods-remove/project",
    "/tmp/reqpack-cocoapods-remove/home",
  },
  fixtureFiles = {
    {
      path = "/tmp/reqpack-cocoapods-remove/project/Podfile",
      content = [[target 'Demo' do
  pod 'AFNetworking', '4.0.1'
  pod 'Alamofire', '5.7.1'
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
      match = "cat '/tmp/reqpack-cocoapods-remove/project/Podfile'",
      exitCode = 0,
      stdout = "target 'Demo' do\n  pod 'AFNetworking', '4.0.1'\n  pod 'Alamofire', '5.7.1'\nend\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/reqpack-cocoapods-remove/project' && python3 -c \"import pathlib; pathlib.Path(\"/tmp/reqpack-cocoapods-remove/project/Podfile\").write_text(\"target 'Demo' do\\n  pod 'Alamofire', '5.7.1'\\nend\\n\")\"",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "HOME='/tmp/reqpack-cocoapods-remove/home' CP_HOME_DIR='/tmp/reqpack-cocoapods-remove/home/.cocoapods' COCOAPODS_DISABLE_STATS='true' COCOAPODS_SKIP_UPDATE_MESSAGE='true' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' pod install --project-directory=/tmp/reqpack-cocoapods-remove/project --no-ansi",
      exitCode = 0,
      stdout = "Removing AFNetworking\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'pod' >/dev/null 2>&1",
      "cat '/tmp/reqpack-cocoapods-remove/project/Podfile'",
      "cat '/tmp/reqpack-cocoapods-remove/project/Podfile'",
      "mkdir -p '/tmp/reqpack-cocoapods-remove/project' && python3 -c \"import pathlib; pathlib.Path(\"/tmp/reqpack-cocoapods-remove/project/Podfile\").write_text(\"target 'Demo' do\\n  pod 'Alamofire', '5.7.1'\\nend\\n\")\"",
      "HOME='/tmp/reqpack-cocoapods-remove/home' CP_HOME_DIR='/tmp/reqpack-cocoapods-remove/home/.cocoapods' COCOAPODS_DISABLE_STATS='true' COCOAPODS_SKIP_UPDATE_MESSAGE='true' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' pod install --project-directory=/tmp/reqpack-cocoapods-remove/project --no-ansi"
    },
    events = { "deleted", "success" },
  },
}
