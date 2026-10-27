return {
  name = "jbang remove installed app",
  request = {
    action = "remove",
    system = "jbang",
    packages = {
      { action = "remove", name = "gavsearch" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'jbang' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "jbang app list --format json",
      exitCode = 0,
      stdout = [=[[{"name":"gavsearch"}]]=],
      stderr = "",
      success = true,
    },
    {
      match = "jbang app uninstall 'gavsearch'",
      exitCode = 0,
      stdout = "removed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = { "jbang app uninstall 'gavsearch'" },
    stdout = { "removed\n" },
    events = { "deleted", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
