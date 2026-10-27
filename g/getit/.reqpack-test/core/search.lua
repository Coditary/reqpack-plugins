return {
  name = "getit search packages",
  request = {
    action = "search",
    system = "getit",
    prompt = "VirtualTree",
    flags = { "cache-root=${fixtureRoot}/CatalogRepository" },
  },
  fixtureRoot = "../fixtures-search",
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "${fixtureRoot}",
  },
  fixtureDirs = {
    "${fixtureRoot}/CatalogRepository/reqpack-getit",
  },
  fakeExec = {
    {
      match = "command -v 'GetItCmd.exe' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "'GetItCmd.exe' -l=VirtualTree -f=all -s=name",
      exitCode = 0,
      stdout = "VirtualTreeview_by_JamSoftware-13-8.3  Virtual Treeview  Jam Software  2024-05-03\nVirtualShellTools-10.0  Virtual Shell Tools  Mustangpeak  2024-03-01\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 2,
    resultName = "Virtual Treeview",
    resultVersion = "13-8.3",
    events = { "searched" },
  },
}
