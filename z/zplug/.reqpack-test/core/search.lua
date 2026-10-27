return {
  name = "zplug search registered packages",
  fixtureRoot = "/home/test",
  request = {
    action = "search",
    system = "zplug",
    prompt = "fz",
  },
  fixtureDirs = {
    ".zplug",
  },
  fixtureFiles = {
    { path = ".zplug/packages.zsh", content = "zplug \"zsh-users/zsh-autosuggestions\", as:plugin\nzplug \"junegunn/fzf\", as:command, use:\"bin/fzf\", at:\"v0.58.0\"\n" },
  },
  fakeExec = {
    { match = "cat '/home/test/.zplug/packages.zsh'", exitCode = 0, stdout = "zplug \"zsh-users/zsh-autosuggestions\", as:plugin\nzplug \"junegunn/fzf\", as:command, use:\"bin/fzf\", at:\"v0.58.0\"\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    commands = { "cat '/home/test/.zplug/packages.zsh'" },
    events = { "searched" },
    resultCount = 1,
    resultName = "junegunn/fzf",
    resultVersion = "v0.58.0",
  },
}
