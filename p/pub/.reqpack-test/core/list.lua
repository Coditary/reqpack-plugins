return {
  name = "pub list activated packages",
  request = {
    action = "list",
    system = "pub",
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
      stdout = "melos\nother-tool\n",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://pub.dev/api/packages/melos'",
      exitCode = 0,
      stdout = [=[{"name":"melos","latest":{"version":"6.3.3","archive_url":"https://storage.googleapis.com/pub-packages/packages/melos-6.3.3.tar.gz","archive_sha256":"abc123","pubspec":{"name":"melos","description":"Workspace management for Dart and Flutter projects.","homepage":"https://melos.invertase.dev","repository":"https://github.com/invertase/melos","license":"MIT","environment":{"sdk":">=3.0.0 <4.0.0"},"executables":{"melos":"melos"},"dependencies":{"yaml":"^3.1.0"}}}}]=],
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://pub.dev/api/packages/melos/score'",
      exitCode = 0,
      stdout = [=[{"grantedPoints":160,"maxPoints":160,"likeCount":420,"downloadCount30Days":500000,"tags":["sdk:dart","sdk:flutter","has:executable"]}]=],
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
    events = { "listed" },
  },
}
