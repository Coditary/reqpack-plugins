return {
  name = "hex info package",
  request = {
    action = "info",
    system = "hex",
    prompt = "plug",
  },
  fakeExec = {
    {
      match = "command -v 'mix' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "MIX_HOME='/home/test/.cache/reqpack/hex/mix' MIX_ARCHIVES='/home/test/.cache/reqpack/hex/mix/archives' HEX_HOME='/home/test/.cache/reqpack/hex/hex' MIX_ENV='prod' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' mix local.hex --if-missing --force",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "MIX_HOME='/home/test/.cache/reqpack/hex/mix' MIX_ARCHIVES='/home/test/.cache/reqpack/hex/mix/archives' HEX_HOME='/home/test/.cache/reqpack/hex/hex' MIX_ENV='prod' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' mix hex.info plug",
      exitCode = 0,
      stdout = "A specification for composable modules between web applications.\n\nConfig: {:plug, \"~> 1.15\"}\nLocked version: 1.14.0\nRecent releases:\n  1.15.0 (2024-01-01)\n  1.14.0 (2023-01-01)\nLicenses: Apache-2.0\nLinks:\n  GitHub: https://github.com/elixir-plug/plug\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "plug",
    resultVersion = "1.14.0",
    events = { "informed" },
  },
}
