return {
  name = "huggingface list cache",
  request = {
    action = "list",
    system = "huggingface",
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
      match = "hf cache ls --format json",
      exitCode = 0,
      stdout = [=[[{"id":"dataset/HuggingFaceFW/fineweb","repo_id":"HuggingFaceFW/fineweb","repo_type":"dataset","size":"1.0G","last_accessed":"today","last_modified":"today","refs":["main"]},{"id":"model/openai-community/gpt2","repo_id":"openai-community/gpt2","repo_type":"model","size":"512M","last_accessed":"today","last_modified":"today","refs":["main"]}]]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'hf' >/dev/null 2>&1",
      "hf cache ls --format json",
    },
    events = { "listed" },
    resultCount = 2,
    resultName = "fineweb",
    resultVersion = "main",
  }
}
