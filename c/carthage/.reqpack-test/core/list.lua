return {
  name = "carthage list merged dependencies",
  request = {
    action = "list",
    system = "carthage",
    flags = {
      "dir=/tmp/reqpack-carthage-list/project",
      "home=/tmp/reqpack-carthage-list/home",
    },
  },
  fixtureDirs = {
    "/tmp/reqpack-carthage-list/project",
    "/tmp/reqpack-carthage-list/home",
  },
  fixtureFiles = {
    {
      path = "/tmp/reqpack-carthage-list/project/Cartfile",
      content = [[github "ReactiveCocoa/ReactiveCocoa" ~> 10.0
binary "https://example.com/MyFramework.json" ~> 1.2
]],
    },
    {
      path = "/tmp/reqpack-carthage-list/project/Cartfile.resolved",
      content = [[github "ReactiveCocoa/ReactiveCocoa" "10.1.0"
binary "https://example.com/MyFramework.json" "1.2.3"
]],
    },
  },
  fakeExec = {
    {
      match = "cat '/tmp/reqpack-carthage-list/project/Cartfile'",
      exitCode = 0,
      stdout = "github \"ReactiveCocoa/ReactiveCocoa\" ~> 10.0\nbinary \"https://example.com/MyFramework.json\" ~> 1.2\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/reqpack-carthage-list/project/Cartfile.resolved'",
      exitCode = 0,
      stdout = "github \"ReactiveCocoa/ReactiveCocoa\" \"10.1.0\"\nbinary \"https://example.com/MyFramework.json\" \"1.2.3\"\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 2,
    resultName = "ReactiveCocoa",
    resultVersion = "\"10.1.0\"",
    events = { "listed" },
  },
}
