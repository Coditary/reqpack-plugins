return {
  name = "huggingface update dataset",
  request = {
    action = "update",
    system = "huggingface",
    packages = {
      { name = "dataset:HuggingFaceFW/fineweb" }
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
      match = "hf download 'HuggingFaceFW/fineweb' --repo-type dataset --force-download",
      exitCode = 0,
      stdout = "Fetching files\n",
      stderr = "",
      success = true,
    },
    {
      match = "hf datasets info 'HuggingFaceFW/fineweb' --format json",
      exitCode = 0,
      stdout = [[{"id":"HuggingFaceFW/fineweb","sha":"newrev","description":"FineWeb dataset","lastModified":"2026-05-27T13:00:00Z"}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'hf' >/dev/null 2>&1",
      "hf download 'HuggingFaceFW/fineweb' --repo-type dataset --force-download",
      "hf datasets info 'HuggingFaceFW/fineweb' --format json",
    },
    events = { "updated", "success" },
    eventPayloads = {
      updated = "{1=<lua-value>}",
      success = "ok",
    },
  }
}
