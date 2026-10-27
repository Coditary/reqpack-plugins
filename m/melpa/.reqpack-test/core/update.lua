return {
  name = "melpa update outdated package",
  request = {
    action = "update",
    system = "melpa",
    packages = {
      { action = "update", name = "use-package" }
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
      match = "REQPACK_MELPA_ACTION='update' REQPACK_MELPA_NAMES='use-package'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  }
}
