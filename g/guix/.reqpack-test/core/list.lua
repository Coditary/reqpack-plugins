return {
  name = "guix list installed package outputs",
  request = {
    action = "list",
    system = "guix",
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
      match = "NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' guix package --profile='/home/test/.cache/reqpack/guix/profile' --list-installed",
      exitCode = 0,
      stdout = "hello\t2.12.1\tout\t/gnu/store/abc-hello-2.12.1\nhello\t2.12.1\tdebug\t/gnu/store/def-hello-debug-2.12.1\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "hello",
    resultVersion = "2.12.1",
  },
}
