return {
  name = "pinto info exact package",
  request = {
    action = "info",
    system = "pinto",
    prompt = "URI",
    flags = { "data-root=${fixtureRoot}/.reqpack-data", "stack=dev" },
  },
  fixtureDirs = {
    ".reqpack-data/repository/.pinto/config",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/repository/.pinto/config/pinto.ini",
      content = "[pinto]\n",
    },
  },
  fakeExec = {
    {
      match = "command -v 'pinto' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -f '${fixtureRoot}/.reqpack-data/repository/.pinto/config/pinto.ini'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "pinto --root '${fixtureRoot}/.reqpack-data/repository' 'list' '--all' '--packages' 'URI' '--format' '%p|^|%v|^|%a|^|%f|^|%y|^|%s|^|%d|^|%D|^|%V|^|%u|^|%S'",
      exitCode = 0,
      stdout = "URI|^|1.62|^|GAAS|^|URI-1.62.tar.gz|^|-|^|f|^|URI|^|URI-1.62|^|1.62|^|file:///repo/authors/id/G/GA/GAAS/URI-1.62.tar.gz|^|https://cpan.example.invalid\n",
      stderr = "",
      success = true,
    },
    {
      match = "pinto --root '${fixtureRoot}/.reqpack-data/repository' 'list' '--stack' 'dev' '--format' '%p|^|%v|^|%a|^|%f|^|%y|^|%s|^|%d|^|%D|^|%V|^|%u|^|%S' '--packages' 'URI'",
      exitCode = 0,
      stdout = "URI|^|1.62|^|GAAS|^|URI-1.62.tar.gz|^|!|^|f|^|URI|^|URI-1.62|^|1.62|^|file:///repo/authors/id/G/GA/GAAS/URI-1.62.tar.gz|^|https://cpan.example.invalid\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultName = "URI",
    resultVersion = "1.62",
    events = { "informed" },
  },
}
