return {
  name = "guildhall info prefers installed block",
  request = {
    action = "info",
    system = "guildhall",
    prompt = "spells",
    flags = { "repo=http://example.test/doro" },
  },
  fakeExec = {
    { match = "command -v 'guild' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.cache/reqpack/guildhall/home/.config/guildhall'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -e '/home/test/.cache/reqpack/guildhall/home/.config/guildhall/config.scm' || printf %s '' > '/home/test/.cache/reqpack/guildhall/home/.config/guildhall/config.scm'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "HOME='/home/test/.cache/reqpack/guildhall/home' NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C guild --repo='http://example.test/doro' --no-config --prefix='/home/test/.cache/reqpack/guildhall/home/.local' update", exitCode = 0, stdout = "Fetching http://example.test/doro/available.scm\n", stderr = "", success = true },
    { match = "HOME='/home/test/.cache/reqpack/guildhall/home' NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C guild --repo='http://example.test/doro' --no-config --prefix='/home/test/.cache/reqpack/guildhall/home/.local' show 'spells'", exitCode = 0, stdout = "Package: spells\nStatus: installed\nVersion: 0-20091204\nDepends: srfi\nHomepage: http://example.test/spells\nDescription: Utility spells\n more text\n\nPackage: spells\nVersion: 0-20091205\nDepends: srfi\nDescription: Utility spells newer\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultName = "spells",
    resultVersion = "0-20091204",
  },
}
