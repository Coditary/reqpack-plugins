return {
  name = "hex list dependencies",
  request = {
    action = "list",
    system = "hex",
    flags = { "dir=/tmp/reqpack-hex-list/project" },
  },
  fixtureDirs = {
    "/tmp/reqpack-hex-list/project",
  },
  fixtureFiles = {
    {
      path = "/tmp/reqpack-hex-list/project/mix.exs",
      content = [[
defmodule Demo.MixProject do
  use Mix.Project

  def project do
    [app: :demo, version: "0.1.0", deps: deps()]
  end

  defp deps do
    [
      {:plug, "~> 1.14"},
    ]
  end
end
]],
    },
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
      match = "cat '/tmp/reqpack-hex-list/project/mix.exs'",
      exitCode = 0,
      stdout = "defmodule Demo.MixProject do\n  use Mix.Project\n\n  def project do\n    [app: :demo, version: \"0.1.0\", deps: deps()]\n  end\n\n  defp deps do\n    [\n      {:plug, \"~> 1.14\"},\n    ]\n  end\nend\n",
      stderr = "",
      success = true,
    },
    {
      match = "cd '/tmp/reqpack-hex-list/project' && MIX_HOME='/home/test/.cache/reqpack/hex/mix' MIX_ARCHIVES='/home/test/.cache/reqpack/hex/mix/archives' HEX_HOME='/home/test/.cache/reqpack/hex/hex' MIX_ENV='prod' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' mix deps --all",
      exitCode = 0,
      stdout = "* plug 1.14.0 (Hex package) (mix)\n  locked at abc123\n  ok\n* localdep 0.1.0 (path)\n  ok\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'mix' >/dev/null 2>&1",
      "MIX_HOME='/home/test/.cache/reqpack/hex/mix' MIX_ARCHIVES='/home/test/.cache/reqpack/hex/mix/archives' HEX_HOME='/home/test/.cache/reqpack/hex/hex' MIX_ENV='prod' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' mix local.hex --if-missing --force",
      "cat '/tmp/reqpack-hex-list/project/mix.exs'",
      "cd '/tmp/reqpack-hex-list/project' && MIX_HOME='/home/test/.cache/reqpack/hex/mix' MIX_ARCHIVES='/home/test/.cache/reqpack/hex/mix/archives' HEX_HOME='/home/test/.cache/reqpack/hex/hex' MIX_ENV='prod' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' mix deps --all"
    },
    resultCount = 1,
    resultName = "plug",
    resultVersion = "1.14.0",
    events = { "listed" },
  },
}
