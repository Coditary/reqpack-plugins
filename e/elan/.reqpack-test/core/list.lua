return {
  name = "elan list installed toolchains",
  request = {
    action = "list",
    system = "elan",
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
      stdout = "stable\nnightly-2023-09-06\nlean-dev\n",
      stderr = "",
      success = true,
    },
    {
      match = "elan show",
      exitCode = 0,
      stdout = "installed toolchains\n--------------------\n\nstable (default)\nnightly-2023-09-06\nlean-dev (linked to local path /tmp/lean-dev)\n\nactive toolchain\n----------------\n\nnightly-2023-09-06 (overridden by '/work/project/lean-toolchain')\nLean (version 4.3.0-nightly-2023-09-06, commit abcdef, Release)\n",
      stderr = "",
      success = true,
    },
    {
      match = "elan dump-state --no-net",
      exitCode = 0,
      stdout = "{\n  \"toolchains\": {\n    \"installed\": [\n      { \"resolved_name\": \"stable\", \"path\": \"/home/test/.elan/toolchains/stable\" },\n      { \"resolved_name\": \"nightly-2023-09-06\", \"path\": \"/home/test/.elan/toolchains/nightly-2023-09-06\" },\n      { \"resolved_name\": \"lean-dev\", \"path\": \"/home/test/.elan/toolchains/lean-dev\" }\n    ],\n    \"default\": {\n      \"unresolved\": \"stable\",\n      \"resolved\": { \"live\": \"stable\", \"cached\": \"stable\" }\n    },\n    \"active_override\": {\n      \"unresolved\": \"nightly-2023-09-06\",\n      \"reason\": \"overridden by '/work/project/lean-toolchain'\"\n    },\n    \"resolved_active\": { \"live\": \"nightly-2023-09-06\", \"cached\": \"nightly-2023-09-06\" }\n  }\n}\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 3,
    resultName = "lean-dev",
    resultVersion = "lean-dev",
  }
}
