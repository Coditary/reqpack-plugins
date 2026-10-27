return {
  name = "oobabooga update model",
  request = {
    action = "update",
    system = "oobabooga",
    packages = {
      { name = "local:${fixtureRoot}/models/Qwen3.gguf" }
    },
  },
  fixtureRoot = "../fixtures-update-model",
  fixtureDirs = {
    "home/.local/share/oobabooga/reqpack",
    "models",
  },
  fixtureFiles = {
    {
      path = "models/Qwen3.gguf",
      content = "weights-new",
    },
    {
      path = "home/.local/share/oobabooga/reqpack/projections.json",
      content = [[{"projections":[{"package_id":"local:${fixtureRoot}/models/Qwen3.gguf","source_path":"${fixtureRoot}/models/Qwen3.gguf","target_name":"Qwen3.gguf","target_path":"${fixtureRoot}/home/.local/share/oobabooga/user_data/models/Qwen3.gguf","source_kind":"file","installed_at":"2026-05-28T12:00:00Z"}]}]],
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    {
      match = "mkdir -p '",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -d '",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "test -f '",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -e '",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "rm -rf '",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cp '",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "wc -c < '",
      exitCode = 0,
      stdout = "11\n",
      stderr = "",
      success = true,
    },
    {
      match = "date -u +%Y-%m-%dT%H:%M:%SZ",
      exitCode = 0,
      stdout = "2026-05-28T13:00:00Z\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
    eventPayloads = {
      updated = "{1=<lua-value>}",
      success = "ok",
    },
  }
}
