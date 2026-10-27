return {
  name = "paru install local",
  request = {
    action = "install",
    system = "paru",
    localPath = "/tmp/demo-1.0.0-1-x86_64.pkg.tar.zst",
  },
  fakeExec = {
    {
      match = "command -v paru >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh HOME=\"$HOME\" XDG_CONFIG_HOME=\"$HOME/.config\" XDG_CACHE_HOME=\"$HOME/.cache\" XDG_DATA_HOME=\"$HOME/.local/share\" XDG_STATE_HOME=\"$HOME/.local/state\" AURDEST=\"$HOME/.cache/paru\" paru -U --noconfirm /tmp/demo-1.0.0-1-x86_64.pkg.tar.zst",
      exitCode = 0,
      stdout = "local install ok\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{localTarget=true, path=/tmp/demo-1.0.0-1-x86_64.pkg.tar.zst}",
      success = "ok",
    },
  }
}
