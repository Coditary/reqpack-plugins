return {
  name = "longtalk install latest unique pack",
  request = {
    action = "install",
    system = "longtalk",
    packages = {
      { action = "install", name = "lflat" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'swilgt' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "findall(Registry,packs::available(Registry,lflat),Registries)",
      exitCode = 0,
      stdout = "REQPACK\tRESOLVED\ttalkshow\tlflat\t2:1:0\n",
      stderr = "",
      success = true,
    },
    {
      match = "packs::install(talkshow,lflat,2:1:0,[])",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
