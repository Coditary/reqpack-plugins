return {
  name = "hex install local dependency",
  request = {
    action = "install",
    system = "hex",
    flags = { "dir=/tmp/reqpack-hex-install-local/project" },
    localPath = "/tmp/reqpack-hex-install-local/localdep",
  },
  fixtureDirs = {
    "/tmp/reqpack-hex-install-local/project",
    "/tmp/reqpack-hex-install-local/localdep",
  },
  fixtureFiles = {
    {
      path = "/tmp/reqpack-hex-install-local/project/mix.exs",
      content = [[
defmodule Demo.MixProject do
  use Mix.Project

  def project do
    [app: :demo, version: "0.1.0", deps: deps()]
  end

  defp deps do
    [
    ]
  end
end
]],
    },
    {
      path = "/tmp/reqpack-hex-install-local/localdep/mix.exs",
      content = [[
defmodule Localdep.MixProject do
  use Mix.Project

  def project do
    [app: :localdep, version: "0.1.0"]
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
      match = "cat '/tmp/reqpack-hex-install-local/localdep/mix.exs'",
      exitCode = 0,
      stdout = "defmodule Localdep.MixProject do\n  use Mix.Project\n\n  def project do\n    [app: :localdep, version: \"0.1.0\"]\n  end\nend\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/reqpack-hex-install-local/project/mix.exs'",
      exitCode = 0,
      stdout = "defmodule Demo.MixProject do\n  use Mix.Project\n\n  def project do\n    [app: :demo, version: \"0.1.0\", deps: deps()]\n  end\n\n  defp deps do\n    [\n    ]\n  end\nend\n",
      stderr = "",
      success = true,
    },
    {
      match = [=[mkdir -p '/tmp/reqpack-hex-install-local/project' && printf %s 'defmodule Demo.MixProject do
  use Mix.Project

  def project do
    [app: :demo, version: "0.1.0", deps: deps()]
  end

  defp deps do
    [
      {:localdep, path: "/tmp/reqpack-hex-install-local/localdep"},
    ]
  end
end

' > '/tmp/reqpack-hex-install-local/project/mix.exs']=],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cd '/tmp/reqpack-hex-install-local/project' && MIX_HOME='/home/test/.cache/reqpack/hex/mix' MIX_ARCHIVES='/home/test/.cache/reqpack/hex/mix/archives' HEX_HOME='/home/test/.cache/reqpack/hex/hex' MIX_ENV='prod' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' mix deps.get",
      exitCode = 0,
      stdout = "Resolving Hex dependencies...\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
