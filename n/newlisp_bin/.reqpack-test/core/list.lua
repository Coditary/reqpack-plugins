return {
  name = "newlisp_bin list registry installs",
  fixtureRoot = "/tmp/opencode/newlisp-bin-list",
  request = {
    action = "list",
    system = "newlisp_bin",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
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
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "newlisp",
    resultVersion = "10.7.5",
    events = { "listed" },
  },
}
