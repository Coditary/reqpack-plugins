return {
  name = "jbang list installed apps",
  request = {
    action = "list",
    system = "jbang",
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
      match = "jbang alias list --format json",
      exitCode = 0,
      stdout = [=[[{"name":"gavsearch","catalogName":"jbangdev","fullName":"gavsearch@jbangdev","scriptRef":"gavsearch@jbangdev","description":"Search Maven artifacts"}]]=],
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
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 1,
    resultName = "gavsearch",
  }
}
