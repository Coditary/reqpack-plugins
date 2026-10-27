return {
  name = "guix update selected package",
  request = {
    action = "update",
    system = "guix",
    packages = {
      { name = "hello" },
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
      match = "NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' guix package --profile='/home/test/.cache/reqpack/guix/profile' --upgrade 'hello'",
      exitCode = 0,
      stdout = "The following package will be upgraded:\n   hello 2.12.1 -> 2.12.2\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  },
}
