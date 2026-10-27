return {
  name = "carthage search github url query",
  request = {
    action = "search",
    system = "carthage",
    flags = {
      "dir=/tmp/reqpack-carthage-search-github-url/project",
    },
    prompt = "https://github.com/Alamofire/Alamofire",
  },
  fixtureDirs = {
    "/tmp/reqpack-carthage-search-github-url/project",
  },
  fixtureFiles = {
    {
      path = "/tmp/reqpack-carthage-search-github-url/project/Cartfile",
      content = [[github "Alamofire/Alamofire" ~> 5.9
]],
    },
    {
      path = "/tmp/reqpack-carthage-search-github-url/project/Cartfile.resolved",
      content = [[github "Alamofire/Alamofire" "5.9.1"
]],
    },
  },
  fakeExec = {
    {
      match = "cat '/tmp/reqpack-carthage-search-github-url/project/Cartfile'",
      exitCode = 0,
      stdout = "github \"Alamofire/Alamofire\" ~> 5.9\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/reqpack-carthage-search-github-url/project/Cartfile.resolved'",
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
    resultVersion = "\"5.9.1\"",
    events = { "searched" },
  },
}
