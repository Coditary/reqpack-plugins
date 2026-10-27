return {
  name = "cpan list installed modules",
  request = {
    action = "list",
    system = "cpan",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
  },
  fakeExec = {
    {
      match = "command -v cpan >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "HOME=${fixtureRoot}/.reqpack-data/home PERL_CPAN_HOME=${fixtureRoot}/.reqpack-data/cpan-home PERL_MM_OPT=INSTALL_BASE=${fixtureRoot}/.reqpack-data/perl5 PERL_MB_OPT='--install_base ${fixtureRoot}/.reqpack-data/perl5' PERL5LIB=${fixtureRoot}/.reqpack-data/perl5/lib/perl5 PATH=${fixtureRoot}/.reqpack-data/perl5/bin:$PATH AUTOMATED_TESTING=1 NONINTERACTIVE_TESTING=1 PERL_MM_USE_DEFAULT=1 cpan -l",
      exitCode = 0,
      stdout = "Try::Tiny\t0.32\nType::Tiny 2.008000\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 2,
    resultName = "Try::Tiny",
    resultVersion = "0.32",
    events = { "listed" },
  }
}
