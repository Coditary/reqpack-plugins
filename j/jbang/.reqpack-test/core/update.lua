return {
  name = "jbang update installed app via reinstall",
  request = {
    action = "update",
    system = "jbang",
    packages = {
      { action = "update", name = "gavsearch" }
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
      match = "cat \"${JBANG_DIR:-$HOME/.jbang}/bin/\"'gavsearch'",
      exitCode = 0,
      stdout = "#!/bin/sh\nexec jbang run gavsearch@jbangdev \"$@\"\n",
      stderr = "",
      success = true,
    },
    {
      match = "jbang app install --force --name 'gavsearch' 'gavsearch@jbangdev'",
      exitCode = 0,
      stdout = "updated\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "cat \"${JBANG_DIR:-$HOME/.jbang}/bin/\"'gavsearch'",
      "jbang app install --force --name 'gavsearch' 'gavsearch@jbangdev'",
    },
    stdout = {
      "#!/bin/sh\nexec jbang run gavsearch@jbangdev \"$@\"\n",
      "updated\n",
    },
    events = { "updated", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
