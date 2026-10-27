return {
  name = "opam install package",
  request = {
    action = "install",
    system = "opam",
    flags = {
      "root=${fixtureRoot}/opam-root",
      "switch=reqpack-test",
    },
    packages = {
      { name = "dune", version = "3.17.2" }
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C OPAMNOSELFUPGRADE=true OPAMUTF8=never opam --cli=2.1 --color=never --yes --root '${fixtureRoot}/opam-root' --switch reqpack-test install dune.3.17.2",
      exitCode = 0,
      stdout = "The following actions will be performed\n  install dune 3.17.2\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'opam' >/dev/null 2>&1",
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C OPAMNOSELFUPGRADE=true OPAMUTF8=never opam --cli=2.1 --color=never --yes --root '${fixtureRoot}/opam-root' --switch reqpack-test install dune.3.17.2"
    },
    events = { "installed", "success" },
  },
}
