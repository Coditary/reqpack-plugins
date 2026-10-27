return {
  name = "carthage remove dependency",
  request = {
    action = "remove",
    system = "carthage",
    flags = {
      "dir=/tmp/reqpack-carthage-remove/project",
      "home=/tmp/reqpack-carthage-remove/home",
    },
    packages = {
      { name = "Alamofire/Alamofire" }
    },
  },
  fixtureDirs = {
    "/tmp/reqpack-carthage-remove/project",
    "/tmp/reqpack-carthage-remove/home",
  },
  fixtureFiles = {
    {
      path = "/tmp/reqpack-carthage-remove/project/Cartfile",
      content = [[github "ReactiveCocoa/ReactiveCocoa" ~> 10.0
github "Alamofire/Alamofire" ~> 5.9
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
      match = "cat '/tmp/reqpack-carthage-remove/project/Cartfile'",
      exitCode = 0,
      stdout = "github \"ReactiveCocoa/ReactiveCocoa\" ~> 10.0\ngithub \"Alamofire/Alamofire\" ~> 5.9\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/reqpack-carthage-remove/project' && python3 -c \"import pathlib; pathlib.Path(\"/tmp/reqpack-carthage-remove/project/Cartfile\").write_text(\"github \\\"ReactiveCocoa/ReactiveCocoa\\\" ~> 10.0\\n\")\"",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "HOME='/tmp/reqpack-carthage-remove/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' carthage update --project-directory=/tmp/reqpack-carthage-remove/project",
      exitCode = 0,
      stdout = "*** Resolving dependencies\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  },
}
