return {
  name = "oobabooga remove aicache model",
  request = {
    action = "remove",
    system = "oobabooga",
    packages = {
      { name = "aicache:huggingface/model-llm/example/Qwen3-GGUF@abcd1234" }
    },
  },
  fixtureRoot = "../fixtures-remove-aicache",
  fixtureDirs = {
    "home/.local/share/oobabooga/reqpack",
    "home/.local/share/oobabooga/user_data/models",
  },
  fixtureFiles = {
    {
      path = "home/.local/share/oobabooga/reqpack/projections.json",
      content = [[{"projections":[{"package_id":"aicache:huggingface/model-llm/example/Qwen3-GGUF@abcd1234","package_kind":"aicache","artifact_id":"huggingface/model-llm/example/Qwen3-GGUF@abcd1234","artifact_path":"${fixtureRoot}/home/.local/share/aicache/artifacts/huggingface/model-llm/example/Qwen3-GGUF@abcd1234","target_name":"Qwen3-Q4_K_M.gguf","target_path":"${fixtureRoot}/home/.local/share/oobabooga/user_data/models/Qwen3-Q4_K_M.gguf","source_kind":"file","source_format":"gguf","installed_at":"2026-05-28T14:00:00Z","installed_revision":"abcd1234"}]}]],
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "test -e '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "rm -rf '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '", exitCode = 0, stdout = "", stderr = "", success = true },
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
