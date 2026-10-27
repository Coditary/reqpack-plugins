return {
  name = "inform7 info installed extension",
  request = {
    action = "info",
    system = "inform7",
    prompt = "Locksmith by Emily Short",
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
      stdout = [[{"inspection":[{"resource":{"type":"extension","title":"Locksmith","author":"Emily Short","version":"12"},"location-file":"${fixtureRoot}/cache/external/Extensions/Emily Short/Locksmith-v12.i7x"}]}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultName = "Locksmith",
    resultVersion = "12",
  },
}
