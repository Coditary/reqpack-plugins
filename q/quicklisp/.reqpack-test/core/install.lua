return {
  name = "quicklisp install remote system",
  fixtureRoot = "/tmp/opencode/quicklisp-install-case",
  request = {
    action = "install",
    system = "quicklisp",
    flags = { "data-root=/tmp/opencode/quicklisp-install-case/.reqpack-data" },
    packages = { { name = "alexandria" } },
  },
  fixtureDirs = {
    ".reqpack-data/quicklisp/home",
  },
  fixtureFiles = {
    { path = ".reqpack-data/quicklisp/home/setup.lisp", content = ";; quicklisp setup\n" },
  },
  fakeExec = {
    { match = "command -v 'sbcl' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -f '/tmp/opencode/quicklisp-install-case/.reqpack-data/quicklisp/home/setup.lisp'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "(ql:quickload name :silent t :prompt nil)", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    eventPayloads = {
      installed = "<lua-value>",
      success = "ok",
    },
  },
}
