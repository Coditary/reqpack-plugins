return {
  name = "sdkman list installed versions",
  request = {
    action = "list",
    system = "sdkman",
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
      match = [=[bash -lc 'if [ -d "$HOME/.sdkman/candidates" ]; then find "$HOME/.sdkman/candidates" -mindepth 1 -maxdepth 1 -type d -printf '\''%f\n'\'' | sort; fi']=],
      exitCode = 0,
      stdout = "groovy\njava\n",
      stderr = "",
      success = true,
    },
    {
      match = [=[bash -lc 'if [ -d "$HOME/.sdkman/candidates/groovy" ]; then find "$HOME/.sdkman/candidates/groovy" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) ! -name current -printf '\''%f\t%y\n'\'' | sort; fi']=],
      exitCode = 0,
      stdout = "4.0.27\td\n4.0.28-local\tl\n",
      stderr = "",
      success = true,
    },
    {
      match = "bash -lc 'if [ -L \"$HOME/.sdkman/candidates/groovy/current\" ]; then target=$(readlink \"$HOME/.sdkman/candidates/groovy/current\"); basename \"$target\"; fi'",
      exitCode = 0,
      stdout = "4.0.27\n",
      stderr = "",
      success = true,
    },
    {
      match = [=[bash -lc 'if [ -d "$HOME/.sdkman/candidates/java" ]; then find "$HOME/.sdkman/candidates/java" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) ! -name current -printf '\''%f\t%y\n'\'' | sort; fi']=],
      exitCode = 0,
      stdout = "21.0.6-tem\td\n",
      stderr = "",
      success = true,
    },
    {
      match = "bash -lc 'if [ -L \"$HOME/.sdkman/candidates/java/current\" ]; then target=$(readlink \"$HOME/.sdkman/candidates/java/current\"); basename \"$target\"; fi'",
      exitCode = 0,
      stdout = "21.0.6-tem\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 3,
    resultName = "groovy",
    resultVersion = "4.0.27",
  }
}
