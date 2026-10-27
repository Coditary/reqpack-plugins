return {
  name = "melpa remove installed package",
  request = {
    action = "remove",
    system = "melpa",
    packages = {
      { action = "remove", name = "use-package" }
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
      match = "REQPACK_MELPA_ACTION='remove' REQPACK_MELPA_NAMES='use-package'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  }
}
