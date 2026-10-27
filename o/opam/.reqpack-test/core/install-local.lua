return {
  name = "opam install local path",
  request = {
    action = "installLocal",
    system = "opam",
    localPath = "/tmp/demo/opam-package",
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C OPAMNOSELFUPGRADE=true OPAMUTF8=never opam --cli=2.1 --color=never --yes --root '${fixtureRoot}/opam-root' --switch reqpack-test install /tmp/demo/opam-package",
      exitCode = 0,
      stdout = "Processing  /tmp/demo/opam-package\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'opam' >/dev/null 2>&1",
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C OPAMNOSELFUPGRADE=true OPAMUTF8=never opam --cli=2.1 --color=never --yes --root '${fixtureRoot}/opam-root' --switch reqpack-test install /tmp/demo/opam-package"
    },
    events = { "installed", "success" },
  },
}
