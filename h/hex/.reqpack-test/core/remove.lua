return {
  name = "hex remove dependency",
  request = {
    action = "remove",
    system = "hex",
    flags = { "dir=/tmp/reqpack-hex-remove/project" },
    packages = {
      { name = "plug" }
    },
  },
  fixtureDirs = {
    "/tmp/reqpack-hex-remove/project",
  },
  fixtureFiles = {
    {
      path = "/tmp/reqpack-hex-remove/project/mix.exs",
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
      match = "cat '/tmp/reqpack-hex-remove/project/mix.exs'",
      exitCode = 0,
      stdout = "defmodule Demo.MixProject do\n  use Mix.Project\n\n  def project do\n    [app: :demo, version: \"0.1.0\", deps: deps()]\n  end\n\n  defp deps do\n    [\n      {:plug, \"~> 1.14\"},\n    ]\n  end\nend\n",
      stderr = "",
      success = true,
    },
    {
      match = [=[mkdir -p '/tmp/reqpack-hex-remove/project' && printf %s 'defmodule Demo.MixProject do
  use Mix.Project

  def project do
    [app: :demo, version: "0.1.0", deps: deps()]
  end

  defp deps do
    [
    ]
  end
end

' > '/tmp/reqpack-hex-remove/project/mix.exs']=],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cd '/tmp/reqpack-hex-remove/project' && MIX_HOME='/home/test/.cache/reqpack/hex/mix' MIX_ARCHIVES='/home/test/.cache/reqpack/hex/mix/archives' HEX_HOME='/home/test/.cache/reqpack/hex/hex' MIX_ENV='prod' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' mix deps.clean --unlock --unused",
      exitCode = 0,
      stdout = "* Cleaning plug\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  },
}
