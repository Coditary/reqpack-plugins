return {
  name = "gt install latest release",
  request = {
    action = "install",
    system = "gt",
    packages = {
      {
        action = "install",
        name = "genometools",
        flags = {
          "data-root=${fixtureRoot}/data",
          "cairo=no",
        },
      },
    },
  },
  fakeExec = {
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
      stdout = [=[[{"tag_name":"v1.6.4","name":"v1.6.4","tarball_url":"https://example.com/genometools-1.6.4.tar.gz","html_url":"https://github.com/genometools/genometools/releases/tag/v1.6.4","body":"bugfix"},{"tag_name":"v1.6.3","name":"v1.6.3","tarball_url":"https://example.com/genometools-1.6.3.tar.gz","html_url":"https://github.com/genometools/genometools/releases/tag/v1.6.3","body":"older"}]]=],
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/data' '${fixtureRoot}/data/downloads' '${fixtureRoot}/data/src' '${fixtureRoot}/data/installs'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -x '${fixtureRoot}/data/installs/1.6.4/bin/gt'",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "test -f '${fixtureRoot}/data/downloads/genometools-1.6.4.tar.gz'",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "curl -fL 'https://example.com/genometools-1.6.4.tar.gz' -o '${fixtureRoot}/data/downloads/genometools-1.6.4.tar.gz'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "rm -rf '${fixtureRoot}/data/src/genometools-1.6.4' && mkdir -p '${fixtureRoot}/data/src/genometools-1.6.4' && tar -xzf '${fixtureRoot}/data/downloads/genometools-1.6.4.tar.gz' -C '${fixtureRoot}/data/src/genometools-1.6.4' --strip-components=1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cd '${fixtureRoot}/data/src/genometools-1.6.4' && make cairo=no",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cd '${fixtureRoot}/data/src/genometools-1.6.4' && make prefix='${fixtureRoot}/data/installs/1.6.4' cairo=no install",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
