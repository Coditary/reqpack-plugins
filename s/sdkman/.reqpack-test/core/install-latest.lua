return {
  name = "sdkman install latest default version",
  request = {
    action = "install",
    system = "sdkman",
    packages = {
      { action = "install", name = "java" }
    },
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
      match = [=[bash -lc 'export SDKMAN_DIR="$HOME/.sdkman"; export sdkman_auto_answer=true; export sdkman_colour_enable=false; export sdkman_auto_complete=false; export sdkman_auto_env=false; export sdkman_selfupdate_feature=false; export sdkman_healthcheck_enable=false; export USE=n; export PAGER=cat; export TERM=dumb; . "$SDKMAN_DIR/bin/sdkman-init.sh" >/dev/null 2>&1; printf '\''%s\n'\'' "$(__sdkman_secure_curl "${SDKMAN_CANDIDATES_API}/candidates/default/java")"']=],
      exitCode = 0,
      stdout = "21.0.6-tem\n",
      stderr = "",
      success = true,
    },
    {
      match = "bash -lc 'export SDKMAN_DIR=\"$HOME/.sdkman\"; export sdkman_auto_answer=true; export sdkman_colour_enable=false; export sdkman_auto_complete=false; export sdkman_auto_env=false; export sdkman_selfupdate_feature=false; export sdkman_healthcheck_enable=false; export USE=n; export PAGER=cat; export TERM=dumb; . \"$SDKMAN_DIR/bin/sdkman-init.sh\" >/dev/null 2>&1; sdk install \"java\" \"21.0.6-tem\"'",
      exitCode = 0,
      stdout = "Installing: java 21.0.6-tem\nDone installing!\n",
      stderr = "",
      success = true,
    },
    {
      match = "bash -lc 'if [ -L \"$HOME/.sdkman/candidates/java/current\" ]; then target=$(readlink \"$HOME/.sdkman/candidates/java/current\"); basename \"$target\"; fi'",
      exitCode = 0,
      stdout = "17.0.12-tem\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    resultCount = 0,
  }
}
