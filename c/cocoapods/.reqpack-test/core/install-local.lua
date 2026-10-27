return {
  name = "cocoapods install local podspec",
  request = {
    action = "install",
    system = "cocoapods",
    flags = {
      "dir=/tmp/reqpack-cocoapods-install-local/project",
      "home=/tmp/reqpack-cocoapods-install-local/home",
    },
    localPath = "/tmp/LocalKit.podspec",
  },
  fixtureDirs = {
    "/tmp/reqpack-cocoapods-install-local/project",
    "/tmp/reqpack-cocoapods-install-local/home",
  },
  fixtureFiles = {
    {
      path = "/tmp/reqpack-cocoapods-install-local/project/Podfile",
      content = [[target 'Demo' do
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
      match = "cat '/tmp/reqpack-cocoapods-install-local/project/Podfile'",
      exitCode = 0,
      stdout = "target 'Demo' do\nend\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/reqpack-cocoapods-install-local/project' && python3 -c \"import pathlib; pathlib.Path(\"/tmp/reqpack-cocoapods-install-local/project/Podfile\").write_text(\"target 'Demo' do\\n  pod 'LocalKit', :podspec => '/tmp/LocalKit.podspec'\\nend\\n\")\"",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "HOME='/tmp/reqpack-cocoapods-install-local/home' CP_HOME_DIR='/tmp/reqpack-cocoapods-install-local/home/.cocoapods' COCOAPODS_DISABLE_STATS='true' COCOAPODS_SKIP_UPDATE_MESSAGE='true' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' pod ipc spec /tmp/LocalKit.podspec --no-ansi",
      exitCode = 0,
      stdout = [[{"name":"LocalKit","version":"1.0.0","summary":"Local kit"}]],
      stderr = "",
      success = true,
    },
    {
      match = "HOME='/tmp/reqpack-cocoapods-install-local/home' CP_HOME_DIR='/tmp/reqpack-cocoapods-install-local/home/.cocoapods' COCOAPODS_DISABLE_STATS='true' COCOAPODS_SKIP_UPDATE_MESSAGE='true' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' pod install --project-directory=/tmp/reqpack-cocoapods-install-local/project --no-ansi",
      exitCode = 0,
      stdout = "Analyzing dependencies\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'pod' >/dev/null 2>&1",
      "cat '/tmp/reqpack-cocoapods-install-local/project/Podfile'",
      "HOME='/tmp/reqpack-cocoapods-install-local/home' CP_HOME_DIR='/tmp/reqpack-cocoapods-install-local/home/.cocoapods' COCOAPODS_DISABLE_STATS='true' COCOAPODS_SKIP_UPDATE_MESSAGE='true' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' pod ipc spec /tmp/LocalKit.podspec --no-ansi",
      "cat '/tmp/reqpack-cocoapods-install-local/project/Podfile'",
      "mkdir -p '/tmp/reqpack-cocoapods-install-local/project' && python3 -c \"import pathlib; pathlib.Path(\"/tmp/reqpack-cocoapods-install-local/project/Podfile\").write_text(\"target 'Demo' do\\n  pod 'LocalKit', :podspec => '/tmp/LocalKit.podspec'\\nend\\n\")\"",
      "HOME='/tmp/reqpack-cocoapods-install-local/home' CP_HOME_DIR='/tmp/reqpack-cocoapods-install-local/home/.cocoapods' COCOAPODS_DISABLE_STATS='true' COCOAPODS_SKIP_UPDATE_MESSAGE='true' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' pod install --project-directory=/tmp/reqpack-cocoapods-install-local/project --no-ansi"
    },
    events = { "installed", "success" },
  },
}
