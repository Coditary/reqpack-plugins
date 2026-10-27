return {
  name = "oobabooga info model",
  request = {
    action = "info",
    system = "oobabooga",
    prompt = "local:/models/Qwen3.gguf",
  },
  fixtureRoot = "../fixtures-info-model",
  fixtureDirs = {
    "home/.local/share/oobabooga/reqpack",
  },
  fixtureFiles = {
    {
      path = "home/.local/share/oobabooga/reqpack/projections.json",
      content = [[{"projections":[{"package_id":"local:/models/Qwen3.gguf","source_path":"/models/Qwen3.gguf","target_name":"Qwen3.gguf","target_path":"${fixtureRoot}/home/.local/share/oobabooga/user_data/models/Qwen3.gguf","source_kind":"file","installed_at":"2026-05-28T12:00:00Z"}]}]],
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "local:/models/Qwen3.gguf",
    resultVersion = "2026-05-28T12:00:00Z",
  }
}
