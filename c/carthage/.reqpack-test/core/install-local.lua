return {
  name = "carthage install local binary spec",
  request = {
    action = "installLocal",
    system = "carthage",
    flags = {
      "dir=/tmp/reqpack-carthage-install-local/project",
      "home=/tmp/reqpack-carthage-install-local/home",
    },
    path = "/tmp/reqpack-carthage-install-local/MyFramework.json",
  },
  fixtureDirs = {
    "/tmp/reqpack-carthage-install-local/project",
    "/tmp/reqpack-carthage-install-local/home",
  },
  fixtureFiles = {
    {
      path = "/tmp/reqpack-carthage-install-local/project/Cartfile",
      content = [[github "ReactiveCocoa/ReactiveCocoa" ~> 10.0
]],
    },
  },
  fakeExec = {
    {
      match = "command -v 'carthage' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/reqpack-carthage-install-local/project/Cartfile'",
      exitCode = 0,
      stdout = "github \"ReactiveCocoa/ReactiveCocoa\" ~> 10.0\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/reqpack-carthage-install-local/project' && python3 -c \"import pathlib; pathlib.Path(\"/tmp/reqpack-carthage-install-local/project/Cartfile\").write_text(\"github \\\"ReactiveCocoa/ReactiveCocoa\\\" ~> 10.0\\n\\nbinary \\\"/tmp/reqpack-carthage-install-local/MyFramework.json\\\"\\n\")\"",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "HOME='/tmp/reqpack-carthage-install-local/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' carthage update --project-directory=/tmp/reqpack-carthage-install-local/project",
      exitCode = 0,
      stdout = "*** Fetching MyFramework\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
