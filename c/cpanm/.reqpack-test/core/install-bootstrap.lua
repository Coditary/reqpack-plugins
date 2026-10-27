return {
  name = "cpanm bootstrap via cpan",
  request = {
    action = "install",
    system = "cpanm",
    flags = { "data-root=${fixtureRoot}/.reqpack-data", "bootstrap" },
    packages = {
      { name = "Plack" }
    },
  },
  fixtureDirs = {
    ".reqpack-data/perl5/bin",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/perl5/bin/cpanm",
      content = "#!/bin/sh\nexit 0\n",
    },
  },
  fakeExec = {
    {
      match = "command -v cpanm >/dev/null 2>&1",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "test -x ${fixtureRoot}/.reqpack-data/perl5/bin/cpanm",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "mkdir -p ${fixtureRoot}/.reqpack-data ${fixtureRoot}/.reqpack-data/home ${fixtureRoot}/.reqpack-data/cpan-home ${fixtureRoot}/.reqpack-data/cpanm-home ${fixtureRoot}/.reqpack-data/perl5 ${fixtureRoot}/.reqpack-data/perl5/lib/perl5 ${fixtureRoot}/.reqpack-data/perl5/bin",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "command -v cpan >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "HOME=${fixtureRoot}/.reqpack-data/home PERL_CPAN_HOME=${fixtureRoot}/.reqpack-data/cpan-home PERL_MM_OPT=INSTALL_BASE=${fixtureRoot}/.reqpack-data/perl5 PERL_MB_OPT='--install_base ${fixtureRoot}/.reqpack-data/perl5' PERL5LIB=${fixtureRoot}/.reqpack-data/perl5/lib/perl5 PATH=${fixtureRoot}/.reqpack-data/perl5/bin:$PATH AUTOMATED_TESTING=1 NONINTERACTIVE_TESTING=1 PERL_MM_USE_DEFAULT=1 cpan -T -i App::cpanminus",
      exitCode = 0,
      stdout = "Installing App::cpanminus\n",
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
      match = "PERL_CPANM_HOME=${fixtureRoot}/.reqpack-data/cpanm-home PERL_MM_OPT=INSTALL_BASE=${fixtureRoot}/.reqpack-data/perl5 PERL_MB_OPT='--install_base ${fixtureRoot}/.reqpack-data/perl5' PERL5LIB=${fixtureRoot}/.reqpack-data/perl5/lib/perl5 PATH=${fixtureRoot}/.reqpack-data/perl5/bin:$PATH AUTOMATED_TESTING=1 NONINTERACTIVE_TESTING=1 PERL_MM_USE_DEFAULT=1 ${fixtureRoot}/.reqpack-data/perl5/bin/cpanm Plack",
      exitCode = 0,
      stdout = "Installed Plack\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
