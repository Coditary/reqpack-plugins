return {
  name = "rtx install tool version",
  request = {
    action = "install",
    system = "rtx",
    packages = {
      { name = "node", version = "20" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'rtx' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "RTX_DATA_DIR='/home/test/.cache/reqpack/rtx/data' RTX_CACHE_DIR='/home/test/.cache/reqpack/rtx/cache' RTX_STATE_DIR='/home/test/.cache/reqpack/rtx/state' RTX_CONFIG_DIR='/home/test/.cache/reqpack/rtx/config' RTX_TMP_DIR='/home/test/.cache/reqpack/rtx/tmp' MISE_DATA_DIR='/home/test/.cache/reqpack/rtx/data' MISE_CACHE_DIR='/home/test/.cache/reqpack/rtx/cache' MISE_STATE_DIR='/home/test/.cache/reqpack/rtx/state' MISE_CONFIG_DIR='/home/test/.cache/reqpack/rtx/config' MISE_TMP_DIR='/home/test/.cache/reqpack/rtx/tmp' NO_COLOR='1' CLICOLOR='0' LC_ALL='C' LANG='C' LANGUAGE='C' rtx install node@20",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    },
    {
      match = "RTX_DATA_DIR='/home/test/.cache/reqpack/rtx/data' RTX_CACHE_DIR='/home/test/.cache/reqpack/rtx/cache' RTX_STATE_DIR='/home/test/.cache/reqpack/rtx/state' RTX_CONFIG_DIR='/home/test/.cache/reqpack/rtx/config' RTX_TMP_DIR='/home/test/.cache/reqpack/rtx/tmp' MISE_DATA_DIR='/home/test/.cache/reqpack/rtx/data' MISE_CACHE_DIR='/home/test/.cache/reqpack/rtx/cache' MISE_STATE_DIR='/home/test/.cache/reqpack/rtx/state' MISE_CONFIG_DIR='/home/test/.cache/reqpack/rtx/config' MISE_TMP_DIR='/home/test/.cache/reqpack/rtx/tmp' NO_COLOR='1' CLICOLOR='0' LC_ALL='C' LANG='C' LANGUAGE='C' rtx ls --installed --json node",
      exitCode = 0,
      stdout = [[{"node":[{"version":"20.0.0","install_path":"/home/test/.cache/reqpack/rtx/data/installs/node/20.0.0"}]}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'rtx' >/dev/null 2>&1",
      "RTX_DATA_DIR='/home/test/.cache/reqpack/rtx/data' RTX_CACHE_DIR='/home/test/.cache/reqpack/rtx/cache' RTX_STATE_DIR='/home/test/.cache/reqpack/rtx/state' RTX_CONFIG_DIR='/home/test/.cache/reqpack/rtx/config' RTX_TMP_DIR='/home/test/.cache/reqpack/rtx/tmp' MISE_DATA_DIR='/home/test/.cache/reqpack/rtx/data' MISE_CACHE_DIR='/home/test/.cache/reqpack/rtx/cache' MISE_STATE_DIR='/home/test/.cache/reqpack/rtx/state' MISE_CONFIG_DIR='/home/test/.cache/reqpack/rtx/config' MISE_TMP_DIR='/home/test/.cache/reqpack/rtx/tmp' NO_COLOR='1' CLICOLOR='0' LC_ALL='C' LANG='C' LANGUAGE='C' rtx install node@20",
      "RTX_DATA_DIR='/home/test/.cache/reqpack/rtx/data' RTX_CACHE_DIR='/home/test/.cache/reqpack/rtx/cache' RTX_STATE_DIR='/home/test/.cache/reqpack/rtx/state' RTX_CONFIG_DIR='/home/test/.cache/reqpack/rtx/config' RTX_TMP_DIR='/home/test/.cache/reqpack/rtx/tmp' MISE_DATA_DIR='/home/test/.cache/reqpack/rtx/data' MISE_CACHE_DIR='/home/test/.cache/reqpack/rtx/cache' MISE_STATE_DIR='/home/test/.cache/reqpack/rtx/state' MISE_CONFIG_DIR='/home/test/.cache/reqpack/rtx/config' MISE_TMP_DIR='/home/test/.cache/reqpack/rtx/tmp' NO_COLOR='1' CLICOLOR='0' LC_ALL='C' LANG='C' LANGUAGE='C' rtx ls --installed --json node"
    },
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{1=<lua-value>}",
      success = "ok",
    },
  }
}
