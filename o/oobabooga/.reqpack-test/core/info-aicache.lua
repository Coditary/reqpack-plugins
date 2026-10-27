return {
  name = "oobabooga info aicache model",
  request = {
    action = "info",
    system = "oobabooga",
    prompt = "aicache:huggingface/model-llm/example/Qwen3-GGUF@abcd1234",
  },
  fixtureRoot = "../fixtures-info-aicache",
  fixtureDirs = {
    "home/.local/share/aicache/artifacts/huggingface/model-llm/example/Qwen3-GGUF@abcd1234",
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
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "aicache/artifacts/huggingface/model-llm/example/Qwen3-GGUF@abcd1234'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "aicache:huggingface/model-llm/example/Qwen3-GGUF@abcd1234",
    resultVersion = "abcd1234",
  }
}
