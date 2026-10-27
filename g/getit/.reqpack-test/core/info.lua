return {
  name = "getit info fallback to search",
  request = {
    action = "info",
    system = "getit",
    prompt = "VirtualTreeview_by_JamSoftware-13-8.3",
    flags = { "cache-root=${fixtureRoot}/CatalogRepository" },
  },
  fixtureRoot = "../fixtures-info",
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "${fixtureRoot}",
  },
  fixtureDirs = {
    "${fixtureRoot}/CatalogRepository/reqpack-getit",
  },
  fakeExec = {
    {
      match = "cat '${fixtureRoot}/CatalogRepository/reqpack-getit/installed-cache.json'",
      exitCode = 1,
      stdout = "",
      stderr = "cat: not found\n",
      success = false,
    },
    {
      match = "command -v 'GetItCmd.exe' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "'GetItCmd.exe' -l= -f=installed -s=name",
      exitCode = 0,
      stdout = "Skia4Delphi-6.1.0  Skia4Delphi  Skia4Delphi Team  2024-04-20\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '${fixtureRoot}/CatalogRepository/reqpack-getit/search-cache-VirtualTreeview_by_JamSoftware-13-8.3.json'",
      exitCode = 1,
      stdout = "",
      stderr = "cat: not found\n",
      success = false,
    },
    {
      match = "command -v 'GetItCmd.exe' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "'GetItCmd.exe' -l=VirtualTreeview_by_JamSoftware-13-8.3 -f=all -s=name",
      exitCode = 0,
      stdout = "VirtualTreeview_by_JamSoftware-13-8.3  Virtual Treeview  Jam Software  2024-05-03\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "Virtual Treeview",
    resultVersion = "13-8.3",
    events = { "informed" },
  },
}
