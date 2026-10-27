return {
  name = "foundry install dependency",
  request = {
    action = "install",
    system = "foundry",
    packages = {
      { name = "OpenZeppelin/openzeppelin-contracts", version = "v5.0.2" },
    },
  },
  fakeExec = {
    {
      match = "command -v 'forge' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "forge install --root . OpenZeppelin/openzeppelin-contracts@v5.0.2",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'forge' >/dev/null 2>&1",
      "forge install --root . OpenZeppelin/openzeppelin-contracts@v5.0.2",
    },
    events = { "installed", "success" },
  },
}
