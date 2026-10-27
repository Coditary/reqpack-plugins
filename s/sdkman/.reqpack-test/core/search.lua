return {
  name = "sdkman search cached candidates",
  request = {
    action = "search",
    system = "sdkman",
    prompt = "groo",
  },
  fakeExec = {
    {
      match = "test -f \"$HOME/.sdkman/bin/sdkman-init.sh\"",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = [=[bash -lc 'if [ -f "$HOME/.sdkman/var/candidates" ]; then tr '\'','\'' '\''\n'\'' < "$HOME/.sdkman/var/candidates"; fi']=],
      exitCode = 0,
      stdout = "java\ngroovy\nkotlin\n",
      stderr = "",
      success = true,
    },
    {
      match = [=[bash -lc 'if [ -d "$HOME/.sdkman/candidates" ]; then find "$HOME/.sdkman/candidates" -mindepth 1 -maxdepth 1 -type d -printf '\''%f\n'\'' | sort; fi']=],
      exitCode = 0,
      stdout = "groovy\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "groovy",
  }
}
