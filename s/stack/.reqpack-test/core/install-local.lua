return {
  name = "stack install local project",
  fixtureRoot = "/tmp/opencode/stack-install-local-case",
  request = {
    action = "install",
    system = "stack",
    localPath = "/tmp/opencode/stack-install-local-case/fixtures/local-tool/tool.cabal",
    flags = { "cache-root=/tmp/opencode/stack-install-local-case/fixtures/cache-root" },
  },
  fixtureDirs = {
    "fixtures/cache-root",
    "fixtures/local-tool",
  },
  fixtureFiles = {
    {
      path = "fixtures/local-tool/stack.yaml",
      content = "resolver: lts-23.14\npackages: ['.']\n",
    },
    {
      path = "fixtures/local-tool/tool.cabal",
      content = "name: tool\nversion: 0.1.0\nsynopsis: Local tool\nlicense: MIT\nexecutable tool\n",
    },
  },
  fakeExec = {
    {
      match = "command -v 'stack' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/stack-install-local-case/fixtures/local-tool/tool.cabal'",
      exitCode = 0,
      stdout = "name: tool\nversion: 0.1.0\nsynopsis: Local tool\nlicense: MIT\nexecutable tool\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/stack-install-local-case/fixtures/local-tool/stack.yaml'",
      exitCode = 0,
      stdout = "resolver: lts-23.14\npackages: ['.']\n",
      stderr = "",
      success = true,
    },
    {
      match = "cd '/tmp/opencode/stack-install-local-case/fixtures/local-tool' && STACK_ROOT='/tmp/opencode/stack-install-local-case/fixtures/cache-root/stack-root' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' stack --color never --local-bin-path /tmp/opencode/stack-install-local-case/fixtures/cache-root/bin install",
      exitCode = 0,
      stdout = "Installed tool\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'stack' >/dev/null 2>&1",
      "cat '/tmp/opencode/stack-install-local-case/fixtures/cache-root/state/installed.tsv'",
      "cat '/tmp/opencode/stack-install-local-case/fixtures/local-tool/tool.cabal'",
      "cat '/tmp/opencode/stack-install-local-case/fixtures/local-tool/stack.yaml'",
      "cd '/tmp/opencode/stack-install-local-case/fixtures/local-tool' && STACK_ROOT='/tmp/opencode/stack-install-local-case/fixtures/cache-root/stack-root' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' stack --color never --local-bin-path /tmp/opencode/stack-install-local-case/fixtures/cache-root/bin install"
    },
    events = { "installed", "success" },
  },
}
