return {
  name = "hbmk2 search function providers",
  request = {
    action = "search",
    system = "hbmk2",
    prompt = "tip",
    flags = {
      "data-root=${fixtureRoot}/cache"
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
      match = "NO_COLOR=1 HB_LANG=en LC_ALL=C LANG=C LANGUAGE=C 'hbmk2' '-find' 'tip'",
      exitCode = 0,
      stdout = "hbtip.hbc (installed):\n   TipClient()\n   TipServer()\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "hbtip",
  }
}
