return {
  name = "oobabooga list",
  request = {
    action = "list",
    system = "oobabooga",
  },
  fixtureRoot = "../fixtures-list",
  fixtureDirs = {
    "home/.local/share/oobabooga/reqpack",
  },
  fixtureFiles = {
    {
      path = "home/.local/share/oobabooga/reqpack/app.json",
      content = [[{"version":"4.2","asset_name":"textgen-portable-4.2-linux-cpu.tar.gz","install_root":"${fixtureRoot}/home/.local/share/oobabooga/text-generation-webui"}]],
    },
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
    events = { "listed" },
    resultCount = 2,
    resultName = "app:oobabooga",
    resultVersion = "4.2",
  }
}
