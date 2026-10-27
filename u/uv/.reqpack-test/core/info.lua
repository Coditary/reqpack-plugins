return {
  name = "uv info package with local state",
  request = {
    action = "info",
    system = "uv",
    prompt = "ruff",
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
      content = "Name: ruff\nVersion: 0.6.9\nSummary: Python linter\nHome-page: https://docs.astral.sh/ruff\nLicense: MIT\n",
    },
  },
  fakeExec = {
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
      stdout = "Name: ruff\nVersion: 0.6.9\nSummary: Python linter\nHome-page: https://docs.astral.sh/ruff\nLicense: MIT\n",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://pypi.org/pypi/ruff/json'",
      exitCode = 0,
      stdout = [[{"info":{"name":"ruff","version":"0.7.0","summary":"An extremely fast Python linter","home_page":"https://docs.astral.sh/ruff","license":"MIT"}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "ruff",
    resultVersion = "0.6.9",
    events = { "informed" },
  }
}
