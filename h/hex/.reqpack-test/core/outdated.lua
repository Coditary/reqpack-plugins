return {
  name = "hex outdated dependencies",
  request = {
    action = "outdated",
    system = "hex",
    flags = { "dir=/tmp/reqpack-hex-outdated/project" },
  },
  fixtureDirs = {
    "/tmp/reqpack-hex-outdated/project",
  },
  fixtureFiles = {
    {
      path = "/tmp/reqpack-hex-outdated/project/mix.exs",
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
      match = "cat '/tmp/reqpack-hex-outdated/project/mix.exs'",
      exitCode = 0,
      stdout = "defmodule Demo.MixProject do\n  use Mix.Project\n\n  def project do\n    [app: :demo, version: \"0.1.0\", deps: deps()]\n  end\n\n  defp deps do\n    [\n      {:plug, \"~> 1.14\"},\n    ]\n  end\nend\n",
      stderr = "",
      success = true,
    },
    {
      match = "cd '/tmp/reqpack-hex-outdated/project' && MIX_HOME='/home/test/.cache/reqpack/hex/mix' MIX_ARCHIVES='/home/test/.cache/reqpack/hex/mix/archives' HEX_HOME='/home/test/.cache/reqpack/hex/hex' MIX_ENV='prod' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' mix hex.outdated --all --within-requirements",
      exitCode = 1,
      stdout = "Dependency              Only  Current  Latest  Status\nplug                         1.14.0   1.15.0  Update possible\nphoenix                 dev   1.7.0    1.7.0   Up-to-date\n\nRun `mix hex.outdated APP` to see requirements for a specific dependency.\n",
      stderr = "",
      success = false,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'mix' >/dev/null 2>&1",
      "MIX_HOME='/home/test/.cache/reqpack/hex/mix' MIX_ARCHIVES='/home/test/.cache/reqpack/hex/mix/archives' HEX_HOME='/home/test/.cache/reqpack/hex/hex' MIX_ENV='prod' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' mix local.hex --if-missing --force",
      "cat '/tmp/reqpack-hex-outdated/project/mix.exs'",
      "cd '/tmp/reqpack-hex-outdated/project' && MIX_HOME='/home/test/.cache/reqpack/hex/mix' MIX_ARCHIVES='/home/test/.cache/reqpack/hex/mix/archives' HEX_HOME='/home/test/.cache/reqpack/hex/hex' MIX_ENV='prod' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' mix hex.outdated --all --within-requirements"
    },
    resultCount = 1,
    resultName = "plug",
    resultVersion = "1.14.0",
    events = { "outdated" },
  },
}
