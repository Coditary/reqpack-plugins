return {
  name = "vcpkg targeted update package",
  request = {
    action = "update",
    system = "vcpkg",
    packages = {
      { action = "update", name = "zlib:x64-linux" }
    },
  },
  fixtureRoot = "../fixtures-update",
  fixtureDirs = {
    "root/installed/x64-linux/include",
  },
  fixtureFiles = {
    { path = "root/installed/x64-linux/include/zlib.h", content = "#pragma once\n" },
  },
  environment = {
    VCPKG_ROOT = "${fixtureRoot}/root",
    XDG_DATA_HOME = "${fixtureRoot}/data",
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    {
      match = "command -v vcpkg 2>/dev/null",
      exitCode = 0,
      stdout = "/usr/local/bin/vcpkg\n",
      stderr = "",
      success = true,
    },
    {
      match = "VSLANG=1033 LC_ALL=C LANG=C LANGUAGE=C /usr/local/bin/vcpkg install --classic --recurse zlib:x64-linux",
      exitCode = 0,
      stdout = "Updating package zlib:x64-linux\n",
      stderr = "",
      success = true,
    },
    {
      match = "command -v vcpkg 2>/dev/null",
      exitCode = 0,
      stdout = "/usr/local/bin/vcpkg\n",
      stderr = "",
      success = true,
    },
    {
      match = "VSLANG=1033 LC_ALL=C LANG=C LANGUAGE=C /usr/local/bin/vcpkg x-package-info --x-json --x-installed zlib:x64-linux",
      exitCode = 0,
      stdout = [[{"results":{"zlib:x64-linux":{"name":"zlib","version-string":"1.3.1","triplet":"x64-linux","abi":"abi123","owns":["x64-linux/include/zlib.h"]}}}]],
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
      stdout = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa  file\n",
      stderr = "",
      success = true,
    },
    {
      match = "stat -c %s '",
      exitCode = 0,
      stdout = "12\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  }
}
