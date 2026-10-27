return {
  name = "carthage search current project dependencies",
  request = {
    action = "search",
    system = "carthage",
    flags = {
      "dir=/tmp/reqpack-carthage-search/project",
    },
    prompt = "alamo",
  },
  fixtureDirs = {
    "/tmp/reqpack-carthage-search/project",
  },
  fixtureFiles = {
    {
      path = "/tmp/reqpack-carthage-search/project/Cartfile",
      content = [[github "Alamofire/Alamofire" ~> 5.9
github "ReactiveCocoa/ReactiveCocoa" ~> 10.0
]],
    },
    {
      path = "/tmp/reqpack-carthage-search/project/Cartfile.resolved",
      content = [[github "Alamofire/Alamofire" "5.9.1"
github "ReactiveCocoa/ReactiveCocoa" "10.1.0"
]],
    },
  },
  fakeExec = {
    {
      match = "cat '/tmp/reqpack-carthage-search/project/Cartfile'",
      exitCode = 0,
      stdout = "github \"Alamofire/Alamofire\" ~> 5.9\ngithub \"ReactiveCocoa/ReactiveCocoa\" ~> 10.0\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/reqpack-carthage-search/project/Cartfile.resolved'",
      exitCode = 0,
      stdout = "github \"Alamofire/Alamofire\" \"5.9.1\"\ngithub \"ReactiveCocoa/ReactiveCocoa\" \"10.1.0\"\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "Alamofire",
    events = { "searched" },
  },
}
