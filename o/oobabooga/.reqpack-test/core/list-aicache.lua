return {
  name = "oobabooga list aicache model",
  request = {
    action = "list",
    system = "oobabooga",
  },
  fixtureRoot = "../fixtures-list-aicache",
  fixtureDirs = {
    "home/.local/share/oobabooga/reqpack",
    "home/.local/share/aicache/artifacts/huggingface/model-llm/example/Qwen3-GGUF@abcd1234",
  },
  fixtureFiles = {
    {
      path = "home/.local/share/oobabooga/reqpack/projections.json",
      content = [[{"projections":[{"package_id":"aicache:huggingface/model-llm/example/Qwen3-GGUF@abcd1234","package_kind":"aicache","artifact_id":"huggingface/model-llm/example/Qwen3-GGUF@abcd1234","artifact_path":"${fixtureRoot}/home/.local/share/aicache/artifacts/huggingface/model-llm/example/Qwen3-GGUF@abcd1234","target_name":"Qwen3-Q4_K_M.gguf","target_path":"${fixtureRoot}/home/.local/share/oobabooga/user_data/models/Qwen3-Q4_K_M.gguf","source_kind":"file","source_format":"gguf","installed_at":"2026-05-28T14:00:00Z","installed_revision":"abcd1234"}]}]],
    },
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
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 1,
    resultName = "aicache:huggingface/model-llm/example/Qwen3-GGUF@abcd1234",
    resultVersion = "abcd1234",
  }
}
