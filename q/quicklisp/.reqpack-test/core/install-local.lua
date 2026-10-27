return {
  name = "quicklisp install local project",
  fixtureRoot = "/tmp/opencode/quicklisp-install-local-case",
  request = {
    action = "install",
    system = "quicklisp",
    localPath = "/tmp/opencode/quicklisp-install-local-case/projects/example-system",
    flags = { "data-root=/tmp/opencode/quicklisp-install-local-case/.reqpack-data" },
  },
  fixtureDirs = {
    ".reqpack-data/quicklisp/home",
    "projects/example-system",
  },
  fixtureFiles = {
    { path = ".reqpack-data/quicklisp/home/setup.lisp", content = ";; quicklisp setup\n" },
    { path = "projects/example-system/example-system.asd", content = "" },
  },
  fakeExec = {
    { match = "command -v 'sbcl' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -f '/tmp/opencode/quicklisp-install-local-case/.reqpack-data/quicklisp/home/setup.lisp'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -d '/tmp/opencode/quicklisp-install-local-case/projects/example-system'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quicklisp-install-local-case/.reqpack-data/quicklisp/home/local-projects'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "(ql:register-local-projects)", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{localTarget=true, packageType=common-lisp-system, path=/tmp/opencode/quicklisp-install-local-case/projects/example-system}",
      success = "ok",
    },
  },
}
