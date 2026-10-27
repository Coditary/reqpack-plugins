return {
  name = "opam search packages",
  request = {
    action = "search",
    system = "opam",
    prompt = "dune",
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C OPAMNOSELFUPGRADE=true OPAMUTF8=never opam --cli=2.1 --color=never --root '${fixtureRoot}/opam-root' --switch reqpack-test list --search --columns=name,version,synopsis,repository '--separator=|^|' --short dune",
      exitCode = 0,
      stdout = "dune|^|3.17.3|^|Fast, portable, and opinionated build system|^|default\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'opam' >/dev/null 2>&1",
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C OPAMNOSELFUPGRADE=true OPAMUTF8=never opam --cli=2.1 --color=never --root '${fixtureRoot}/opam-root' --switch reqpack-test list --search --columns=name,version,synopsis,repository '--separator=|^|' --short dune"
    },
    resultCount = 1,
    resultName = "dune",
    resultVersion = "3.17.3",
    events = { "searched" },
  },
}
