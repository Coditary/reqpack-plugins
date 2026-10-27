return {
  name = "hbmk2 info resolves hbc metadata",
  request = {
    action = "info",
    system = "hbmk2",
    prompt = "hbct",
    flags = {
      "data-root=${fixtureRoot}/cache"
    },
  },
  fixtureDirs = {
    "${fixtureRoot}/cache",
    "${fixtureRoot}/hb"
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/cache/tracked-packages.txt",
      content = "hbct.hbc\n",
    },
    {
      path = "${fixtureRoot}/hb/hbct.hbc",
      content = "name=hbct\ndescription=Harbour CT library\nversion=3.2.0\nhbcs=rtl vm\n",
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
      stdout = "hbct.hbc\n",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 HB_LANG=en LC_ALL=C LANG=C LANGUAGE=C 'hbmk2' '-hbcontainer' '-quiet' '-workdir=${fixtureRoot}/cache/workdir' 'hbct.hbc' '--hbinfo'",
      exitCode = 0,
      stdout = [[{"targetname":"container","targettype":"hbcontainer","outputname":"container","hbctree":"${fixtureRoot}/hb/hbct.hbc\n"}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat '${fixtureRoot}/hb/hbct.hbc'",
      exitCode = 0,
      stdout = "name=hbct\ndescription=Harbour CT library\nversion=3.2.0\nhbcs=rtl vm\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultName = "hbct",
    resultVersion = "3.2.0",
  }
}
