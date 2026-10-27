return {
  name = "guix remove installed package",
  request = {
    action = "remove",
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
      match = "NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' guix package --profile='/home/test/.cache/reqpack/guix/profile' --remove 'hello'",
      exitCode = 0,
      stdout = "The following package will be removed:\n   hello 2.12.1\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  },
}
