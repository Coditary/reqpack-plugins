return {
  name = "hbmk2 install tracked packages",
  request = {
    action = "install",
    system = "hbmk2",
    flags = {
      "data-root=${fixtureRoot}/cache"
    },
    packages = {
      { name = "hbct" },
      { name = "hbtip.hbc" }
    },
  },
  fixtureDirs = {
    "${fixtureRoot}/cache"
  },
  fakeExec = {
    {
      match = "command -v 'hbmk2' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat '${fixtureRoot}/cache/tracked-packages.txt'",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "NO_COLOR=1 HB_LANG=en LC_ALL=C LANG=C LANGUAGE=C 'hbmk2' '-hbcontainer' '-quiet' '-workdir=${fixtureRoot}/cache/workdir' 'hbct.hbc' 'hbtip.hbc' '--hbinfo'",
      exitCode = 0,
      stdout = [[{"targetname":"container","targettype":"hbcontainer","outputname":"container","hbctree":"${fixtureRoot}/hb/hbct.hbc\n${fixtureRoot}/hb/hbtip.hbc\n"}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'hbmk2' >/dev/null 2>&1",
      "cat '${fixtureRoot}/cache/tracked-packages.txt'",
      "NO_COLOR=1 HB_LANG=en LC_ALL=C LANG=C LANGUAGE=C 'hbmk2' '-hbcontainer' '-quiet' '-workdir=${fixtureRoot}/cache/workdir' 'hbct.hbc' 'hbtip.hbc' '--hbinfo'",
    },
    events = { "installed", "success" },
  }
}
