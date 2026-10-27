return {
  name = "uv outdated tools",
  request = {
    action = "outdated",
    system = "uv",
  },
  fixtureDirs = {
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
      content = "Name: ruff\nVersion: 0.6.9\nSummary: Python linter\n",
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
      match = "UV_CACHE_DIR='/home/test/.cache/reqpack/uv/cache' UV_TOOL_DIR='/home/test/.cache/reqpack/uv/tools' UV_TOOL_BIN_DIR='/home/test/.cache/reqpack/uv/bin' UV_NO_PROGRESS='1' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' uv tool list --outdated -v",
      exitCode = 0,
      stdout = "ruff v0.6.9\n- ruff\n",
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
      stdout = "Name: ruff\nVersion: 0.6.9\nSummary: Python linter\n",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://pypi.org/pypi/ruff/json'",
      exitCode = 0,
      stdout = [[{"info":{"name":"ruff","version":"0.7.0","summary":"Python linter","home_page":"https://docs.astral.sh/ruff","license":"MIT"}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "ruff",
    resultVersion = "0.6.9",
    events = { "outdated" },
  }
}
