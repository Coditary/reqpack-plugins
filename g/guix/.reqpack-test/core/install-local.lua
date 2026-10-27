return {
  name = "guix install local package file",
  request = {
    action = "install",
    system = "guix",
    localPath = "./fixtures/hello.scm",
  },
  fixtureFiles = {
    {
      path = "./fixtures/hello.scm",
      content = "(specifications->manifest '(\"hello\"))\n",
    },
  },
  fakeExec = {
    {
      match = "command -v 'guix' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -f './fixtures/hello.scm'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' guix package --profile='/home/test/.cache/reqpack/guix/profile' --install-from-file './fixtures/hello.scm'",
      exitCode = 0,
      stdout = "The following package will be installed:\n   hello 2.12.1\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
