return {
  name = "guix install package into shared profile",
  request = {
    action = "install",
    system = "guix",
    packages = {
      { name = "hello", version = "2.12.1" },
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
      match = "NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' guix package --profile='/home/test/.cache/reqpack/guix/profile' --install 'hello@2.12.1'",
      exitCode = 0,
      stdout = "The following package will be installed:\n   hello 2.12.1\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    commands = {
      "command -v 'guix' >/dev/null 2>&1",
      "NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' guix package --profile='/home/test/.cache/reqpack/guix/profile' --install 'hello@2.12.1'"
    },
  },
}
