return {
  name = "gt list managed installs",
  fixtureDirs = {
    "data/installs/1.6.3/bin",
    "data/installs/1.6.4/bin",
  },
  fixtureFiles = {
    {
      path = "data/installs/1.6.3/bin/gt",
      content = "binary",
    },
    {
      path = "data/installs/1.6.4/bin/gt",
      content = "binary",
    },
  },
  request = {
    action = "list",
    system = "gt",
    flags = {
      "data-root=${fixtureRoot}/data",
    },
  },
  fakeExec = {
    {
      match = "if [ -d '${fixtureRoot}/data/installs' ]; then ls -1 '${fixtureRoot}/data/installs'; fi",
      exitCode = 0,
      stdout = "1.6.3\n1.6.4\n",
      stderr = "",
      success = true,
    },
    {
      match = "test -x '${fixtureRoot}/data/installs/1.6.3/bin/gt'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -x '${fixtureRoot}/data/installs/1.6.4/bin/gt'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'tar' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'make' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'curl' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://api.github.com/repos/genometools/genometools/releases?per_page=100'",
      exitCode = 0,
      stdout = [=[[{"tag_name":"v1.6.4","name":"v1.6.4","tarball_url":"https://example.com/genometools-1.6.4.tar.gz","html_url":"https://github.com/genometools/genometools/releases/tag/v1.6.4","body":"bugfix"}]]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "gt",
    resultVersion = "1.6.3",
  }
}
