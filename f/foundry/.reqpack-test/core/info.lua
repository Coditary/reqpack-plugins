return {
  name = "foundry info installed dependency",
  fixtureRoot = "/tmp/opencode/foundry-info-case",
  request = {
    action = "info",
    system = "foundry",
    prompt = "foundry-rs/forge-std",
    flags = { "dir=/tmp/opencode/foundry-info-case/project" },
  },
  fixtureDirs = {
    "project/lib/forge-std",
  },
  fixtureFiles = {
    {
      path = "project/foundry.toml",
      content = "libs = [\"lib\"]\ncache_path = \"cache\"\n",
    },
    {
      path = "project/.gitmodules",
      content = "[submodule \"lib/forge-std\"]\n\tpath = lib/forge-std\n\turl = https://github.com/foundry-rs/forge-std\n",
    },
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/foundry-info-case/project/foundry.toml'",
      exitCode = 0,
      stdout = "libs = [\"lib\"]\ncache_path = \"cache\"\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/foundry-info-case/project/.gitmodules'",
      exitCode = 0,
      stdout = "[submodule \"lib/forge-std\"]\n\tpath = lib/forge-std\n\turl = https://github.com/foundry-rs/forge-std\n",
      stderr = "",
      success = true,
    },
    {
      match = "bash -lc 'if [ -d \"/tmp/opencode/foundry-info-case/project/lib\" ]; then find \"/tmp/opencode/foundry-info-case/project/lib\" -mindepth 1 -maxdepth 1 -type d -printf '\''%f\\n'\'' | sort; fi'",
      exitCode = 0,
      stdout = "forge-std\n",
      stderr = "",
      success = true,
    },
    {
      match = "git -C /tmp/opencode/foundry-info-case/project/lib/forge-std rev-parse --short HEAD",
      exitCode = 0,
      stdout = "1a2b3c4\n",
      stderr = "",
      success = true,
    },
    {
      match = "git -C /tmp/opencode/foundry-info-case/project/lib/forge-std describe --tags --exact-match",
      exitCode = 1,
      stdout = "",
      stderr = "fatal\n",
      success = false,
    },
  },
  expect = {
    success = true,
    resultName = "forge-std",
    resultVersion = "1a2b3c4",
    events = { "informed" },
  },
}
