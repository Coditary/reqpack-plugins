return {
  name = "xbps remove package",
  request = {
    action = "remove",
    system = "xbps",
    packages = {
      { name = "ripgrep" }
    },
  },
  fakeExec = {
    { match = "command -v xbps-install >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "command -v xbps-remove >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "command -v xbps-query >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "command -v xbps-rindex >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "xbps-remove -y -c /home/Leodoras/.cache/reqpack/xbps/cache ripgrep", exitCode = 0, stdout = "Removed `ripgrep'\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
    result = true,
  }
}
