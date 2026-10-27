return {
  name = "guildhall search derived from list-packages all",
  request = {
    action = "search",
    system = "guildhall",
    prompt = "spell",
    flags = { "repo=http://example.test/doro" },
  },
  fakeExec = {
    { match = "command -v 'guild' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.cache/reqpack/guildhall/home/.config/guildhall'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -e '/home/test/.cache/reqpack/guildhall/home/.config/guildhall/config.scm' || printf %s '' > '/home/test/.cache/reqpack/guildhall/home/.config/guildhall/config.scm'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "HOME='/home/test/.cache/reqpack/guildhall/home' NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C guild --repo='http://example.test/doro' --no-config --prefix='/home/test/.cache/reqpack/guildhall/home/.local' update", exitCode = 0, stdout = "Fetching http://example.test/doro/available.scm\n", stderr = "", success = true },
    { match = "HOME='/home/test/.cache/reqpack/guildhall/home' NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C guild --repo='http://example.test/doro' --no-config --prefix='/home/test/.cache/reqpack/guildhall/home/.local' list-packages --all", exitCode = 0, stdout = "n spells 0-20091205 Utility spells\nn conjure 0-20091204 Console tools\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "spells",
    resultVersion = "0-20091205",
  },
}
