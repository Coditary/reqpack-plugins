return {
  name = "oobabooga install local model",
  request = {
    action = "installLocal",
    system = "oobabooga",
    localPath = "${fixtureRoot}/models/Qwen3.gguf",
  },
  fixtureRoot = "../fixtures-install-local",
  fixtureDirs = {
    "models",
    "home/.local/share/oobabooga/reqpack",
    "home/.local/share/oobabooga/user_data/models",
  },
  fixtureFiles = {
    {
      path = "models/Qwen3.gguf",
      content = "weights",
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    {
      match = "mkdir -p '",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -d '",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "test -f '",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cp '",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "wc -c < '",
      exitCode = 0,
      stdout = "7\n",
      stderr = "",
      success = true,
    },
    {
      match = "date -u +%Y-%m-%dT%H:%M:%SZ",
      exitCode = 0,
      stdout = "2026-05-28T12:00:00Z\n",
      stderr = "",
      success = true,
    },
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
