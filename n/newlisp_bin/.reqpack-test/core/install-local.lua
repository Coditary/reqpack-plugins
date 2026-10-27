return {
  name = "newlisp_bin install local executable",
  fixtureRoot = "/tmp/opencode/newlisp-bin-install-local",
  request = {
    action = "installLocal",
    system = "newlisp_bin",
    localPath = "${fixtureRoot}/downloads/newlisp",
    version = "10.7.5-local",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "variant=macos-utf8",
    },
  },
  fixtureDirs = {
    "${fixtureRoot}/downloads",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/downloads/newlisp",
      content = "#!/bin/sh\nexit 0\n",
    },
  },
  fakeExec = {
    { match = "rm -rf '${fixtureRoot}/.reqpack-data/newlisp_bin/installs/macos-utf8/10.7.5'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/newlisp_bin/installs/macos-utf8/10.7.5/bin'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cp '${fixtureRoot}/downloads/newlisp' '${fixtureRoot}/.reqpack-data/newlisp_bin/installs/macos-utf8/10.7.5/bin/newlisp'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "chmod +x '${fixtureRoot}/.reqpack-data/newlisp_bin/installs/macos-utf8/10.7.5/bin/newlisp'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-data/newlisp_bin/installed.tsv'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/newlisp_bin'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/newlisp_bin'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "printf %s 'newlisp/macos-utf8\tnewlisp\t10.7.5\tmacos-utf8\t${fixtureRoot}/.reqpack-data/newlisp_bin/installs/macos-utf8/10.7.5\t${fixtureRoot}/.reqpack-data/newlisp_bin/installs/macos-utf8/10.7.5/bin/newlisp\t${fixtureRoot}/downloads/newlisp\tManaged local newLISP executable\n' > '${fixtureRoot}/.reqpack-data/newlisp_bin/installed.tsv'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
