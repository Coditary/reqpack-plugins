return {
  name = "uv install tool",
  request = {
    action = "install",
    system = "uv",
    packages = {
      { name = "ruff", version = "0.6.9" }
    },
  },
  fixtureDirs = {
    "/home/test/.cache/reqpack/uv",
    "/home/test/.cache/reqpack/uv/cache",
    "/home/test/.cache/reqpack/uv/bin",
    "/home/test/.cache/reqpack/uv/tools",
    "/home/test/.cache/reqpack/uv/tools/ruff",
    "/home/test/.cache/reqpack/uv/tools/ruff/lib",
    "/home/test/.cache/reqpack/uv/tools/ruff/lib/python3.12",
    "/home/test/.cache/reqpack/uv/tools/ruff/lib/python3.12/site-packages",
    "/home/test/.cache/reqpack/uv/tools/ruff/lib/python3.12/site-packages/ruff-0.6.9.dist-info",
  },
  fixtureFiles = {
    {
      path = "/home/test/.cache/reqpack/uv/tools/ruff/uv-receipt.toml",
      content = [[
[tool]
requirements = [{ name = "ruff" }]
entrypoints = [
    { name = "ruff", install-path = "/home/test/.cache/reqpack/uv/bin/ruff", from = "ruff" },
]
]],
    },
    {
      path = "/home/test/.cache/reqpack/uv/tools/ruff/lib/python3.12/site-packages/ruff-0.6.9.dist-info/METADATA",
      content = [[
Name: ruff
Version: 0.6.9
Summary: Python linter
Home-page: https://docs.astral.sh/ruff
License: MIT
Requires-Python: >=3.8
Requires-Dist: click>=8
]],
    },
  },
  fakeExec = {
    {
      match = "command -v 'uv' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "UV_CACHE_DIR='/home/test/.cache/reqpack/uv/cache' UV_TOOL_DIR='/home/test/.cache/reqpack/uv/tools' UV_TOOL_BIN_DIR='/home/test/.cache/reqpack/uv/bin' UV_NO_PROGRESS='1' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' uv tool install ruff==0.6.9",
      exitCode = 0,
      stdout = "Installed 1 executable: ruff\n",
      stderr = "",
      success = true,
    },
    {
      match = "ls -1A '/home/test/.cache/reqpack/uv/tools'",
      exitCode = 0,
      stdout = "ruff\n",
      stderr = "",
      success = true,
    },
    {
      match = "ls -1A '/home/test/.cache/reqpack/uv/tools/ruff/lib'",
      exitCode = 0,
      stdout = "python3.12\n",
      stderr = "",
      success = true,
    },
    {
      match = "ls -1A '/home/test/.cache/reqpack/uv/tools/ruff/lib/python3.12/site-packages'",
      exitCode = 0,
      stdout = "ruff-0.6.9.dist-info\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/home/test/.cache/reqpack/uv/tools/ruff/uv-receipt.toml'",
      exitCode = 0,
      stdout = "[tool]\nrequirements = [{ name = \"ruff\" }]\nentrypoints = [\n    { name = \"ruff\", install-path = \"/home/test/.cache/reqpack/uv/bin/ruff\", from = \"ruff\" },\n]\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/home/test/.cache/reqpack/uv/tools/ruff/lib/python3.12/site-packages/ruff-0.6.9.dist-info/METADATA'",
      exitCode = 0,
      stdout = "Name: ruff\nVersion: 0.6.9\nSummary: Python linter\nHome-page: https://docs.astral.sh/ruff\nLicense: MIT\nRequires-Python: >=3.8\nRequires-Dist: click>=8\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'uv' >/dev/null 2>&1",
      "UV_CACHE_DIR='/home/test/.cache/reqpack/uv/cache' UV_TOOL_DIR='/home/test/.cache/reqpack/uv/tools' UV_TOOL_BIN_DIR='/home/test/.cache/reqpack/uv/bin' UV_NO_PROGRESS='1' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' uv tool install ruff==0.6.9",
      "ls -1A '/home/test/.cache/reqpack/uv/tools'",
      "cat '/home/test/.cache/reqpack/uv/tools/ruff/uv-receipt.toml'",
      "ls -1A '/home/test/.cache/reqpack/uv/tools/ruff/lib'",
      "ls -1A '/home/test/.cache/reqpack/uv/tools/ruff/lib/python3.12/site-packages'",
      "cat '/home/test/.cache/reqpack/uv/tools/ruff/lib/python3.12/site-packages/ruff-0.6.9.dist-info/METADATA'"
    },
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{1=<lua-value>}",
      success = "ok",
    },
  }
}
