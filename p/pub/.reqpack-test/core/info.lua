return {
  name = "pub info merges installed state",
  request = {
    action = "info",
    system = "pub",
    prompt = "melos",
  },
  fixtureDirs = {
    "/home/test/.cache/reqpack/pub/pub-cache/bin",
  },
  fakeExec = {
    {
      match = "command -v 'dart' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "PUB_CACHE='/home/test/.cache/reqpack/pub/pub-cache' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' dart 'pub' 'global' 'list'",
      exitCode = 0,
      stdout = "melos 6.3.2\n",
      stderr = "",
      success = true,
    },
    {
      match = "ls -1A '/home/test/.cache/reqpack/pub/pub-cache/bin'",
      exitCode = 0,
      stdout = "melos\n",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://pub.dev/api/packages/melos'",
      exitCode = 0,
      stdout = [=[{"name":"melos","latest":{"version":"6.3.3","pubspec":{"name":"melos","description":"Workspace management for Dart and Flutter projects.","homepage":"https://melos.invertase.dev","repository":"https://github.com/invertase/melos","license":"MIT","executables":{"melos":"melos"}}}}]=],
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://pub.dev/api/packages/melos/score'",
      exitCode = 0,
      stdout = [=[{"grantedPoints":160,"maxPoints":160,"likeCount":420,"downloadCount30Days":500000,"tags":["sdk:dart","has:executable"]}]=],
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://pub.dev/api/packages/melos/publisher'",
      exitCode = 0,
      stdout = [=[{"publisherId":"invertase.dev"}]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'dart' >/dev/null 2>&1",
      "PUB_CACHE='/home/test/.cache/reqpack/pub/pub-cache' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' dart 'pub' 'global' 'list'",
      "ls -1A '/home/test/.cache/reqpack/pub/pub-cache/bin'",
      "curl -fsSL 'https://pub.dev/api/packages/melos'",
      "curl -fsSL 'https://pub.dev/api/packages/melos/score'",
      "curl -fsSL 'https://pub.dev/api/packages/melos/publisher'"
    },
    resultCount = 1,
    resultName = "melos",
    resultVersion = "6.3.2",
    events = { "informed" },
  },
}
