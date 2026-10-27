return {
  name = "inform7 install local extension file",
  request = {
    action = "install",
    system = "inform7",
    localPath = "${fixtureRoot}/downloads/Locksmith.i7x",
    flags = {
      "data-root=${fixtureRoot}/cache"
    },
  },
  fixtureDirs = {
    "${fixtureRoot}/downloads",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/downloads/Locksmith.i7x",
      content = "Version 12 of Locksmith by Emily Short begins here.\n",
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
      match = "mkdir -p '${fixtureRoot}/cache' '${fixtureRoot}/cache/external' '${fixtureRoot}/cache/external/Extensions' '${fixtureRoot}/cache/tmp'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -e '${fixtureRoot}/downloads/Locksmith.i7x'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL=C LANG=C LANGUAGE=C 'inbuild' '-external' '${fixtureRoot}/cache/external' '-inspect' '-json' '-' '${fixtureRoot}/downloads/Locksmith.i7x'",
      exitCode = 0,
      stdout = [[{"inspection":[{"resource":{"type":"extension","title":"Locksmith","author":"Emily Short","version":"12"},"location-file":"${fixtureRoot}/downloads/Locksmith.i7x"}]}]],
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL=C LANG=C LANGUAGE=C 'inbuild' '-external' '${fixtureRoot}/cache/external' '-sync-to' '${fixtureRoot}/cache/external' '${fixtureRoot}/downloads/Locksmith.i7x'",
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
    commands = {
      "command -v 'inbuild' >/dev/null 2>&1",
      "mkdir -p '${fixtureRoot}/cache' '${fixtureRoot}/cache/external' '${fixtureRoot}/cache/external/Extensions' '${fixtureRoot}/cache/tmp'",
      "test -e '${fixtureRoot}/downloads/Locksmith.i7x'",
      "LC_ALL=C LANG=C LANGUAGE=C 'inbuild' '-external' '${fixtureRoot}/cache/external' '-inspect' '-json' '-' '${fixtureRoot}/downloads/Locksmith.i7x'",
      "LC_ALL=C LANG=C LANGUAGE=C 'inbuild' '-external' '${fixtureRoot}/cache/external' '-sync-to' '${fixtureRoot}/cache/external' '${fixtureRoot}/downloads/Locksmith.i7x'",
      "test -d '${fixtureRoot}/cache/external/Extensions'",
      "LC_ALL=C LANG=C LANGUAGE=C 'inbuild' '-external' '${fixtureRoot}/cache/external' '-inspect' '-recursive' '-contents-of' '${fixtureRoot}/cache/external/Extensions' '-json' '-'",
    },
    events = { "installed", "success" },
  },
}
