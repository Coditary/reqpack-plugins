return {
  name = "huggingface list aicache",
  request = {
    action = "list",
    system = "huggingface",
  },
  fixtureRoot = "../fixtures-aicache-list",
  fixtureFiles = {
    {
      path = "data/aicache/views/by-source/huggingface/model/openai-community__gpt2/current.json",
      content = [[{"artifact_id":"huggingface/model-llm/openai-community/gpt2@abcd1234","artifact_path":"${fixtureRoot}/data/aicache/artifacts/huggingface/model-llm/openai-community/gpt2@abcd1234"}]],
    },
    {
      path = "data/aicache/artifacts/huggingface/model-llm/openai-community/gpt2@abcd1234/manifest.json",
      content = [[{"artifact_id":"huggingface/model-llm/openai-community/gpt2@abcd1234","kind":"model-llm","tasks":["causal-lm"],"source":{"registry":"huggingface","repo_type":"model","repo_id":"openai-community/gpt2","revision":"abcd1234","refs":["main"]},"created_at":"2026-05-27T12:00:00Z"}]],
    },
    {
      path = "data/aicache/artifacts/huggingface/model-llm/openai-community/gpt2@abcd1234/files.json",
      content = [[{"files":[{"logical_path":"model.safetensors","role":"weights","format":"safetensors","blob_id":"sha256:11aa22bb33cc44dd55ee66ff77889900aa11bb22cc33dd44ee55ff6677889900","size":123456}]}]],
    },
    {
      path = "data/aicache/artifacts/huggingface/model-llm/openai-community/gpt2@abcd1234/source.json",
      content = [[{"fetched_at":"2026-05-27T12:00:00Z","upstream_metadata":{"description":"GPT-2 model","updated_at":"2026-05-27T12:00:00Z","homepage":"https://huggingface.co/openai-community/gpt2","source_url":"https://huggingface.co/openai-community/gpt2"}}]],
    },
  },
  environment = {
    XDG_DATA_HOME = "${fixtureRoot}/data",
  },
  fakeExec = {
    {
      match = "find '",
      exitCode = 0,
      stdout = ".reqpack-test/fixtures-aicache-list/data/aicache/views/by-source/huggingface/model/openai-community__gpt2/current.json\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 1,
    resultName = "gpt2",
    resultVersion = "abcd1234",
  }
}
