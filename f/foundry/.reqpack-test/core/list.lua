return {
  name = "foundry list installed dependencies",
  fixtureRoot = "/tmp/opencode/foundry-list-case",
  request = {
    action = "list",
    system = "foundry",
    flags = { "dir=/tmp/opencode/foundry-list-case/project" },
  },
  fixtureDirs = {
    "project/lib/forge-std",
    "project/lib/openzeppelin-contracts",
  },
  fixtureFiles = {
    {
      path = "project/foundry.toml",
      content = "libs = [\"lib\"]\ncache_path = \"cache\"\n",
    },
    {
      path = "project/.gitmodules",
      content = "[submodule \"lib/forge-std\"]\n\tpath = lib/forge-std\n\turl = https://github.com/foundry-rs/forge-std\n[submodule \"lib/openzeppelin-contracts\"]\n\tpath = lib/openzeppelin-contracts\n\turl = https://github.com/OpenZeppelin/openzeppelin-contracts\n",
    },
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/foundry-list-case/project/foundry.toml'",
      exitCode = 0,
      stdout = "libs = [\"lib\"]\ncache_path = \"cache\"\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/foundry-list-case/project/.gitmodules'",
      exitCode = 0,
      stdout = "[submodule \"lib/forge-std\"]\n\tpath = lib/forge-std\n\turl = https://github.com/foundry-rs/forge-std\n[submodule \"lib/openzeppelin-contracts\"]\n\tpath = lib/openzeppelin-contracts\n\turl = https://github.com/OpenZeppelin/openzeppelin-contracts\n",
      stderr = "",
      success = true,
    },
    {
      match = "bash -lc 'if [ -d \"/tmp/opencode/foundry-list-case/project/lib\" ]; then find \"/tmp/opencode/foundry-list-case/project/lib\" -mindepth 1 -maxdepth 1 -type d -printf '\''%f\\n'\'' | sort; fi'",
      exitCode = 0,
      stdout = "forge-std\nopenzeppelin-contracts\n",
      stderr = "",
      success = true,
    },
    {
      match = "git -C /tmp/opencode/foundry-list-case/project/lib/forge-std rev-parse --short HEAD",
      exitCode = 0,
      stdout = "1a2b3c4\n",
      stderr = "",
      success = true,
    },
    {
      match = "git -C /tmp/opencode/foundry-list-case/project/lib/forge-std describe --tags --exact-match",
      exitCode = 1,
      stdout = "",
      stderr = "fatal\n",
      success = false,
    },
    {
      match = "git -C /tmp/opencode/foundry-list-case/project/lib/openzeppelin-contracts rev-parse --short HEAD",
      exitCode = 0,
      stdout = "5d6e7f8\n",
      stderr = "",
      success = true,
    },
    {
      match = "git -C /tmp/opencode/foundry-list-case/project/lib/openzeppelin-contracts describe --tags --exact-match",
      exitCode = 0,
      stdout = "v5.0.2\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 2,
    resultName = "forge-std",
    resultVersion = "1a2b3c4",
    events = { "listed" },
  },
}
