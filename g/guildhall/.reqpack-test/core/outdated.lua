return {
  name = "guildhall outdated derived from show",
  request = {
    action = "outdated",
    system = "guildhall",
    flags = { "repo=http://example.test/doro" },
  },
  fakeExec = {
    { match = "command -v 'guild' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.cache/reqpack/guildhall/home/.config/guildhall'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -e '/home/test/.cache/reqpack/guildhall/home/.config/guildhall/config.scm' || printf %s '' > '/home/test/.cache/reqpack/guildhall/home/.config/guildhall/config.scm'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "HOME='/home/test/.cache/reqpack/guildhall/home' NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C guild --repo='http://example.test/doro' --no-config --prefix='/home/test/.cache/reqpack/guildhall/home/.local' update", exitCode = 0, stdout = "Fetching http://example.test/doro/available.scm\n", stderr = "", success = true },
    { match = "HOME='/home/test/.cache/reqpack/guildhall/home' NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C guild --no-config --prefix='/home/test/.cache/reqpack/guildhall/home/.local' list-packages", exitCode = 0, stdout = "i spells 0-20091204 Utility spells\ni srfi 0-20091204 SRFI support\n", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.cache/reqpack/guildhall/reqpack'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "printf %s 'i spells 0-20091204 Utility spells\ni srfi 0-20091204 SRFI support\n' > '/home/test/.cache/reqpack/guildhall/reqpack/last-list.txt'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "HOME='/home/test/.cache/reqpack/guildhall/home' NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C guild --repo='http://example.test/doro' --no-config --prefix='/home/test/.cache/reqpack/guildhall/home/.local' show 'spells'", exitCode = 0, stdout = "Package: spells\nStatus: installed\nVersion: 0-20091204\nDescription: Utility spells\n\nPackage: spells\nVersion: 0-20091205\nDescription: Utility spells\n", stderr = "", success = true },
    { match = "HOME='/home/test/.cache/reqpack/guildhall/home' NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C guild --repo='http://example.test/doro' --no-config --prefix='/home/test/.cache/reqpack/guildhall/home/.local' show 'srfi'", exitCode = 0, stdout = "Package: srfi\nStatus: installed\nVersion: 0-20091204\nDescription: SRFI support\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "spells",
    resultVersion = "0-20091204",
  },
}
