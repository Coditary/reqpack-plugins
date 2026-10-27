return {
  name = "huggingface install local spec",
  request = {
    action = "install",
    system = "huggingface",
    localPath = "dataset:HuggingFaceFW/fineweb@main//README.md",
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
      match = "hf download 'HuggingFaceFW/fineweb' 'README.md' --repo-type dataset --revision 'main'",
      exitCode = 0,
      stdout = "/tmp/README.md\n",
      stderr = "",
      success = true,
    },
    {
      match = "hf datasets info 'HuggingFaceFW/fineweb' --revision 'main' --format json",
      exitCode = 0,
      stdout = [[{"id":"HuggingFaceFW/fineweb","sha":"rev-main","description":"FineWeb dataset","lastModified":"2026-05-27T12:00:00Z"}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'hf' >/dev/null 2>&1",
      "hf download 'HuggingFaceFW/fineweb' 'README.md' --repo-type dataset --revision 'main'",
      "hf datasets info 'HuggingFaceFW/fineweb' --revision 'main' --format json",
    },
    events = { "installed", "success" },
  }
}
