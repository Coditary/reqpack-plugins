return {
  name = "hbmk2 install local hbc",
  request = {
    action = "install",
    system = "hbmk2",
    flags = {
      "data-root=${fixtureRoot}/cache"
    },
    localPath = "${fixtureRoot}/local/custom.hbc",
  },
  fixtureDirs = {
    "${fixtureRoot}/cache",
    "${fixtureRoot}/local",
    "${fixtureRoot}/hb",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/local/custom.hbc",
      content = "name=custom\ndescription=Custom package\nversion=1.2.3\n",
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
      match = "test -e '${fixtureRoot}/local/custom.hbc'",
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
      match = "NO_COLOR=1 HB_LANG=en LC_ALL=C LANG=C LANGUAGE=C 'hbmk2' '-hbcontainer' '-quiet' '-workdir=${fixtureRoot}/cache/workdir' '${fixtureRoot}/local/custom.hbc' '--hbinfo'",
      exitCode = 0,
      stdout = [[{"targetname":"container","targettype":"hbcontainer","outputname":"container","hbctree":"${fixtureRoot}/local/custom.hbc\n"}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
