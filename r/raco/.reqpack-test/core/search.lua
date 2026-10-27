return {
  name = "raco search catalog packages",
  request = {
    action = "search",
    system = "raco",
    prompt = "shell",
  },
  fakeExec = {
    {
      match = "command -v 'raco' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "raco pkg catalog-show --all --only-names",
      exitCode = 0,
      stdout = "shell-completion\nmini-shell\nmacro-debugger\n",
      stderr = "",
      success = true,
    },
    {
      match = "raco pkg catalog-show 'shell-completion'",
      exitCode = 0,
      stdout = [=[Package name: shell-completion
 Author: test
 Source: https://pkgs.racket-lang.org/package/shell-completion
 Checksum: deadbeef0001
 Tags: terminal, shell
 Description: Completion library for shells
 Ring: 1
 Dependencies:
  base
  racket-doc version 1.0
]=],
      stderr = "",
      success = true,
    },
    {
      match = "raco pkg show --all --long -d --scope user 'shell-completion'",
      exitCode = 0,
      stdout = "",
      stderr = "package not installed\n",
      success = false,
    },
    {
      match = "raco pkg catalog-show 'mini-shell'",
      exitCode = 0,
      stdout = [=[Package name: mini-shell
 Author: test
 Source: https://pkgs.racket-lang.org/package/mini-shell
 Checksum: deadbeef0002
 Description: Tiny shell implementation
]=],
      stderr = "",
      success = true,
    },
    {
      match = "raco pkg show --all --long -d --scope user 'mini-shell'",
      exitCode = 0,
      stdout = "",
      stderr = "package not installed\n",
      success = false,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "shell-completion",
    resultVersion = "deadbeef0001",
  }
}
