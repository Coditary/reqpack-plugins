return {
  name = "rtx list installed tools",
  request = {
    action = "list",
    system = "rtx",
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
      match = "RTX_DATA_DIR='/home/test/.cache/reqpack/rtx/data' RTX_CACHE_DIR='/home/test/.cache/reqpack/rtx/cache' RTX_STATE_DIR='/home/test/.cache/reqpack/rtx/state' RTX_CONFIG_DIR='/home/test/.cache/reqpack/rtx/config' RTX_TMP_DIR='/home/test/.cache/reqpack/rtx/tmp' MISE_DATA_DIR='/home/test/.cache/reqpack/rtx/data' MISE_CACHE_DIR='/home/test/.cache/reqpack/rtx/cache' MISE_STATE_DIR='/home/test/.cache/reqpack/rtx/state' MISE_CONFIG_DIR='/home/test/.cache/reqpack/rtx/config' MISE_TMP_DIR='/home/test/.cache/reqpack/rtx/tmp' NO_COLOR='1' CLICOLOR='0' LC_ALL='C' LANG='C' LANGUAGE='C' rtx ls --installed --json",
      exitCode = 0,
      stdout = [[{"node":[{"version":"20.0.0","install_path":"/home/test/.cache/reqpack/rtx/data/installs/node/20.0.0"}],"python":[{"version":"3.12.2","install_path":"/home/test/.cache/reqpack/rtx/data/installs/python/3.12.2"}]}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'rtx' >/dev/null 2>&1",
      "RTX_DATA_DIR='/home/test/.cache/reqpack/rtx/data' RTX_CACHE_DIR='/home/test/.cache/reqpack/rtx/cache' RTX_STATE_DIR='/home/test/.cache/reqpack/rtx/state' RTX_CONFIG_DIR='/home/test/.cache/reqpack/rtx/config' RTX_TMP_DIR='/home/test/.cache/reqpack/rtx/tmp' MISE_DATA_DIR='/home/test/.cache/reqpack/rtx/data' MISE_CACHE_DIR='/home/test/.cache/reqpack/rtx/cache' MISE_STATE_DIR='/home/test/.cache/reqpack/rtx/state' MISE_CONFIG_DIR='/home/test/.cache/reqpack/rtx/config' MISE_TMP_DIR='/home/test/.cache/reqpack/rtx/tmp' NO_COLOR='1' CLICOLOR='0' LC_ALL='C' LANG='C' LANGUAGE='C' rtx ls --installed --json"
    },
    resultCount = 2,
    resultName = "node",
    resultVersion = "20.0.0",
    events = { "listed" },
  }
}
