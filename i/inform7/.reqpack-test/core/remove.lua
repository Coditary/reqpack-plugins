return {
  name = "inform7 remove installed extension",
  request = {
    action = "remove",
    system = "inform7",
    packages = {
      { name = "Locksmith", author = "Emily Short" }
    },
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
    {
      match = "rm -f '${fixtureRoot}/cache/external/Extensions/Emily Short/Locksmith-v12.i7x'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'inbuild' >/dev/null 2>&1",
      "test -d '${fixtureRoot}/cache/external/Extensions'",
      "LC_ALL=C LANG=C LANGUAGE=C 'inbuild' '-external' '${fixtureRoot}/cache/external' '-inspect' '-recursive' '-contents-of' '${fixtureRoot}/cache/external/Extensions' '-json' '-'",
      "test -d '${fixtureRoot}/cache/external/Extensions'",
      "LC_ALL=C LANG=C LANGUAGE=C 'inbuild' '-external' '${fixtureRoot}/cache/external' '-inspect' '-recursive' '-contents-of' '${fixtureRoot}/cache/external/Extensions' '-json' '-'",
      "rm -f '${fixtureRoot}/cache/external/Extensions/Emily Short/Locksmith-v12.i7x'",
    },
    events = { "deleted", "success" },
  },
}
