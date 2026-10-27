return {
  name = "gt search releases",
  request = {
    action = "search",
    system = "gt",
    prompt = "1.6",
    flags = {
      "data-root=${fixtureRoot}/data",
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
      stdout = [=[[{"tag_name":"v1.6.4","name":"v1.6.4","tarball_url":"https://example.com/genometools-1.6.4.tar.gz","html_url":"https://github.com/genometools/genometools/releases/tag/v1.6.4","body":"bugfix"},{"tag_name":"v1.6.3","name":"v1.6.3","tarball_url":"https://example.com/genometools-1.6.3.tar.gz","html_url":"https://github.com/genometools/genometools/releases/tag/v1.6.3","body":"older"},{"tag_name":"v1.5.9","name":"v1.5.9","tarball_url":"https://example.com/genometools-1.5.9.tar.gz","html_url":"https://github.com/genometools/genometools/releases/tag/v1.5.9","body":"legacy"}]]=],
      stderr = "",
      success = true,
    },
    {
      match = "if [ -d '${fixtureRoot}/data/installs' ]; then ls -1 '${fixtureRoot}/data/installs'; fi",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "gt",
    resultVersion = "1.6.4",
  }
}
