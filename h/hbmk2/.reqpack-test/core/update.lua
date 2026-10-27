return {
  name = "hbmk2 update revalidates tracked package",
  request = {
    action = "update",
    system = "hbmk2",
    flags = {
      "data-root=${fixtureRoot}/cache"
    },
    packages = {
      { name = "hbct" }
    },
  },
  fixtureDirs = {
    "${fixtureRoot}/cache"
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/cache/tracked-packages.txt",
      content = "hbtip.hbc\n",
    },
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
      exitCode = 0,
      stdout = "hbtip.hbc\n",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 HB_LANG=en LC_ALL=C LANG=C LANGUAGE=C 'hbmk2' '-hbcontainer' '-quiet' '-workdir=${fixtureRoot}/cache/workdir' 'hbtip.hbc' 'hbct.hbc' '--hbinfo'",
      exitCode = 0,
      stdout = [[{"targetname":"container","targettype":"hbcontainer","outputname":"container","hbctree":"${fixtureRoot}/hb/hbtip.hbc\n${fixtureRoot}/hb/hbct.hbc\n"}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  }
}
