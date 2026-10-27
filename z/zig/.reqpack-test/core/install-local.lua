return {
  name = "zig install local path",
  request = {
    action = "installLocal",
    system = "zig",
    localPath = "/tmp/demo-zig-package",
  },
  fixtureDirs = {
    "/home/test/.cache/reqpack/zig/records",
    "/home/test/.cache/reqpack/zig/sources",
    "/home/test/.cache/reqpack/zig/global-cache",
  },
  fakeExec = {
    {
      match = "command -v 'zig' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/home/test/.cache/reqpack/zig/global-cache'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -e '/tmp/demo-zig-package'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "ZIG_GLOBAL_CACHE_DIR='/home/test/.cache/reqpack/zig/global-cache' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' zig fetch --global-cache-dir '/home/test/.cache/reqpack/zig/global-cache' '/tmp/demo-zig-package'",
      exitCode = 0,
      stdout = "1220cafebabe\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/home/test/.cache/reqpack/zig/sources/tmp_demo_zig_package'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/home/test/.cache/reqpack/zig/records'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/home/test/.cache/reqpack/zig/sources'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = [[mkdir -p '/home/test/.cache/reqpack/zig/records' && printf %s 'id	/tmp/demo-zig-package
name	demo-zig-package
sourceKind	path
target	/tmp/demo-zig-package
hash	1220cafebabe
installMode	fetch
mirrorPath	/home/test/.cache/reqpack/zig/sources/tmp_demo_zig_package
flags	
updatedAt	0
' > '/home/test/.cache/reqpack/zig/records/tmp_demo_zig_package.tsv']],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'zig' >/dev/null 2>&1",
      "mkdir -p '/home/test/.cache/reqpack/zig/global-cache'",
      "ZIG_GLOBAL_CACHE_DIR='/home/test/.cache/reqpack/zig/global-cache' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' zig fetch --global-cache-dir '/home/test/.cache/reqpack/zig/global-cache' '/tmp/demo-zig-package'",
      "mkdir -p '/home/test/.cache/reqpack/zig/sources/tmp_demo_zig_package'",
      "mkdir -p '/home/test/.cache/reqpack/zig/records'",
      "mkdir -p '/home/test/.cache/reqpack/zig/sources'",
      "mkdir -p '/home/test/.cache/reqpack/zig/records'",
      [[mkdir -p '/home/test/.cache/reqpack/zig/records' && printf %s 'id	/tmp/demo-zig-package
name	demo-zig-package
sourceKind	path
target	/tmp/demo-zig-package
hash	1220cafebabe
installMode	fetch
mirrorPath	/home/test/.cache/reqpack/zig/sources/tmp_demo_zig_package
flags	
updatedAt	0
' > '/home/test/.cache/reqpack/zig/records/tmp_demo_zig_package.tsv']],
    },
    events = { "installed", "success" },
    result = true,
  }
}
