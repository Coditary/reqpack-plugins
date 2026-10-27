return {
  name = "pinokio info shared artifact",
  request = {
    action = "info",
    system = "pinokio",
    prompt = "artifact:huggingface/model-llm/example/gpt2@abcd1234",
  },
  fixtureRoot = "../fixtures-info-artifact",
  fixtureDirs = {
    "home/.local/share/aicache/artifacts/huggingface/model-llm/example/gpt2@abcd1234",
  },
  fixtureFiles = {
    { path = "home/.local/share/aicache/artifacts/huggingface/model-llm/example/gpt2@abcd1234/manifest.json", content = [[{"artifact_id":"huggingface/model-llm/example/gpt2@abcd1234","kind":"model-llm","source":{"registry":"huggingface","repo_id":"example/gpt2","revision":"abcd1234"}}]] },
    { path = "home/.local/share/aicache/artifacts/huggingface/model-llm/example/gpt2@abcd1234/files.json", content = [[{"files":[{"logical_path":"config.json","role":"config","format":"json","blob_id":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","size":2}]}]] },
    { path = "home/.local/share/aicache/artifacts/huggingface/model-llm/example/gpt2@abcd1234/source.json", content = [[{"upstream_metadata":{"source_url":"https://huggingface.co/example/gpt2"}}]] },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "aicache/artifacts/huggingface/model-llm/example/gpt2@abcd1234'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "artifact:huggingface/model-llm/example/gpt2@abcd1234",
    resultVersion = "abcd1234",
  }
}
