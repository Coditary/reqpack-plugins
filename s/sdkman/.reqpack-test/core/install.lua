return {
  name = "sdkman install exact version",
  request = {
    action = "install",
    system = "sdkman",
    packages = {
      { action = "install", name = "groovy", version = "4.0.28" }
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
      match = "bash -lc 'export SDKMAN_DIR=\"$HOME/.sdkman\"; export sdkman_auto_answer=true; export sdkman_colour_enable=false; export sdkman_auto_complete=false; export sdkman_auto_env=false; export sdkman_selfupdate_feature=false; export sdkman_healthcheck_enable=false; export USE=n; export PAGER=cat; export TERM=dumb; . \"$SDKMAN_DIR/bin/sdkman-init.sh\" >/dev/null 2>&1; sdk install \"groovy\" \"4.0.28\"'",
      exitCode = 0,
      stdout = "Installing: groovy 4.0.28\nDone installing!\n",
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
  },
  expect = {
    success = true,
    commands = {
      "test -f \"$HOME/.sdkman/bin/sdkman-init.sh\"",
      "bash -lc 'export SDKMAN_DIR=\"$HOME/.sdkman\"; export sdkman_auto_answer=true; export sdkman_colour_enable=false; export sdkman_auto_complete=false; export sdkman_auto_env=false; export sdkman_selfupdate_feature=false; export sdkman_healthcheck_enable=false; export USE=n; export PAGER=cat; export TERM=dumb; . \"$SDKMAN_DIR/bin/sdkman-init.sh\" >/dev/null 2>&1; sdk install \"groovy\" \"4.0.28\"'",
      "bash -lc 'if [ -L \"$HOME/.sdkman/candidates/groovy/current\" ]; then target=$(readlink \"$HOME/.sdkman/candidates/groovy/current\"); basename \"$target\"; fi'",
    },
    events = { "installed", "success" },
  }
}
