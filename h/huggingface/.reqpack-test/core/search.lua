return {
  name = "huggingface search datasets",
  request = {
    action = "search",
    system = "huggingface",
    prompt = "dataset:fineweb",
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
      match = "hf datasets ls --search 'fineweb' --limit 10 --format json",
      exitCode = 0,
      stdout = [=[[{"id":"HuggingFaceFW/fineweb","description":"FineWeb dataset","lastModified":"2026-05-27T12:00:00Z"},{"id":"my-org/fineweb-mini","description":"Small FineWeb slice","lastModified":"2026-05-26T12:00:00Z"}]]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'hf' >/dev/null 2>&1",
      "hf datasets ls --search 'fineweb' --limit 10 --format json",
    },
    events = { "searched" },
    resultCount = 2,
    resultName = "fineweb",
  }
}
