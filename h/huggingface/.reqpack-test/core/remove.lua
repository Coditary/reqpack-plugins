return {
  name = "huggingface remove model cache entry",
  request = {
    action = "remove",
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
      match = "hf cache rm 'model/openai-community/gpt2' --yes",
      exitCode = 0,
      stdout = "Deleted 1 repo(s) and 1 revision(s); freed 1.9G.\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'hf' >/dev/null 2>&1",
      "hf cache rm 'model/openai-community/gpt2' --yes",
    },
    events = { "deleted", "success" },
    eventPayloads = {
      deleted = "{1=<lua-value>}",
      success = "ok",
    },
  }
}
