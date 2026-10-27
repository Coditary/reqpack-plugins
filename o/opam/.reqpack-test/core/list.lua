return {
  name = "opam list installed packages",
  request = {
    action = "list",
    system = "opam",
    flags = {
      "root=${fixtureRoot}/opam-root",
      "switch=reqpack-test",
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C OPAMNOSELFUPGRADE=true OPAMUTF8=never opam --cli=2.1 --color=never --root '${fixtureRoot}/opam-root' --switch reqpack-test list --installed --columns=name,installed-version,synopsis,repository '--separator=|^|' --short",
      exitCode = 0,
      stdout = "dune|^|3.17.2|^|Fast, portable, and opinionated build system|^|default\nocamlfind|^|1.9.8|^|A library manager for OCaml|^|default\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'opam' >/dev/null 2>&1",
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C OPAMNOSELFUPGRADE=true OPAMUTF8=never opam --cli=2.1 --color=never --root '${fixtureRoot}/opam-root' --switch reqpack-test list --installed --columns=name,installed-version,synopsis,repository '--separator=|^|' --short"
    },
    resultCount = 2,
    resultName = "dune",
    resultVersion = "3.17.2",
    events = { "listed" },
  },
}
