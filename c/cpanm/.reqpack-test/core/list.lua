return {
  name = "cpanm list installed modules",
  request = {
    action = "list",
    system = "cpanm",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
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
      match = "command -v perl >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "PERL_CPANM_HOME=${fixtureRoot}/.reqpack-data/cpanm-home PERL_MM_OPT=INSTALL_BASE=${fixtureRoot}/.reqpack-data/perl5 PERL_MB_OPT='--install_base ${fixtureRoot}/.reqpack-data/perl5' PERL5LIB=${fixtureRoot}/.reqpack-data/perl5/lib/perl5 PATH=${fixtureRoot}/.reqpack-data/perl5/bin:$PATH AUTOMATED_TESTING=1 NONINTERACTIVE_TESTING=1 PERL_MM_USE_DEFAULT=1 perl -MExtUtils::Installed -e 'use ExtUtils::Installed; my $i = ExtUtils::Installed->new(skip_cwd => 1); for my $m (sort $i->modules) { my $v = eval { $i->version($m) }; $v = defined($v) && $v ne q{} ? $v : q{undef}; print $m, qq{ }, $v, qq{\\n}; }'",
      exitCode = 0,
      stdout = "Plack 1.0051\nTry::Tiny 0.32\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 2,
    resultName = "Plack",
    resultVersion = "1.0051",
    events = { "listed" },
  }
}
