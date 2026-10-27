return {
  name = "newlisp_bin search history fallback metadata",
  fixtureRoot = "/tmp/opencode/newlisp-bin-search-fallbacks",
  request = {
    action = "search",
    system = "newlisp_bin",
    prompt = "10.7.1",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
    },
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/.reqpack-cache/newlisp_bin/query/downloads.html",
      content = "Stable Release version 10.7.5\nSource distribution v.10.7.5\nnewlisp-10.7.5.tgz\n",
    },
    {
      path = "${fixtureRoot}/.reqpack-cache/newlisp_bin/query/sourceforge-files.html",
      content = "newlisp-10.7.5.tgz\nnewlisp-10.7.1.tgz\nnewlisp-10701-win64-gs-166.exe\n",
    },
    {
      path = "${fixtureRoot}/.reqpack-cache/newlisp_bin/query/sourceforge-news.html",
      content = "newLISP v.10.7.1 GS-143 source and Win32/64 installers\nPosted by 2017-01-31\n",
    },
    {
      path = "${fixtureRoot}/.reqpack-cache/newlisp_bin/query/macos-1071.html",
      content = "newlisp 2018-09-10\nnewlisp.dylib 2018-09-10\n",
    },
  },
  fakeExec = {
    { match = "command -v 'curl' >/dev/null 2>&1", exitCode = 0, stdout = "/usr/bin/curl\n", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-cache/newlisp_bin/query/downloads.html'", exitCode = 0, stdout = "Stable Release version 10.7.5\nSource distribution v.10.7.5\nnewlisp-10.7.5.tgz\n", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-cache/newlisp_bin/query/sourceforge-files.html'", exitCode = 0, stdout = "newlisp-10.7.5.tgz\nnewlisp-10.7.1.tgz\nnewlisp-10701-win64-gs-166.exe\n", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-cache/newlisp_bin/query/sourceforge-news.html'", exitCode = 0, stdout = "newLISP v.10.7.1 GS-143 source and Win32/64 installers\nPosted by 2017-01-31\n", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-cache/newlisp_bin/query/macos-1071.html'", exitCode = 0, stdout = "newlisp 2018-09-10\nnewlisp.dylib 2018-09-10\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    resultCount = 3,
    resultName = "newlisp",
    resultVersion = "10.7.1",
    events = { "searched" },
  },
}
