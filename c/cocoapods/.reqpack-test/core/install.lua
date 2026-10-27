return {
  name = "cocoapods install dependency into project",
  request = {
    action = "install",
    system = "cocoapods",
    flags = {
      "dir=/tmp/reqpack-cocoapods-install/project",
      "home=/tmp/reqpack-cocoapods-install/home",
    },
    packages = {
      { name = "AFNetworking", version = "4.0.1" }
    },
  },
  fixtureDirs = {
    "/tmp/reqpack-cocoapods-install/project",
    "/tmp/reqpack-cocoapods-install/home",
  },
  fixtureFiles = {
    {
      path = "/tmp/reqpack-cocoapods-install/project/Podfile",
      content = [[target 'Demo' do
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
      match = "cat '/tmp/reqpack-cocoapods-install/project/Podfile'",
      exitCode = 0,
      stdout = "target 'Demo' do\n  pod 'Alamofire', '5.7.1'\nend\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/reqpack-cocoapods-install/project' && python3 -c \"import pathlib; pathlib.Path(\"/tmp/reqpack-cocoapods-install/project/Podfile\").write_text(\"target 'Demo' do\\n  pod 'Alamofire', '5.7.1'\\n  pod 'AFNetworking', '4.0.1'\\nend\\n\")\"",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "HOME='/tmp/reqpack-cocoapods-install/home' CP_HOME_DIR='/tmp/reqpack-cocoapods-install/home/.cocoapods' COCOAPODS_DISABLE_STATS='true' COCOAPODS_SKIP_UPDATE_MESSAGE='true' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' pod install --project-directory=/tmp/reqpack-cocoapods-install/project --no-ansi",
      exitCode = 0,
      stdout = "Analyzing dependencies\nDownloading dependencies\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'pod' >/dev/null 2>&1",
      "cat '/tmp/reqpack-cocoapods-install/project/Podfile'",
      "cat '/tmp/reqpack-cocoapods-install/project/Podfile'",
      "mkdir -p '/tmp/reqpack-cocoapods-install/project' && python3 -c \"import pathlib; pathlib.Path(\"/tmp/reqpack-cocoapods-install/project/Podfile\").write_text(\"target 'Demo' do\\n  pod 'Alamofire', '5.7.1'\\n  pod 'AFNetworking', '4.0.1'\\nend\\n\")\"",
      "HOME='/tmp/reqpack-cocoapods-install/home' CP_HOME_DIR='/tmp/reqpack-cocoapods-install/home/.cocoapods' COCOAPODS_DISABLE_STATS='true' COCOAPODS_SKIP_UPDATE_MESSAGE='true' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' pod install --project-directory=/tmp/reqpack-cocoapods-install/project --no-ansi"
    },
    events = { "installed", "success" },
  },
}
