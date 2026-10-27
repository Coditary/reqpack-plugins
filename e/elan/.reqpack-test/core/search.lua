return {
  name = "elan search returns local and standard channels",
  request = {
    action = "search",
    system = "elan",
    prompt = "night",
  },
  fakeExec = {
    {
      match = "command -v elan >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "elan toolchain list",
      exitCode = 0,
      stdout = "stable\nnightly-2023-09-06\n",
      stderr = "",
      success = true,
    },
    {
      match = "elan show",
      exitCode = 0,
      stdout = "installed toolchains\n--------------------\n\nstable (default)\nnightly-2023-09-06\n\nactive toolchain\n----------------\n\nnightly-2023-09-06 (overridden by '/work/project/lean-toolchain')\n",
      stderr = "",
      success = true,
    },
    {
      match = "elan dump-state --no-net",
      exitCode = 0,
      stdout = "{\n  \"toolchains\": {\n    \"installed\": [\n      { \"resolved_name\": \"stable\", \"path\": \"/home/test/.elan/toolchains/stable\" },\n      { \"resolved_name\": \"nightly-2023-09-06\", \"path\": \"/home/test/.elan/toolchains/nightly-2023-09-06\" }\n    ]\n  }\n}\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed", "searched" },
    resultCount = 2,
    resultName = "nightly",
    resultVersion = "nightly",
  }
}
