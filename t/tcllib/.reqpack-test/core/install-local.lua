return {
  name = "tcllib install local source tree",
  request = {
    action = "installLocal",
    system = "tcllib",
    localPath = "/tmp/opencode/tcllib-local",
    flags = {
      "cache-root=/tmp/opencode/tcllib-cache",
    },
  },
  fixtureDirs = {
    "/tmp/opencode/tcllib-cache",
    "/tmp/opencode/tcllib-cache/state",
    "/tmp/opencode/tcllib-local",
  },
  fixtureFiles = {
    {
      path = "/tmp/opencode/tcllib-local/installer.tcl",
      content = "# local installer placeholder\n",
    },
    {
      path = "/tmp/opencode/tcllib-local/tcllib_version.tcl",
      content = "set tcllib_version 1.21\n",
    },
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
      match = "test -e '/tmp/opencode/tcllib-local/installer.tcl'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/tcllib-local/tcllib_version.tcl'",
      exitCode = 0,
      stdout = "set tcllib_version 1.21\n",
      stderr = "",
      success = true,
    },
    {
      match = "rm -rf '/tmp/opencode/tcllib-cache/current' && mkdir -p '/tmp/opencode/tcllib-cache/current/lib' '/tmp/opencode/tcllib-cache/current/examples' '/tmp/opencode/tcllib-cache/current/doc/html' '/tmp/opencode/tcllib-cache/current/man/mann' && (cd '/tmp/opencode/tcllib-local' && tclsh './installer.tcl' -no-gui -no-wait -pkg-path '/tmp/opencode/tcllib-cache/current/lib/tcllib1.21' -example-path '/tmp/opencode/tcllib-cache/current/examples' -html-path '/tmp/opencode/tcllib-cache/current/doc/html' -nroff-path '/tmp/opencode/tcllib-cache/current/man/mann' -pkgs -examples -html -nroff)",
      exitCode = 0,
      stdout = "Installing Tcllib 1.21\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'tclsh' >/dev/null 2>&1",
      "test -e '/tmp/opencode/tcllib-local/installer.tcl'",
      "cat '/tmp/opencode/tcllib-local/tcllib_version.tcl'",
      "rm -rf '/tmp/opencode/tcllib-cache/current' && mkdir -p '/tmp/opencode/tcllib-cache/current/lib' '/tmp/opencode/tcllib-cache/current/examples' '/tmp/opencode/tcllib-cache/current/doc/html' '/tmp/opencode/tcllib-cache/current/man/mann' && (cd '/tmp/opencode/tcllib-local' && tclsh './installer.tcl' -no-gui -no-wait -pkg-path '/tmp/opencode/tcllib-cache/current/lib/tcllib1.21' -example-path '/tmp/opencode/tcllib-cache/current/examples' -html-path '/tmp/opencode/tcllib-cache/current/doc/html' -nroff-path '/tmp/opencode/tcllib-cache/current/man/mann' -pkgs -examples -html -nroff)",
    },
    events = { "installed", "success" },
  }
}
