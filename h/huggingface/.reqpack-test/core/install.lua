return {
  name = "huggingface install model",
  request = {
    action = "install",
    system = "huggingface",
    packages = {
      { name = "openai-community/gpt2" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'hf' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "hf download 'openai-community/gpt2'",
      exitCode = 0,
      stdout = "Fetching 2 files: 100%\n/home/test/.cache/huggingface/hub/models--openai-community--gpt2/snapshots/abcd\n",
      stderr = "",
      success = true,
    },
    {
      match = "hf models info 'openai-community/gpt2' --format json",
      exitCode = 0,
      stdout = [[{"id":"openai-community/gpt2","sha":"abcd1234","description":"GPT-2 model","downloads":42,"likes":7,"lastModified":"2026-05-27T12:00:00Z"}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'hf' >/dev/null 2>&1",
      "hf download 'openai-community/gpt2'",
      "hf models info 'openai-community/gpt2' --format json",
    },
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{1=<lua-value>}",
      success = "ok",
    },
  }
}
