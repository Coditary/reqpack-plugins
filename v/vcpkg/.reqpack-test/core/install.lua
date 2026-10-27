return {
  name = "vcpkg install package",
  request = {
    action = "install",
    system = "vcpkg",
    packages = {
      { name = "zlib", version = "1.3.1" }
    },
  },
  fixtureRoot = "../fixtures-install",
  fixtureDirs = {
    "root/installed/x64-linux/include",
    "root/installed/x64-linux/lib",
    "root/installed/x64-linux/share/zlib",
  },
  fixtureFiles = {
    { path = "root/installed/x64-linux/include/zlib.h", content = "#pragma once\n" },
    { path = "root/installed/x64-linux/lib/libz.a", content = "fake-libz\n" },
    { path = "root/installed/x64-linux/share/zlib/copyright", content = "zlib license\n" },
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
      match = "VSLANG=1033 LC_ALL=C LANG=C LANGUAGE=C /usr/local/bin/vcpkg install --classic --recurse zlib",
      exitCode = 0,
      stdout = "Installing package zlib\n",
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
      match = "VSLANG=1033 LC_ALL=C LANG=C LANGUAGE=C /usr/local/bin/vcpkg x-package-info --x-json zlib",
      exitCode = 0,
      stdout = [[{"results":{"zlib":{"name":"zlib","version-string":"1.3.1","description":"A compression library","homepage":"https://zlib.net","dependencies":[]}}}]],
      stderr = "",
      success = true,
    },
    {
      match = "VSLANG=1033 LC_ALL=C LANG=C LANGUAGE=C /usr/local/bin/vcpkg list --classic --x-full-desc",
      exitCode = 0,
      stdout = "zlib:x64-linux 1.3.1 A compression library\n",
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
      match = "VSLANG=1033 LC_ALL=C LANG=C LANGUAGE=C /usr/local/bin/vcpkg x-package-info --x-json zlib",
      exitCode = 0,
      stdout = [[{"results":{"zlib":{"name":"zlib","version-string":"1.3.1","description":"A compression library","homepage":"https://zlib.net","dependencies":[]}}}]],
      stderr = "",
      success = true,
    },
    {
      match = "VSLANG=1033 LC_ALL=C LANG=C LANGUAGE=C /usr/local/bin/vcpkg x-package-info --x-json --x-installed zlib:x64-linux",
      exitCode = 0,
      stdout = [[{"results":{"zlib:x64-linux":{"name":"zlib","version-string":"1.3.1","triplet":"x64-linux","abi":"abi123","owns":["x64-linux/include/zlib.h","x64-linux/lib/libz.a","x64-linux/share/zlib/copyright"]}}}]],
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
    events = { "installed", "success" },
  }
}
