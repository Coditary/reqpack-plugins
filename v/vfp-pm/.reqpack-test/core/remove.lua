return {
  name = "vfp-pm remove via saved installer",
  fixtureRoot = "/tmp/opencode/vfp-pm-remove",
  request = {
    action = "remove",
    system = "vfp-pm",
    packages = {
      { name = "SFMail" },
    },
    flags = {
      "cache-root=/tmp/opencode/vfp-pm-remove/cache",
      "project=/tmp/opencode/vfp-pm-remove/project",
      "bridge=vfp-bridge",
    },
  },
  fixtureDirs = {
    "cache/bridge",
    "project/Packages/SFMail",
  },
  fixtureFiles = {
    {
      path = "cache/bridge/remove-sfmail.json",
      content = [[{"success":true,"name":"SFMail"}]],
    },
    {
      path = "cache/bridge/remove-sfmail.prg",
      content = "* generated\n",
    },
    {
      path = "project/Packages/SFMail/SFMailInstaller.prg",
      content = "define class SFMailInstaller as Custom\nenddefine\n",
    },
    {
      path = "project/Packages/packages.xml",
      content = "<VFPData><Packages><Name>SFMail</Name><Version>2.1.0</Version><Date>2026-05-03</Date><RefCount>1</RefCount></Packages></VFPData>",
    },
  },
  fakeExec = {
    {
      match = "test -d '/tmp/opencode/vfp-pm-remove/cache/bridge' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "vfp-bridge --script '/tmp/opencode/vfp-pm-remove/cache/bridge/remove-sfmail.prg' --result '/tmp/opencode/vfp-pm-remove/cache/bridge/remove-sfmail.json'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/vfp-pm-remove/cache/bridge/remove-sfmail.json'",
      exitCode = 0,
      stdout = [[{"success":true,"name":"SFMail"}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/vfp-pm-remove/project/Packages/packages.xml'",
      exitCode = 0,
      stdout = "<VFPData><Packages><Name>SFMail</Name><Version>2.1.0</Version><Date>2026-05-03</Date><RefCount>1</RefCount></Packages></VFPData>",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "cat '/tmp/opencode/vfp-pm-remove/project/Packages/packages.xml'",
      "test -d '/tmp/opencode/vfp-pm-remove/cache/bridge' >/dev/null 2>&1",
      "vfp-bridge --script '/tmp/opencode/vfp-pm-remove/cache/bridge/remove-sfmail.prg' --result '/tmp/opencode/vfp-pm-remove/cache/bridge/remove-sfmail.json'",
      "cat '/tmp/opencode/vfp-pm-remove/cache/bridge/remove-sfmail.json'",
    },
    events = { "deleted", "success" },
  },
}
