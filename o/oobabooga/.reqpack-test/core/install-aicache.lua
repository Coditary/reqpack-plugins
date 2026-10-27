return {
  name = "oobabooga install aicache model",
  request = {
    action = "install",
    system = "oobabooga",
    packages = {
      { name = "aicache:huggingface/model-llm/example/Qwen3-GGUF@abcd1234" }
    },
  },
  fixtureRoot = "../fixtures-install-aicache",
  fixtureDirs = {
    "home/.local/share/oobabooga/reqpack",
    "home/.local/share/aicache/artifacts/huggingface/model-llm/example/Qwen3-GGUF@abcd1234",
    "home/.local/share/aicache/blobs/sha256/bb",
  },
  fixtureFiles = {
    {
      path = "home/.local/share/aicache/artifacts/huggingface/model-llm/example/Qwen3-GGUF@abcd1234/manifest.json",
      content = [[{"artifact_id":"huggingface/model-llm/example/Qwen3-GGUF@abcd1234","kind":"model-llm","source":{"registry":"huggingface","repo_id":"example/Qwen3-GGUF","revision":"abcd1234"}}]],
    },
    {
      path = "home/.local/share/aicache/artifacts/huggingface/model-llm/example/Qwen3-GGUF@abcd1234/files.json",
      content = [[{"files":[{"logical_path":"Qwen3-Q4_K_M.gguf","role":"weights","format":"gguf","blob_id":"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","size":7}]}]],
    },
    {
      path = "home/.local/share/aicache/artifacts/huggingface/model-llm/example/Qwen3-GGUF@abcd1234/source.json",
      content = [[{"upstream_metadata":{"source_url":"https://huggingface.co/example/Qwen3-GGUF"}}]],
    },
    {
      path = "home/.local/share/aicache/blobs/sha256/bb/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      content = "weights",
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "mkdir -p '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "aicache/artifacts/huggingface/model-llm/example/Qwen3-GGUF@abcd1234'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "aicache/blobs/sha256/bb/", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "user_data/models/Qwen3-Q4_K_M.gguf'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -f '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -d '", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "cp '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "wc -c < '", exitCode = 0, stdout = "7\n", stderr = "", success = true },
    { match = "date -u +%Y-%m-%dT%H:%M:%SZ", exitCode = 0, stdout = "2026-05-28T14:00:00Z\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{1=<lua-value>}",
      success = "ok",
    },
  }
}
