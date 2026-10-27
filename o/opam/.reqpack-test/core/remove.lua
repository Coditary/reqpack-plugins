return {
  name = "opam remove package",
  request = {
    action = "remove",
    system = "opam",
    flags = {
      "root=${fixtureRoot}/opam-root",
      "switch=reqpack-test",
    },
    packages = {
      { name = "dune" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'opam' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C OPAMNOSELFUPGRADE=true OPAMUTF8=never opam --cli=2.1 --color=never --yes --root '${fixtureRoot}/opam-root' --switch reqpack-test remove dune",
      exitCode = 0,
      stdout = "The following actions will be performed\n  remove dune\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'opam' >/dev/null 2>&1",
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C OPAMNOSELFUPGRADE=true OPAMUTF8=never opam --cli=2.1 --color=never --yes --root '${fixtureRoot}/opam-root' --switch reqpack-test remove dune"
    },
    events = { "deleted", "success" },
  },
}
