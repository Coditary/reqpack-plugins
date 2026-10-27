return {
  name = "cpan search detail lookup",
  request = {
    action = "search",
    system = "cpan",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    prompt = "Try::Tiny",
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
      match = "HOME=${fixtureRoot}/.reqpack-data/home PERL_CPAN_HOME=${fixtureRoot}/.reqpack-data/cpan-home PERL_MM_OPT=INSTALL_BASE=${fixtureRoot}/.reqpack-data/perl5 PERL_MB_OPT='--install_base ${fixtureRoot}/.reqpack-data/perl5' PERL5LIB=${fixtureRoot}/.reqpack-data/perl5/lib/perl5 PATH=${fixtureRoot}/.reqpack-data/perl5/bin:$PATH AUTOMATED_TESTING=1 NONINTERACTIVE_TESTING=1 PERL_MM_USE_DEFAULT=1 cpan -D Try::Tiny",
      exitCode = 0,
      stdout = "Try::Tiny\n-------------------------------------------------------------------------\n\t/usr/lib/perl5/vendor_perl/Try/Tiny.pm\n\tInstalled: 0.31\n\tCPAN:      0.32  Not up to date\n\tE/ET/ETHER/Try-Tiny-0.32.tar.gz\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "Try::Tiny",
    resultVersion = "0.31",
    events = { "searched" },
  }
}
