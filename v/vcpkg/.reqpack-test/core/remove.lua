return {
  name = "vcpkg remove package",
  request = {
    action = "remove",
    system = "vcpkg",
    packages = {
      { action = "remove", name = "zlib:x64-linux" }
    },
  },
  fixtureRoot = "../fixtures-remove",
  fixtureFiles = {
    {
      path = "data/cppcache/views/by-source/vcpkg/zlib__x64-linux/current.json",
      content = [[{"artifact_id":"vcpkg/cpp-package/zlib__x64-linux@abi123","artifact_path":"${fixtureRoot}/data/cppcache/artifacts/vcpkg/cpp-package/zlib__x64-linux@abi123","prefix_path":"${fixtureRoot}/data/cppcache/prefixes/vcpkg/cpp-package/zlib__x64-linux@abi123","source_path":"${fixtureRoot}/root/installed"}]],
    },
  },
  environment = {
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
      match = "VSLANG=1033 LC_ALL=C LANG=C LANGUAGE=C /usr/local/bin/vcpkg x-package-info --x-json --x-installed zlib:x64-linux",
      exitCode = 0,
      stdout = [[{"results":{"zlib:x64-linux":{"name":"zlib","version-string":"1.3.1","triplet":"x64-linux","abi":"abi123","owns":["x64-linux/include/zlib.h"]}}}]],
      stderr = "",
      success = true,
    },
    {
      match = "VSLANG=1033 LC_ALL=C LANG=C LANGUAGE=C /usr/local/bin/vcpkg remove --classic --recurse zlib:x64-linux",
      exitCode = 0,
      stdout = "Removing package zlib:x64-linux\n",
      stderr = "",
      success = true,
    },
    {
      match = "rm -rf '",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  }
}
