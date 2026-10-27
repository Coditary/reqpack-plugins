return {
  name = "inform7 installLocal extension bundle",
  request = {
    action = "installLocal",
    system = "inform7",
    localPath = "${fixtureRoot}/downloads/Directorial Testing.i7xd",
    flags = {
      "data-root=${fixtureRoot}/cache"
    },
  },
  fixtureDirs = {
    "${fixtureRoot}/downloads/Directorial Testing.i7xd",
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
      match = "test -e '${fixtureRoot}/downloads/Directorial Testing.i7xd'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL=C LANG=C LANGUAGE=C 'inbuild' '-external' '${fixtureRoot}/cache/external' '-inspect' '-json' '-' '${fixtureRoot}/downloads/Directorial Testing.i7xd'",
      exitCode = 0,
      stdout = [[{"inspection":[{"resource":{"type":"extension","title":"Directorial Testing","author":"Araminta Intest","version":"2.7"},"location-directory":"${fixtureRoot}/downloads/Directorial Testing.i7xd"}]}]],
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL=C LANG=C LANGUAGE=C 'inbuild' '-external' '${fixtureRoot}/cache/external' '-sync-to' '${fixtureRoot}/cache/external' '${fixtureRoot}/downloads/Directorial Testing.i7xd'",
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
      stdout = [[{"inspection":[{"resource":{"type":"extension","title":"Directorial Testing","author":"Araminta Intest","version":"2.7"},"location-directory":"${fixtureRoot}/cache/external/Extensions/Araminta Intest/Directorial Testing-v2_7.i7xd"}]}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
