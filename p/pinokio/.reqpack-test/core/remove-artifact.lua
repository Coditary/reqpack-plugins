return {
  name = "pinokio remove shared artifact",
  request = {
    action = "remove",
    system = "pinokio",
    packages = { { name = "artifact:huggingface/model-llm/example/gpt2@abcd1234" } },
  },
  fixtureRoot = "../fixtures-remove-artifact",
  fixtureDirs = {
    "home/pinokio/reqpack",
  },
  fixtureFiles = {
    {
      path = "home/pinokio/reqpack/artifacts.json",
      content = [[{"artifacts":[{"package_id":"artifact:huggingface/model-llm/example/gpt2@abcd1234","artifact_id":"huggingface/model-llm/example/gpt2@abcd1234","artifact_path":"${fixtureRoot}/home/.local/share/aicache/artifacts/huggingface/model-llm/example/gpt2@abcd1234","target_name":"huggingface_model-llm_example_gpt2_abcd1234","target_path":"${fixtureRoot}/home/pinokio/drive/reqpack/artifacts/huggingface_model-llm_example_gpt2_abcd1234","installed_at":"2026-05-28T14:00:00Z","installed_revision":"abcd1234","projection_mode":"workspace-export"}]}]],
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
