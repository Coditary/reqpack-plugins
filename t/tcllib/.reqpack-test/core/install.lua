return {
  name = "tcllib install latest release",
  request = {
    action = "install",
    system = "tcllib",
    flags = {
      "cache-root=/tmp/opencode/tcllib-cache",
    },
    packages = {
      { name = "tcllib" },
    },
  },
  fixtureDirs = {
    "/tmp/opencode/tcllib-cache",
    "/tmp/opencode/tcllib-cache/state",
  },
  fakeExec = {
    {
      match = "command -v 'tclsh' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'curl' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'tar' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'curl' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://api.github.com/repos/tcltk/tcllib/tags?per_page=100'",
      exitCode = 0,
      stdout = "[{\"name\":\"tcllib-2-0\"},{\"name\":\"tcllib-1-21\"}]",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/tcllib-cache/archives' '/tmp/opencode/tcllib-cache/sources' '/tmp/opencode/tcllib-cache/state' && curl -fsSL 'https://codeload.github.com/tcltk/tcllib/tar.gz/refs/tags/tcllib-2-0' -o '/tmp/opencode/tcllib-cache/archives/tcllib-2-0.tar.gz'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "rm -rf '/tmp/opencode/tcllib-cache/sources/tcllib-tcllib-2-0' && mkdir -p '/tmp/opencode/tcllib-cache/sources' && tar -xzf '/tmp/opencode/tcllib-cache/archives/tcllib-2-0.tar.gz' -C '/tmp/opencode/tcllib-cache/sources'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "rm -rf '/tmp/opencode/tcllib-cache/current' && mkdir -p '/tmp/opencode/tcllib-cache/current/lib' '/tmp/opencode/tcllib-cache/current/examples' '/tmp/opencode/tcllib-cache/current/doc/html' '/tmp/opencode/tcllib-cache/current/man/mann' && (cd '/tmp/opencode/tcllib-cache/sources/tcllib-tcllib-2-0' && tclsh './installer.tcl' -no-gui -no-wait -pkg-path '/tmp/opencode/tcllib-cache/current/lib/tcllib2.0' -example-path '/tmp/opencode/tcllib-cache/current/examples' -html-path '/tmp/opencode/tcllib-cache/current/doc/html' -nroff-path '/tmp/opencode/tcllib-cache/current/man/mann' -pkgs -examples -html -nroff)",
      exitCode = 0,
      stdout = "Installing Tcllib 2.0\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'tclsh' >/dev/null 2>&1",
      "command -v 'curl' >/dev/null 2>&1",
      "command -v 'tar' >/dev/null 2>&1",
      "command -v 'curl' >/dev/null 2>&1",
      "curl -fsSL 'https://api.github.com/repos/tcltk/tcllib/tags?per_page=100'",
      "mkdir -p '/tmp/opencode/tcllib-cache/archives' '/tmp/opencode/tcllib-cache/sources' '/tmp/opencode/tcllib-cache/state' && curl -fsSL 'https://codeload.github.com/tcltk/tcllib/tar.gz/refs/tags/tcllib-2-0' -o '/tmp/opencode/tcllib-cache/archives/tcllib-2-0.tar.gz'",
      "rm -rf '/tmp/opencode/tcllib-cache/sources/tcllib-tcllib-2-0' && mkdir -p '/tmp/opencode/tcllib-cache/sources' && tar -xzf '/tmp/opencode/tcllib-cache/archives/tcllib-2-0.tar.gz' -C '/tmp/opencode/tcllib-cache/sources'",
      "rm -rf '/tmp/opencode/tcllib-cache/current' && mkdir -p '/tmp/opencode/tcllib-cache/current/lib' '/tmp/opencode/tcllib-cache/current/examples' '/tmp/opencode/tcllib-cache/current/doc/html' '/tmp/opencode/tcllib-cache/current/man/mann' && (cd '/tmp/opencode/tcllib-cache/sources/tcllib-tcllib-2-0' && tclsh './installer.tcl' -no-gui -no-wait -pkg-path '/tmp/opencode/tcllib-cache/current/lib/tcllib2.0' -example-path '/tmp/opencode/tcllib-cache/current/examples' -html-path '/tmp/opencode/tcllib-cache/current/doc/html' -nroff-path '/tmp/opencode/tcllib-cache/current/man/mann' -pkgs -examples -html -nroff)",
    },
    events = { "installed", "success" },
  }
}
