return {
  name = "vfp-pm install local installer",
  fixtureRoot = "/tmp/opencode/vfp-pm-install-local",
  request = {
    action = "install",
    system = "vfp-pm",
    localPath = "/tmp/opencode/vfp-pm-install-local/local/SFMailInstaller.prg",
    flags = {
      "cache-root=/tmp/opencode/vfp-pm-install-local/cache",
      "project=/tmp/opencode/vfp-pm-install-local/project",
      "bridge=vfp-bridge",
    },
  },
  fixtureDirs = {
    "cache/bridge",
    "local",
    "project/Packages/SFMail",
  },
  fixtureFiles = {
    {
      path = "local/SFMailInstaller.prg",
      content = "define class SFMailInstaller as Custom\nenddefine\n",
    },
    {
      path = "cache/bridge/install-local-sfmail.json",
      content = [[{"success":true,"name":"SFMail","version":"2.1.0"}]],
    },
    {
      path = "cache/bridge/install-local-sfmail.prg",
      content = "* generated\n",
    },
    {
      path = "project/Packages/packages.xml",
      content = "<VFPData><Packages><Name>SFMail</Name><Version>2.1.0</Version><Date>2026-05-03</Date><RefCount>1</RefCount></Packages></VFPData>",
    },
  },
  fakeExec = {
    {
      match = "test -d '/tmp/opencode/vfp-pm-install-local/cache/bridge' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "vfp-bridge --script '/tmp/opencode/vfp-pm-install-local/cache/bridge/install-local-sfmail.prg' --result '/tmp/opencode/vfp-pm-install-local/cache/bridge/install-local-sfmail.json'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/vfp-pm-install-local/cache/bridge/install-local-sfmail.json'",
      exitCode = 0,
      stdout = [[{"success":true,"name":"SFMail","version":"2.1.0"}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/vfp-pm-install-local/project/Packages/packages.xml'",
      exitCode = 0,
      stdout = "<VFPData><Packages><Name>SFMail</Name><Version>2.1.0</Version><Date>2026-05-03</Date><RefCount>1</RefCount></Packages></VFPData>",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "test -d '/tmp/opencode/vfp-pm-install-local/cache/bridge' >/dev/null 2>&1",
      "vfp-bridge --script '/tmp/opencode/vfp-pm-install-local/cache/bridge/install-local-sfmail.prg' --result '/tmp/opencode/vfp-pm-install-local/cache/bridge/install-local-sfmail.json'",
      "cat '/tmp/opencode/vfp-pm-install-local/cache/bridge/install-local-sfmail.json'",
      "cat '/tmp/opencode/vfp-pm-install-local/project/Packages/packages.xml'",
    },
    events = { "installed", "success" },
  },
}
