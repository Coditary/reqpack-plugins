return {
  name = "getit list installed packages",
  request = {
    action = "list",
    system = "getit",
    flags = { "cache-root=${fixtureRoot}/CatalogRepository" },
  },
  fixtureRoot = "../fixtures-list",
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
      match = "'GetItCmd.exe' -l= -f=installed -s=name",
      exitCode = 0,
      stdout = "ID  Name  Vendor  Date\nVirtualTreeview_by_JamSoftware-13-8.3  Virtual Treeview  Jam Software  2024-05-03\nSkia4Delphi-6.1.0  Skia4Delphi  Skia4Delphi Team  2024-04-20\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 2,
    resultName = "Virtual Treeview",
    resultVersion = "13-8.3",
    events = { "listed" },
  },
}
