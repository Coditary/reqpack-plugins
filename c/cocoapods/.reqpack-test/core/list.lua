return {
  name = "cocoapods list from project lockfile",
  request = {
    action = "list",
    system = "cocoapods",
    flags = {
      "dir=/tmp/reqpack-cocoapods-list/project",
    },
  },
  fixtureDirs = {
    "/tmp/reqpack-cocoapods-list/project",
  },
  fixtureFiles = {
    {
      path = "/tmp/reqpack-cocoapods-list/project/Podfile.lock",
      content = [[PODS:
  - AFNetworking (4.0.1)
  - Alamofire (5.7.1)

DEPENDENCIES:
  - AFNetworking (~> 4.0)
  - Alamofire

SPEC REPOS:
  trunk:
    - AFNetworking
    - Alamofire

COCOAPODS: 1.16.2
]],
    },
  },
  fakeExec = {
    {
      match = "cat '/tmp/reqpack-cocoapods-list/project/Podfile.lock'",
      exitCode = 0,
      stdout = "PODS:\n  - AFNetworking (4.0.1)\n  - Alamofire (5.7.1)\n\nDEPENDENCIES:\n  - AFNetworking (~> 4.0)\n  - Alamofire\n\nSPEC REPOS:\n  trunk:\n    - AFNetworking\n    - Alamofire\n\nCOCOAPODS: 1.16.2\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "cat '/tmp/reqpack-cocoapods-list/project/Podfile.lock'"
    },
    events = { "listed" },
    resultCount = 2,
    resultName = "AFNetworking",
    resultVersion = "4.0.1",
  },
}
