return {
  name = "pinto outdated packages via dry-run diff",
  request = {
    action = "outdated",
    system = "pinto",
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
      match = "pinto --root '${fixtureRoot}/.reqpack-data/repository' 'list' '--stack' 'dev' '--format' '%p|^|%v|^|%a|^|%f|^|%y|^|%s|^|%d|^|%D|^|%V|^|%u|^|%S'",
      exitCode = 0,
      stdout = "URI|^|1.60|^|GAAS|^|URI-1.60.tar.gz|^|-|^|f|^|URI|^|URI-1.60|^|1.60|^|file:///repo/authors/id/G/GA/GAAS/URI-1.60.tar.gz|^|https://cpan.example.invalid\nTry::Tiny|^|0.32|^|DOY|^|Try-Tiny-0.32.tar.gz|^|-|^|f|^|Try-Tiny|^|Try-Tiny-0.32|^|0.32|^|file:///repo/authors/id/D/DO/DOY/Try-Tiny-0.32.tar.gz|^|https://cpan.example.invalid\n",
      stderr = "",
      success = true,
    },
    {
      match = "PINTO_DIFF_STYLE=detailed pinto --root '${fixtureRoot}/.reqpack-data/repository' 'update' '--stack' 'dev' '--roots' '--dry-run' '--use-default-message'",
      exitCode = 0,
      stdout = "+URI|^|1.62|^|GAAS|^|URI-1.62.tar.gz\n-URI|^|1.60|^|GAAS|^|URI-1.60.tar.gz\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "URI",
    resultVersion = "1.60",
    events = { "outdated" },
  },
}
