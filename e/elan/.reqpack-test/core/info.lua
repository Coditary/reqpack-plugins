return {
  name = "elan info summarizes one toolchain",
  request = {
    action = "info",
    system = "elan",
    prompt = "stable",
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
      stdout = "installed toolchains\n--------------------\n\nstable (default)\nnightly-2023-09-06\n\nactive toolchain\n----------------\n\nstable\nLean (version 4.9.0, Release)\n",
      stderr = "",
      success = true,
    },
    {
      match = "elan dump-state --no-net",
      exitCode = 0,
      stdout = "{\n  \"toolchains\": {\n    \"installed\": [\n      { \"resolved_name\": \"stable\", \"path\": \"/home/test/.elan/toolchains/stable\" },\n      { \"resolved_name\": \"nightly-2023-09-06\", \"path\": \"/home/test/.elan/toolchains/nightly-2023-09-06\" }\n    ],\n    \"default\": {\n      \"unresolved\": \"stable\",\n      \"resolved\": { \"live\": \"stable\", \"cached\": \"stable\" }\n    },\n    \"resolved_active\": { \"live\": \"stable\", \"cached\": \"stable\" }\n  }\n}\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed", "informed" },
    resultName = "stable",
    resultVersion = "stable",
  }
}
