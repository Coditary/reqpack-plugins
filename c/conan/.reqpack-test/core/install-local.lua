return {
  name = "conan install local recipe",
  request = {
    action = "install",
    system = "conan",
    localPath = "/tmp/demo-recipe",
  },
  fixtureDirs = {
    "/tmp/demo-recipe/include",
    "/tmp/demo-recipe/lib",
  },
  fixtureFiles = {
    { path = "/tmp/demo-recipe/include/demo.hpp", content = "#pragma once\n" },
    { path = "/tmp/demo-recipe/lib/libdemo.a", content = "fake-demo\n" },
  },
  environment = {
    XDG_DATA_HOME = "/tmp/reqpack-cppcache-data",
    HOME = "/tmp/reqpack-cppcache-home",
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
      match = "'conan' 'export' '--format=json' '/tmp/demo-recipe'",
      exitCode = 0,
      stdout = [=[Exported reqpackdemo
{"reference":"reqpackdemo/0.1#abc123"}]=],
      stderr = "",
      success = true,
    },
    {
      match = "find '/tmp/demo-recipe' -type f -printf '%P\\n'",
      exitCode = 0,
      stdout = "include/demo.hpp\nlib/libdemo.a\n",
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
      stdout = "10\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
