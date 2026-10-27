return {
  name = "opam update package",
  request = {
    action = "update",
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C OPAMNOSELFUPGRADE=true OPAMUTF8=never opam --cli=2.1 --color=never --yes --root '${fixtureRoot}/opam-root' --switch reqpack-test update",
      exitCode = 0,
      stdout = "Updating package repositories\n",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C OPAMNOSELFUPGRADE=true OPAMUTF8=never opam --cli=2.1 --color=never --yes --root '${fixtureRoot}/opam-root' --switch reqpack-test upgrade dune",
      exitCode = 0,
      stdout = "The following actions will be performed\n  upgrade dune\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'opam' >/dev/null 2>&1",
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C OPAMNOSELFUPGRADE=true OPAMUTF8=never opam --cli=2.1 --color=never --yes --root '${fixtureRoot}/opam-root' --switch reqpack-test update",
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C OPAMNOSELFUPGRADE=true OPAMUTF8=never opam --cli=2.1 --color=never --yes --root '${fixtureRoot}/opam-root' --switch reqpack-test upgrade dune"
    },
    events = { "updated", "success" },
  },
}
