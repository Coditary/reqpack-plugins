return {
  name = "zig update remote url",
  request = {
    action = "update",
    system = "zig",
    packages = {
      { name = "https://example.com/demo.tar.gz" }
    },
  },
  fixtureDirs = {
    "/home/test/.cache/reqpack/zig/records",
    "/home/test/.cache/reqpack/zig/sources",
    "/home/test/.cache/reqpack/zig/global-cache",
  },
  fixtureFiles = {
    {
      path = "/home/test/.cache/reqpack/zig/records/https_example_com_demo_tar_gz.tsv",
      content = "id\thttps://example.com/demo.tar.gz\nname\tdemo\nsourceKind\turl\ntarget\thttps://example.com/demo.tar.gz\nhash\t1220old\ninstallMode\tfetch\nmirrorPath\t/home/test/.cache/reqpack/zig/sources/https_example_com_demo_tar_gz\nhomepage\thttps://example.com/demo.tar.gz\nflags\t\nupdatedAt\t1\n",
    },
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
      match = "ZIG_GLOBAL_CACHE_DIR='/home/test/.cache/reqpack/zig/global-cache' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' zig fetch --global-cache-dir '/home/test/.cache/reqpack/zig/global-cache' 'https://example.com/demo.tar.gz'",
      exitCode = 0,
      stdout = "1220new\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/home/test/.cache/reqpack/zig/sources/https_example_com_demo_tar_gz'",
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
      match = [[mkdir -p '/home/test/.cache/reqpack/zig/records' && printf %s 'id	https://example.com/demo.tar.gz
name	demo
sourceKind	url
target	https://example.com/demo.tar.gz
hash	1220new
installMode	fetch
mirrorPath	/home/test/.cache/reqpack/zig/sources/https_example_com_demo_tar_gz
homepage	https://example.com/demo.tar.gz
flags	
updatedAt	0
' > '/home/test/.cache/reqpack/zig/records/https_example_com_demo_tar_gz.tsv']],
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
      "ZIG_GLOBAL_CACHE_DIR='/home/test/.cache/reqpack/zig/global-cache' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' zig fetch --global-cache-dir '/home/test/.cache/reqpack/zig/global-cache' 'https://example.com/demo.tar.gz'",
      "mkdir -p '/home/test/.cache/reqpack/zig/sources/https_example_com_demo_tar_gz'",
      "mkdir -p '/home/test/.cache/reqpack/zig/records'",
      "mkdir -p '/home/test/.cache/reqpack/zig/sources'",
      "mkdir -p '/home/test/.cache/reqpack/zig/records'",
      [[mkdir -p '/home/test/.cache/reqpack/zig/records' && printf %s 'id	https://example.com/demo.tar.gz
name	demo
sourceKind	url
target	https://example.com/demo.tar.gz
hash	1220new
installMode	fetch
mirrorPath	/home/test/.cache/reqpack/zig/sources/https_example_com_demo_tar_gz
homepage	https://example.com/demo.tar.gz
flags	
updatedAt	0
' > '/home/test/.cache/reqpack/zig/records/https_example_com_demo_tar_gz.tsv']],
    },
    events = { "updated", "success" },
    result = true,
  }
}
