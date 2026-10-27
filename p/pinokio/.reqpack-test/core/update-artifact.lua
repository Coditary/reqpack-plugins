return {
  name = "pinokio update shared artifact",
  request = {
    action = "update",
    system = "pinokio",
    packages = { { name = "artifact:huggingface/model-llm/example/gpt2@abcd1234" } },
  },
  fixtureRoot = "../fixtures-update-artifact",
  fixtureDirs = {
    "home/pinokio/reqpack",
    "home/.local/share/aicache/artifacts/huggingface/model-llm/example/gpt2@abcd1234",
    "home/.local/share/aicache/blobs/sha256/aa",
  },
  fixtureFiles = {
    {
      path = "home/pinokio/reqpack/artifacts.json",
      content = [[{"artifacts":[{"package_id":"artifact:huggingface/model-llm/example/gpt2@abcd1234","artifact_id":"huggingface/model-llm/example/gpt2@abcd1234","artifact_path":"${fixtureRoot}/home/.local/share/aicache/artifacts/huggingface/model-llm/example/gpt2@abcd1234","target_name":"huggingface_model-llm_example_gpt2_abcd1234","target_path":"${fixtureRoot}/home/pinokio/drive/reqpack/artifacts/huggingface_model-llm_example_gpt2_abcd1234","installed_at":"2026-05-28T14:00:00Z","installed_revision":"abcd1234","projection_mode":"workspace-export"}]}]],
    },
    { path = "home/.local/share/aicache/artifacts/huggingface/model-llm/example/gpt2@abcd1234/manifest.json", content = [[{"artifact_id":"huggingface/model-llm/example/gpt2@abcd1234","kind":"model-llm","source":{"registry":"huggingface","repo_id":"example/gpt2","revision":"abcd1234"}}]] },
    { path = "home/.local/share/aicache/artifacts/huggingface/model-llm/example/gpt2@abcd1234/files.json", content = [[{"files":[{"logical_path":"config.json","role":"config","format":"json","blob_id":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","size":4}]}]] },
    { path = "home/.local/share/aicache/artifacts/huggingface/model-llm/example/gpt2@abcd1234/source.json", content = [[{"upstream_metadata":{"source_url":"https://huggingface.co/example/gpt2"}}]] },
    { path = "home/.local/share/aicache/blobs/sha256/aa/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", content = "{}{}" },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "mkdir -p '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -e '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -f '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "rm -rf '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cp '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "date -u +%Y-%m-%dT%H:%M:%SZ", exitCode = 0, stdout = "2026-05-28T15:00:00Z\n", stderr = "", success = true },
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
