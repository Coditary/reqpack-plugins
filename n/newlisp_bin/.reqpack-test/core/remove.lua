return {
  name = "newlisp_bin remove managed install",
  fixtureRoot = "/tmp/opencode/newlisp-bin-remove",
  request = {
    action = "remove",
    system = "newlisp_bin",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "variant=source",
    },
    packages = {
      { name = "newlisp" },
    },
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/.reqpack-data/newlisp_bin/installed.tsv",
      content = "newlisp/source\tnewlisp\t10.7.5\tsource\t${fixtureRoot}/.reqpack-data/newlisp_bin/installs/source/10.7.5\t${fixtureRoot}/.reqpack-data/newlisp_bin/installs/source/10.7.5/bin/newlisp\thttps://www.newlisp.org/downloads/newlisp-10.7.5.tgz\tOfficial newLISP source release\n",
    },
  },
  fakeExec = {
    { match = "cat '${fixtureRoot}/.reqpack-data/newlisp_bin/installed.tsv'", exitCode = 0, stdout = "newlisp/source\tnewlisp\t10.7.5\tsource\t${fixtureRoot}/.reqpack-data/newlisp_bin/installs/source/10.7.5\t${fixtureRoot}/.reqpack-data/newlisp_bin/installs/source/10.7.5/bin/newlisp\thttps://www.newlisp.org/downloads/newlisp-10.7.5.tgz\tOfficial newLISP source release\n", stderr = "", success = true },
    { match = "rm -rf '${fixtureRoot}/.reqpack-data/newlisp_bin/installs/source/10.7.5'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/newlisp_bin'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "printf %s '' > '${fixtureRoot}/.reqpack-data/newlisp_bin/installed.tsv'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  },
}
