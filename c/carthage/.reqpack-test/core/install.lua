return {
  name = "carthage install github dependency",
  request = {
    action = "install",
    system = "carthage",
    flags = {
      "dir=/tmp/reqpack-carthage-install/project",
      "home=/tmp/reqpack-carthage-install/home",
      "use-xcframeworks",
    },
    packages = {
      { name = "Alamofire/Alamofire", version = "~> 5.9" }
    },
  },
  fixtureDirs = {
    "/tmp/reqpack-carthage-install/project",
    "/tmp/reqpack-carthage-install/home",
  },
  fixtureFiles = {
    {
      path = "/tmp/reqpack-carthage-install/project/Cartfile",
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
      match = "cat '/tmp/reqpack-carthage-install/project/Cartfile'",
      exitCode = 0,
      stdout = "github \"ReactiveCocoa/ReactiveCocoa\" ~> 10.0\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/reqpack-carthage-install/project' && python3 -c \"import pathlib; pathlib.Path(\"/tmp/reqpack-carthage-install/project/Cartfile\").write_text(\"github \\\"ReactiveCocoa/ReactiveCocoa\\\" ~> 10.0\\n\\ngithub \\\"Alamofire/Alamofire\\\" ~> 5.9\\n\")\"",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "HOME='/tmp/reqpack-carthage-install/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' carthage update --project-directory=/tmp/reqpack-carthage-install/project --use-xcframeworks",
      exitCode = 0,
      stdout = "*** Fetching Alamofire\n*** Checking out Alamofire\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'carthage' >/dev/null 2>&1",
      "cat '/tmp/reqpack-carthage-install/project/Cartfile'",
      "cat '/tmp/reqpack-carthage-install/project/Cartfile'",
      "mkdir -p '/tmp/reqpack-carthage-install/project' && python3 -c \"import pathlib; pathlib.Path(\"/tmp/reqpack-carthage-install/project/Cartfile\").write_text(\"github \\\"ReactiveCocoa/ReactiveCocoa\\\" ~> 10.0\\n\\ngithub \\\"Alamofire/Alamofire\\\" ~> 5.9\\n\")\"",
      "HOME='/tmp/reqpack-carthage-install/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' carthage update --project-directory=/tmp/reqpack-carthage-install/project --use-xcframeworks"
    },
    events = { "installed", "success" },
  },
}
