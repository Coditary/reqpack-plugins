return {
  name = "inform7 search visible extensions",
  request = {
    action = "search",
    system = "inform7",
    prompt = "lock",
    flags = {
      "data-root=${fixtureRoot}/cache"
    },
  },
  fakeExec = {
    {
      match = "command -v 'inbuild' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -d '${fixtureRoot}/cache/external/Extensions'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL=C LANG=C LANGUAGE=C 'inbuild' '-external' '${fixtureRoot}/cache/external' '-inspect' '-recursive' '-contents-of' '${fixtureRoot}/cache/external/Extensions' '-json' '-'",
      exitCode = 0,
      stdout = [[{"inspection":[{"resource":{"type":"extension","title":"Locksmith","author":"Emily Short","version":"12"},"location-file":"${fixtureRoot}/cache/external/Extensions/Emily Short/Locksmith-v12.i7x"},{"resource":{"type":"extension","title":"Menus","author":"Emily Short","version":"3"},"location-file":"${fixtureRoot}/cache/external/Extensions/Emily Short/Menus-v3.i7x"}]}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "Locksmith",
    resultVersion = "12",
  },
}
