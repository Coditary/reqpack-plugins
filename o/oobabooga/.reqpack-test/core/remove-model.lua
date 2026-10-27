return {
  name = "oobabooga remove model",
  request = {
    action = "remove",
    system = "oobabooga",
    packages = {
      { name = "local:${fixtureRoot}/models/Qwen3.gguf" }
    },
  },
  fixtureRoot = "../fixtures-remove-model",
  fixtureDirs = {
    "home/.local/share/oobabooga/user_data/models",
    "home/.local/share/oobabooga/reqpack",
    "models",
  },
  fixtureFiles = {
    {
      path = "models/Qwen3.gguf",
      content = "weights",
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
      match = "mkdir -p '",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
    eventPayloads = {
      deleted = "{1=<lua-value>}",
      success = "ok",
    },
  }
}
