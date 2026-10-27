return {
  name = "conan install remote recipe",
  request = {
    action = "install",
    system = "conan",
    packages = {
      { name = "zlib/1.3.1", flags = { "remote=conancenter" } }
    },
  },
  fixtureRoot = "../fixtures-install",
  fixtureDirs = {
    "cache/include",
    "cache/lib",
  },
  fixtureFiles = {
    { path = "cache/include/zlib.h", content = "#pragma once\n" },
    { path = "cache/lib/libz.a", content = "fake-z\n" },
  },
  environment = {
    XDG_DATA_HOME = "${fixtureRoot}/data",
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    {
      match = "command -v 'conan' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "'conan' 'remote' 'list' '--format=json'",
      exitCode = 0,
      stdout = [=[[{"name":"conancenter","url":"https://center2.conan.io","enabled":true}]]=],
      stderr = "",
      success = true,
    },
    {
      match = "'conan' 'download' '--format=json' '-r' 'conancenter' 'zlib/1.3.1'",
      exitCode = 0,
      stdout = [[{"conancenter":{"zlib/1.3.1":{"revisions":{"abc123":{}}}}}]],
      stderr = "",
      success = true,
    },
    {
      match = "'conan' 'cache' 'path' '--format=json' 'zlib/1.3.1'",
      exitCode = 0,
      stdout = [[{"cache_path":"${fixtureRoot}/cache","folder":"package","reference":"zlib/1.3.1"}]],
      stderr = "",
      success = true,
    },
    {
      match = "find '${fixtureRoot}/cache' -type f -printf '%P\\n'",
      exitCode = 0,
      stdout = "include/zlib.h\nlib/libz.a\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "date -u +%Y-%m-%dT%H:%M:%SZ",
      exitCode = 0,
      stdout = "2026-05-30T12:00:00Z\n",
      stderr = "",
      success = true,
    },
    {
      match = "ln '",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "sha256sum '",
      exitCode = 0,
      stdout = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb  file\n",
      stderr = "",
      success = true,
    },
    {
      match = "stat -c %s '",
      exitCode = 0,
      stdout = "8\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
