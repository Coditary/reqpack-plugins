return {
  name = "carthage outdated parse xcode warnings",
  request = {
    action = "outdated",
    system = "carthage",
    flags = {
      "dir=/tmp/reqpack-carthage-outdated/project",
      "home=/tmp/reqpack-carthage-outdated/home",
    },
  },
  fixtureDirs = {
    "/tmp/reqpack-carthage-outdated/project",
    "/tmp/reqpack-carthage-outdated/home",
  },
  fixtureFiles = {
    {
      path = "/tmp/reqpack-carthage-outdated/project/Cartfile",
      content = [[github "Alamofire/Alamofire" ~> 5.9
]],
    },
    {
      path = "/tmp/reqpack-carthage-outdated/project/Cartfile.resolved",
      content = [[github "Alamofire/Alamofire" "5.9.1"
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
      match = "HOME='/tmp/reqpack-carthage-outdated/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' carthage outdated --project-directory=/tmp/reqpack-carthage-outdated/project --xcode-warnings",
      exitCode = 0,
      stdout = "warning: Alamofire is out of date (5.9.1 -> 5.10.0) (Latest: 6.0.0)\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/reqpack-carthage-outdated/project/Cartfile'",
      exitCode = 0,
      stdout = "github \"Alamofire/Alamofire\" ~> 5.9\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/reqpack-carthage-outdated/project/Cartfile.resolved'",
      exitCode = 0,
      stdout = "github \"Alamofire/Alamofire\" \"5.9.1\"\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "Alamofire",
    resultVersion = "5.9.1",
    events = { "outdated" },
  },
}
