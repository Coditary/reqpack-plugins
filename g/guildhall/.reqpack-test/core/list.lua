return {
  name = "guildhall list installed packages",
  request = {
    action = "list",
    system = "guildhall",
  },
  fakeExec = {
    { match = "command -v 'guild' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.cache/reqpack/guildhall/home/.config/guildhall'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -e '/home/test/.cache/reqpack/guildhall/home/.config/guildhall/config.scm' || printf %s '' > '/home/test/.cache/reqpack/guildhall/home/.config/guildhall/config.scm'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "HOME='/home/test/.cache/reqpack/guildhall/home' NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C guild --no-config --prefix='/home/test/.cache/reqpack/guildhall/home/.local' list-packages", exitCode = 0, stdout = "i spells 0-20091204 Utility spells\ni srfi 0-20091204 SRFI support\n", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.cache/reqpack/guildhall/reqpack'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "printf %s 'i spells 0-20091204 Utility spells\ni srfi 0-20091204 SRFI support\n' > '/home/test/.cache/reqpack/guildhall/reqpack/last-list.txt'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "spells",
    resultVersion = "0-20091204",
  },
}
