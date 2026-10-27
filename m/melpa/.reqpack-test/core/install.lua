return {
  name = "melpa install package",
  request = {
    action = "install",
    system = "melpa",
    packages = {
      { action = "install", name = "use-package" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'emacs' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "REQPACK_MELPA_ACTION='install' REQPACK_MELPA_NAMES='use-package'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
