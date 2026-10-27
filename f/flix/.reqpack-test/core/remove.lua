return {
  name = "flix remove tracked dependency",
  fixtureRoot = "/tmp/opencode/flix-remove-case",
  request = {
    action = "remove",
    system = "flix",
    flags = { "project-root=/tmp/opencode/flix-remove-case" },
    packages = {
      { packageId = "flix/museum", name = "flix/museum" }
    },
  },
  fixtureDirs = {
    ".reqpack-data/flix-cache",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/flix-cache/flix.toml",
      content = "[package]\nname        = \"reqpack-flix-cache\"\ndescription = \"ReqPack managed Flix dependency cache\"\nversion     = \"0.0.0\"\nflix        = \"0.0.0\"\nlicense     = \"MIT\"\nauthors     = [\"ReqPack <reqpack@example.invalid>\"]\n\n[dependencies]\n\"github:flix/museum\" = \"1.4.0\"\n",
    },
  },
  fakeExec = {
    {
      match = "command -v flix >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/flix-remove-case/.reqpack-data/flix-cache/flix.toml'",
      exitCode = 0,
      stdout = "[package]\nname        = \"reqpack-flix-cache\"\ndescription = \"ReqPack managed Flix dependency cache\"\nversion     = \"0.0.0\"\nflix        = \"0.0.0\"\nlicense     = \"MIT\"\nauthors     = [\"ReqPack <reqpack@example.invalid>\"]\n\n[dependencies]\n\"github:flix/museum\" = \"1.4.0\"\n",
      stderr = "",
      success = true,
    },
    {
      match = [=[mkdir -p '/tmp/opencode/flix-remove-case/.reqpack-data/flix-cache' && printf %s '[package]
name        = "reqpack-flix-cache"
description = "ReqPack managed Flix dependency cache"
version     = "0.0.0"
flix        = "0.0.0"
license     = "MIT"
authors     = ["ReqPack <reqpack@example.invalid>"]

[dependencies]
' > '/tmp/opencode/flix-remove-case/.reqpack-data/flix-cache/flix.toml']=],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "cat '/tmp/opencode/flix-remove-case/.reqpack-data/flix-cache/flix.toml'",
      [=[mkdir -p '/tmp/opencode/flix-remove-case/.reqpack-data/flix-cache' && printf %s '[package]
name        = "reqpack-flix-cache"
description = "ReqPack managed Flix dependency cache"
version     = "0.0.0"
flix        = "0.0.0"
license     = "MIT"
authors     = ["ReqPack <reqpack@example.invalid>"]

[dependencies]
' > '/tmp/opencode/flix-remove-case/.reqpack-data/flix-cache/flix.toml']=]
    },
    events = { "deleted", "success" },
  }
}
