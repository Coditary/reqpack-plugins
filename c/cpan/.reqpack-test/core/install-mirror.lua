return {
  name = "cpan install with mirrors and prefer",
  request = {
    action = "install",
    system = "cpan",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "mirror=https://cpan.metacpan.org",
      "mirror=https://cpan.org",
      "prefer-mirror",
    },
    packages = {
      { name = "Try::Tiny" }
    },
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
      match = "mkdir -p ${fixtureRoot}/.reqpack-data ${fixtureRoot}/.reqpack-data/home ${fixtureRoot}/.reqpack-data/cpan-home ${fixtureRoot}/.reqpack-data/perl5 ${fixtureRoot}/.reqpack-data/perl5/lib/perl5 ${fixtureRoot}/.reqpack-data/perl5/bin",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "HOME=${fixtureRoot}/.reqpack-data/home PERL_CPAN_HOME=${fixtureRoot}/.reqpack-data/cpan-home PERL_MM_OPT=INSTALL_BASE=${fixtureRoot}/.reqpack-data/perl5 PERL_MB_OPT='--install_base ${fixtureRoot}/.reqpack-data/perl5' PERL5LIB=${fixtureRoot}/.reqpack-data/perl5/lib/perl5 PATH=${fixtureRoot}/.reqpack-data/perl5/bin:$PATH AUTOMATED_TESTING=1 NONINTERACTIVE_TESTING=1 PERL_MM_USE_DEFAULT=1 cpan -M https://cpan.metacpan.org,https://cpan.org -P -i Try::Tiny",
      exitCode = 0,
      stdout = "Installing Try::Tiny\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
