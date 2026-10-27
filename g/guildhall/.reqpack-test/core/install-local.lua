return {
  name = "guildhall install local bundle",
  request = {
    action = "install",
    system = "guildhall",
    localPath = "${fixtureRoot}/bundle/spells.zip",
  },
  fixtureDirs = {
    "${fixtureRoot}/bundle",
  },
  fixtureFiles = {
    ["bundle/spells.zip"] = "fake bundle",
  },
  fakeExec = {
    { match = "command -v 'guild' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.cache/reqpack/guildhall/home/.config/guildhall'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -e '/home/test/.cache/reqpack/guildhall/home/.config/guildhall/config.scm' || printf %s '' > '/home/test/.cache/reqpack/guildhall/home/.config/guildhall/config.scm'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -e '${fixtureRoot}/bundle/spells.zip'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "HOME='/home/test/.cache/reqpack/guildhall/home' NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C guild --no-config --prefix='/home/test/.cache/reqpack/guildhall/home/.local' show-bundle '${fixtureRoot}/bundle/spells.zip'", exitCode = 0, stdout = "Package: spells\nVersion: 0-20091204\nDescription: Spells package\n\nPackage: srfi\nVersion: 0-20091204\nDescription: SRFI package\n", stderr = "", success = true },
    { match = "HOME='/home/test/.cache/reqpack/guildhall/home' NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C guild --no-config --prefix='/home/test/.cache/reqpack/guildhall/home/.local' install --bundle='${fixtureRoot}/bundle/spells.zip' 'spells' 'srfi'", exitCode = 0, stdout = "Installing spells (0-20091204) ...\nInstalling srfi (0-20091204) ...\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
