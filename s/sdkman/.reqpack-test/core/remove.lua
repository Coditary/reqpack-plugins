return {
  name = "sdkman remove exact version",
  request = {
    action = "remove",
    system = "sdkman",
    packages = {
      { action = "remove", name = "groovy", version = "4.0.27" }
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
      match = "bash -lc 'export SDKMAN_DIR=\"$HOME/.sdkman\"; export sdkman_auto_answer=true; export sdkman_colour_enable=false; export sdkman_auto_complete=false; export sdkman_auto_env=false; export sdkman_selfupdate_feature=false; export sdkman_healthcheck_enable=false; export USE=n; export PAGER=cat; export TERM=dumb; . \"$SDKMAN_DIR/bin/sdkman-init.sh\" >/dev/null 2>&1; sdk uninstall \"groovy\" \"4.0.27\"'",
      exitCode = 0,
      stdout = "Uninstalling groovy 4.0.27...\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  }
}
