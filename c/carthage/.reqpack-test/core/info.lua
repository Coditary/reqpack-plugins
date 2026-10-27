return {
  name = "carthage info dependency",
  request = {
    action = "info",
    system = "carthage",
    flags = {
      "dir=/tmp/reqpack-carthage-info/project",
    },
    prompt = "ReactiveCocoa",
  },
  fixtureDirs = {
    "/tmp/reqpack-carthage-info/project",
  },
  fixtureFiles = {
    {
      path = "/tmp/reqpack-carthage-info/project/Cartfile",
      content = [[github "ReactiveCocoa/ReactiveCocoa" ~> 10.0
]],
    },
    {
      path = "/tmp/reqpack-carthage-info/project/Cartfile.resolved",
      content = [[github "ReactiveCocoa/ReactiveCocoa" "10.1.0"
]],
    },
  },
  fakeExec = {
    {
      match = "cat '/tmp/reqpack-carthage-info/project/Cartfile'",
      exitCode = 0,
      stdout = "github \"ReactiveCocoa/ReactiveCocoa\" ~> 10.0\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/reqpack-carthage-info/project/Cartfile.resolved'",
      exitCode = 0,
      stdout = "github \"ReactiveCocoa/ReactiveCocoa\" \"10.1.0\"\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultName = "ReactiveCocoa",
    resultVersion = "\"10.1.0\"",
    events = { "informed" },
  },
}
