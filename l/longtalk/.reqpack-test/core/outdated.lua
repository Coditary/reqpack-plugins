return {
  name = "longtalk list outdated packs",
  request = {
    action = "outdated",
    system = "longtalk",
  },
  fakeExec = {
    {
      match = "command -v 'swilgt' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "forall(packs::outdated(Registry,Pack,Version,LatestVersion)",
      exitCode = 0,
      stdout = "REQPACK\tOUTDATED\ttalkshow\tlflat\t2:0:2\t2:1:0\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "lflat",
    resultVersion = "2:0:2",
  },
}
