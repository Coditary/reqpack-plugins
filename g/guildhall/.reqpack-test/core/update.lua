return {
  name = "guildhall update named package",
  request = {
    action = "update",
    system = "guildhall",
    packages = {
      { action = "update", name = "spells", flags = { "repo=http://example.test/doro" } }
    },
  },
  fakeExec = {
    { match = "command -v 'guild' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.cache/reqpack/guildhall/home/.config/guildhall'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -e '/home/test/.cache/reqpack/guildhall/home/.config/guildhall/config.scm' || printf %s '' > '/home/test/.cache/reqpack/guildhall/home/.config/guildhall/config.scm'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "HOME='/home/test/.cache/reqpack/guildhall/home' NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C guild --repo='http://example.test/doro' --no-config --prefix='/home/test/.cache/reqpack/guildhall/home/.local' update", exitCode = 0, stdout = "Fetching http://example.test/doro/available.scm\n", stderr = "", success = true },
    { match = "HOME='/home/test/.cache/reqpack/guildhall/home' NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C guild --repo='http://example.test/doro' --no-config --prefix='/home/test/.cache/reqpack/guildhall/home/.local' install 'spells'", exitCode = 0, stdout = "Installing spells (0-20091205) ...\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  },
}
