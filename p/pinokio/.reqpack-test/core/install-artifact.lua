return {
  name = "pinokio install shared artifact",
  request = {
    action = "install",
    system = "pinokio",
    packages = { { name = "artifact:huggingface/model-llm/example/gpt2@abcd1234" } },
  },
  fixtureRoot = "../fixtures-install-artifact",
  fixtureDirs = {
    "home/pinokio/reqpack",
    "home/.local/share/aicache/artifacts/huggingface/model-llm/example/gpt2@abcd1234",
    "home/.local/share/aicache/blobs/sha256/aa",
    "home/.local/share/aicache/blobs/sha256/bb",
  },
  fixtureFiles = {
    { path = "home/.local/share/aicache/artifacts/huggingface/model-llm/example/gpt2@abcd1234/manifest.json", content = [[{"artifact_id":"huggingface/model-llm/example/gpt2@abcd1234","kind":"model-llm","source":{"registry":"huggingface","repo_id":"example/gpt2","revision":"abcd1234"}}]] },
    { path = "home/.local/share/aicache/artifacts/huggingface/model-llm/example/gpt2@abcd1234/files.json", content = [[{"files":[{"logical_path":"config.json","role":"config","format":"json","blob_id":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","size":2},{"logical_path":"weights/model.gguf","role":"weights","format":"gguf","blob_id":"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","size":7}]}]] },
    { path = "home/.local/share/aicache/artifacts/huggingface/model-llm/example/gpt2@abcd1234/source.json", content = [[{"upstream_metadata":{"source_url":"https://huggingface.co/example/gpt2"}}]] },
    { path = "home/.local/share/aicache/blobs/sha256/aa/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", content = "{}" },
    { path = "home/.local/share/aicache/blobs/sha256/bb/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", content = "weights" },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "mkdir -p '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "aicache/artifacts/huggingface/model-llm/example/gpt2@abcd1234'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "aicache/blobs/sha256/aa/", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "aicache/blobs/sha256/bb/", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "pinokio/drive/reqpack/artifacts/huggingface_model-llm_example_gpt2_abcd1234'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -f '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cp '", exitCode = 0, stdout = "", stderr = "", success = true },
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
