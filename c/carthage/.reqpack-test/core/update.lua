return {
  name = "carthage update dependency requirement",
  request = {
    action = "update",
    system = "carthage",
    flags = {
      "dir=/tmp/reqpack-carthage-update/project",
      "home=/tmp/reqpack-carthage-update/home",
      "cache-builds",
    },
    packages = {
      { name = "Alamofire/Alamofire", version = "~> 5.10" }
    },
  },
  fixtureDirs = {
    "/tmp/reqpack-carthage-update/project",
    "/tmp/reqpack-carthage-update/home",
  },
  fixtureFiles = {
    {
      path = "/tmp/reqpack-carthage-update/project/Cartfile",
      content = [[github "Alamofire/Alamofire" ~> 5.9
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
      match = "cat '/tmp/reqpack-carthage-update/project/Cartfile'",
      exitCode = 0,
      stdout = "github \"Alamofire/Alamofire\" ~> 5.9\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/reqpack-carthage-update/project' && python3 -c \"import pathlib; pathlib.Path(\"/tmp/reqpack-carthage-update/project/Cartfile\").write_text(\"github \\\"Alamofire/Alamofire\\\" ~> 5.10\\n\")\"",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "HOME='/tmp/reqpack-carthage-update/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' carthage update --project-directory=/tmp/reqpack-carthage-update/project --cache-builds",
      exitCode = 0,
      stdout = "*** Updating Alamofire\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  },
}
