return {
  name = "pinokio list shared artifact",
  request = {
    action = "list",
    system = "pinokio",
  },
  fixtureRoot = "../fixtures-list-artifact",
  fixtureDirs = {
    "home/pinokio/reqpack",
    "home/.local/share/aicache/artifacts/huggingface/model-llm/example/gpt2@abcd1234",
  },
  fixtureFiles = {
    {
      path = "home/pinokio/reqpack/artifacts.json",
      content = [[{"artifacts":[{"package_id":"artifact:huggingface/model-llm/example/gpt2@abcd1234","artifact_id":"huggingface/model-llm/example/gpt2@abcd1234","artifact_path":"${fixtureRoot}/home/.local/share/aicache/artifacts/huggingface/model-llm/example/gpt2@abcd1234","target_name":"huggingface_model-llm_example_gpt2_abcd1234","target_path":"${fixtureRoot}/home/pinokio/drive/reqpack/artifacts/huggingface_model-llm_example_gpt2_abcd1234","installed_at":"2026-05-28T14:00:00Z","installed_revision":"abcd1234","projection_mode":"workspace-export"}]}]],
    },
    { path = "home/.local/share/aicache/artifacts/huggingface/model-llm/example/gpt2@abcd1234/manifest.json", content = [[{"artifact_id":"huggingface/model-llm/example/gpt2@abcd1234","kind":"model-llm","source":{"registry":"huggingface","repo_id":"example/gpt2","revision":"abcd1234"}}]] },
    { path = "home/.local/share/aicache/artifacts/huggingface/model-llm/example/gpt2@abcd1234/files.json", content = [[{"files":[{"logical_path":"config.json","role":"config","format":"json","blob_id":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","size":2}]}]] },
    { path = "home/.local/share/aicache/artifacts/huggingface/model-llm/example/gpt2@abcd1234/source.json", content = [[{"upstream_metadata":{"source_url":"https://huggingface.co/example/gpt2"}}]] },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 1,
    resultName = "artifact:huggingface/model-llm/example/gpt2@abcd1234",
    resultVersion = "abcd1234",
  }
}
