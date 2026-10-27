return {
  name = "gh install skill",
  request = {
    action = "install",
    system = "gh",
    packages = {
      { name = "github/awesome-copilot/documentation-writer" }
    },
  },
  fixtureDirs = {
    "/home/test/.cache/reqpack/gh/state",
  },
  fakeExec = {
    {
      match = "GH_CONFIG_DIR='/home/test/.cache/reqpack/gh/config' XDG_CACHE_HOME='/home/test/.cache/reqpack/gh/xdg-cache' XDG_STATE_HOME='/home/test/.cache/reqpack/gh/xdg-state' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' gh skill install github/awesome-copilot documentation-writer --dir /home/test/.cache/reqpack/gh/skills/managed",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/home/test/.cache/reqpack/gh/state'",
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
