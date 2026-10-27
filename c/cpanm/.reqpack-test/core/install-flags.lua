return {
  name = "cpanm install with version range and flags",
  request = {
    action = "install",
    system = "cpanm",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    packages = {
      {
        name = "Plack",
        flags = {
          "version-range=>= 1.0, < 2.0",
          "dev",
          "self-contained",
          "skip-installed",
        },
      }
    },
  },
  fakeExec = {
    {
      match = "command -v cpanm >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p ${fixtureRoot}/.reqpack-data ${fixtureRoot}/.reqpack-data/home ${fixtureRoot}/.reqpack-data/cpan-home ${fixtureRoot}/.reqpack-data/cpanm-home ${fixtureRoot}/.reqpack-data/perl5 ${fixtureRoot}/.reqpack-data/perl5/lib/perl5 ${fixtureRoot}/.reqpack-data/perl5/bin",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "PERL_CPANM_HOME=${fixtureRoot}/.reqpack-data/cpanm-home PERL_MM_OPT=INSTALL_BASE=${fixtureRoot}/.reqpack-data/perl5 PERL_MB_OPT='--install_base ${fixtureRoot}/.reqpack-data/perl5' PERL5LIB=${fixtureRoot}/.reqpack-data/perl5/lib/perl5 PATH=${fixtureRoot}/.reqpack-data/perl5/bin:$PATH AUTOMATED_TESTING=1 NONINTERACTIVE_TESTING=1 PERL_MM_USE_DEFAULT=1 cpanm --dev --self-contained --skip-installed 'Plack~>= 1.0, < 2.0'",
      exitCode = 0,
      stdout = "Installed ranged Plack\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
