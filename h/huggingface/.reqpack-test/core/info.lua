return {
  name = "huggingface info space",
  request = {
    action = "info",
    system = "huggingface",
    prompt = "space:HuggingFaceH4/zephyr-chat",
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
      match = "hf spaces info 'HuggingFaceH4/zephyr-chat' --format json",
      exitCode = 0,
      stdout = [[{"id":"HuggingFaceH4/zephyr-chat","sha":"space-rev","description":"Chat demo space","lastModified":"2026-05-27T12:00:00Z"}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'hf' >/dev/null 2>&1",
      "hf spaces info 'HuggingFaceH4/zephyr-chat' --format json",
    },
    events = { "informed" },
    resultCount = 1,
    resultName = "zephyr-chat",
    resultVersion = "space-rev",
  }
}
