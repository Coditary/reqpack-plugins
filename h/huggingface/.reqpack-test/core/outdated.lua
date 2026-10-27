return {
  name = "huggingface outdated dataset sha differs",
  request = {
    action = "outdated",
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
      match = "hf cache ls --format json --revisions",
      exitCode = 0,
      stdout = [=[[{"id":"dataset/HuggingFaceFW/fineweb","repo_id":"HuggingFaceFW/fineweb","repo_type":"dataset","revision":"oldrev","size":"1.0G","last_accessed":"today","last_modified":"today","refs":["main"]},{"id":"model/openai-community/gpt2","repo_id":"openai-community/gpt2","repo_type":"model","revision":"same-rev","size":"512M","last_accessed":"today","last_modified":"today","refs":["main"]},{"id":"space:ignored/no-ref","repo_id":"ignored/no-ref","repo_type":"space","revision":"pinnedrev","size":"1M","last_accessed":"today","last_modified":"today","refs":[]}]]=],
      stderr = "",
      success = true,
    },
    {
      match = "hf datasets info 'HuggingFaceFW/fineweb' --revision 'main' --format json",
      exitCode = 0,
      stdout = [[{"id":"HuggingFaceFW/fineweb","sha":"newrev","description":"FineWeb dataset","lastModified":"2026-05-27T13:00:00Z"}]],
      stderr = "",
      success = true,
    },
    {
      match = "hf models info 'openai-community/gpt2' --revision 'main' --format json",
      exitCode = 0,
      stdout = [[{"id":"openai-community/gpt2","sha":"same-rev","description":"GPT-2 model","lastModified":"2026-05-27T13:00:00Z"}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'hf' >/dev/null 2>&1",
      "hf cache ls --format json --revisions",
      "hf datasets info 'HuggingFaceFW/fineweb' --revision 'main' --format json",
      "hf models info 'openai-community/gpt2' --revision 'main' --format json",
    },
    events = { "outdated" },
    resultCount = 1,
    resultName = "fineweb",
    resultVersion = "oldrev",
  }
}
