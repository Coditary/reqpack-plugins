return {
  name = "newlisp_bin detect outdated source install",
  fixtureRoot = "/tmp/opencode/newlisp-bin-outdated",
  request = {
    action = "outdated",
    system = "newlisp_bin",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
    },
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/.reqpack-data/newlisp_bin/installed.tsv",
      content = "newlisp/source\tnewlisp\t10.7.1\tsource\t${fixtureRoot}/.reqpack-data/newlisp_bin/installs/source/10.7.1\t${fixtureRoot}/.reqpack-data/newlisp_bin/installs/source/10.7.1/bin/newlisp\thttps://sourceforge.net/projects/newlisp/files/newlisp-10.7.1.tgz/download\tOfficial newLISP source release\n",
    },
  },
  fakeExec = {
    { match = "cat '${fixtureRoot}/.reqpack-data/newlisp_bin/installed.tsv'", exitCode = 0, stdout = "newlisp/source\tnewlisp\t10.7.1\tsource\t${fixtureRoot}/.reqpack-data/newlisp_bin/installs/source/10.7.1\t${fixtureRoot}/.reqpack-data/newlisp_bin/installs/source/10.7.1/bin/newlisp\thttps://sourceforge.net/projects/newlisp/files/newlisp-10.7.1.tgz/download\tOfficial newLISP source release\n", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-cache/newlisp_bin/query/downloads.html'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-cache/newlisp_bin/query'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "curl -fsSL 'https://www.newlisp.org/index.cgi?page=Downloads' -o '${fixtureRoot}/.reqpack-cache/newlisp_bin/query/downloads.html'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-cache/newlisp_bin/query/downloads.html'", exitCode = 0, stdout = "Stable Release version 10.7.5\nSource distribution v.10.7.5\nnewlisp-10.7.5.tgz\n", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-cache/newlisp_bin/query/sourceforge-files.html'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-cache/newlisp_bin/query'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "curl -fsSL 'https://sourceforge.net/projects/newlisp/files/' -o '${fixtureRoot}/.reqpack-cache/newlisp_bin/query/sourceforge-files.html'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-cache/newlisp_bin/query/sourceforge-files.html'", exitCode = 0, stdout = "newlisp-10.7.5.tgz\nnewlisp-10.7.1.tgz\n", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-cache/newlisp_bin/query/sourceforge-news.html'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-cache/newlisp_bin/query'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "curl -fsSL 'https://sourceforge.net/p/newlisp/news/' -o '${fixtureRoot}/.reqpack-cache/newlisp_bin/query/sourceforge-news.html'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-cache/newlisp_bin/query/sourceforge-news.html'", exitCode = 0, stdout = "newLISP v.10.7.1 GS-143 source and Win32/64 installers\nPosted by 2017-01-31\n", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-cache/newlisp_bin/query/macos-1071.html'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-cache/newlisp_bin/query'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "curl -fsSL 'https://newlisp.nfshost.com/downloads1071/development/macOS-UTF8/' -o '${fixtureRoot}/.reqpack-cache/newlisp_bin/query/macos-1071.html'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-cache/newlisp_bin/query/macos-1071.html'", exitCode = 0, stdout = "newlisp 2018-09-10\nnewlisp.dylib 2018-09-10\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultVersion = "10.7.1",
    events = { "outdated" },
  },
}
