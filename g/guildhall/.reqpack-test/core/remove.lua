return {
  name = "guildhall remove package",
  request = {
    action = "remove",
    system = "guildhall",
    packages = {
      { action = "remove", name = "spells" }
    },
  },
  fakeExec = {
    { match = "command -v 'guild' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.cache/reqpack/guildhall/home/.config/guildhall'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -e '/home/test/.cache/reqpack/guildhall/home/.config/guildhall/config.scm' || printf %s '' > '/home/test/.cache/reqpack/guildhall/home/.config/guildhall/config.scm'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "HOME='/home/test/.cache/reqpack/guildhall/home' NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C guild --no-config --prefix='/home/test/.cache/reqpack/guildhall/home/.local' remove 'spells'", exitCode = 0, stdout = "Removing spells ...\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  },
}
