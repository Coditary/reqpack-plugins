return {
  name = "flix install github dependency",
  fixtureRoot = "/tmp/opencode/flix-install-case",
  request = {
    action = "install",
    system = "flix",
    flags = { "project-root=/tmp/opencode/flix-install-case" },
    packages = {
      { packageId = "flix/museum", name = "flix/museum" }
    },
  },
  fixtureDirs = {
    ".reqpack-data/flix-cache",
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/flix-install-case/.reqpack-data/flix-cache/flix.toml'",
      exitCode = 1,
      stdout = "",
      stderr = "missing\n",
      success = false,
    },
    {
      match = "cat '/tmp/opencode/flix-install-case/.reqpack-data/flix-cache/github/flix__museum.json'",
      exitCode = 1,
      stdout = "",
      stderr = "missing\n",
      success = false,
    },
    {
      match = "cat '/tmp/opencode/flix-install-case/.reqpack-data/flix-cache/github/flix__museum__releases.json'",
      exitCode = 1,
      stdout = "",
      stderr = "missing\n",
      success = false,
    },
    {
      match = "command -v flix >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL -H 'Accept: application/vnd.github+json' https://api.github.com/repos/flix/museum -o /tmp/opencode/flix-install-case/.reqpack-data/flix-cache/github/flix__museum.json",
      exitCode = 0,
      stdout = [[{"full_name":"flix/museum","name":"museum","description":"Museum package","html_url":"https://github.com/flix/museum","homepage":""}]],
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL -H 'Accept: application/vnd.github+json' https://api.github.com/repos/flix/museum/releases -o /tmp/opencode/flix-install-case/.reqpack-data/flix-cache/github/flix__museum__releases.json",
      exitCode = 0,
      stdout = [=[[{"tag_name":"v1.4.0"}]]=],
      stderr = "",
      success = true,
    },
    {
      match = [=[mkdir -p '/tmp/opencode/flix-install-case/.reqpack-data/flix-cache' && printf %s '[package]
name        = "reqpack-flix-cache"
description = "ReqPack managed Flix dependency cache"
version     = "0.0.0"
flix        = "0.0.0"
license     = "MIT"
authors     = ["ReqPack <reqpack@example.invalid>"]

[dependencies]
"github:flix/museum" = "1.4.0"
' > '/tmp/opencode/flix-install-case/.reqpack-data/flix-cache/flix.toml']=],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/flix-install-case/.reqpack-data/flix-cache/src/Main.flix'",
      exitCode = 1,
      stdout = "",
      stderr = "missing\n",
      success = false,
    },
    {
      match = [=[mkdir -p '/tmp/opencode/flix-install-case/.reqpack-data/flix-cache/src' && printf %s 'def main(): Unit \ IO =
    ()
' > '/tmp/opencode/flix-install-case/.reqpack-data/flix-cache/src/Main.flix']=],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cd '/tmp/opencode/flix-install-case/.reqpack-data/flix-cache' && flix check --yes",
      exitCode = 0,
      stdout = "ok\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "cat '/tmp/opencode/flix-install-case/.reqpack-data/flix-cache/flix.toml'",
      "cat '/tmp/opencode/flix-install-case/.reqpack-data/flix-cache/github/flix__museum.json'",
      "curl -fsSL -H 'Accept: application/vnd.github+json' https://api.github.com/repos/flix/museum -o /tmp/opencode/flix-install-case/.reqpack-data/flix-cache/github/flix__museum.json",
      "cat '/tmp/opencode/flix-install-case/.reqpack-data/flix-cache/github/flix__museum__releases.json'",
      "curl -fsSL -H 'Accept: application/vnd.github+json' https://api.github.com/repos/flix/museum/releases -o /tmp/opencode/flix-install-case/.reqpack-data/flix-cache/github/flix__museum__releases.json",
      [=[mkdir -p '/tmp/opencode/flix-install-case/.reqpack-data/flix-cache' && printf %s '[package]
name        = "reqpack-flix-cache"
description = "ReqPack managed Flix dependency cache"
version     = "0.0.0"
flix        = "0.0.0"
license     = "MIT"
authors     = ["ReqPack <reqpack@example.invalid>"]

[dependencies]
"github:flix/museum" = "1.4.0"
' > '/tmp/opencode/flix-install-case/.reqpack-data/flix-cache/flix.toml']=],
      "cat '/tmp/opencode/flix-install-case/.reqpack-data/flix-cache/src/Main.flix'",
      [=[mkdir -p '/tmp/opencode/flix-install-case/.reqpack-data/flix-cache/src' && printf %s 'def main(): Unit \ IO =
    ()
' > '/tmp/opencode/flix-install-case/.reqpack-data/flix-cache/src/Main.flix']=],
      "cd '/tmp/opencode/flix-install-case/.reqpack-data/flix-cache' && flix check --yes"
    },
    events = { "installed", "success" },
  }
}
