return {
  name = "octave-forge search remote index",
  request = {
    action = "search",
    system = "octave-forge",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    prompt = "imag",
  },
  fakeExec = {
    { match = "cat '${fixtureRoot}/.reqpack-data/cache/packages.json'", exitCode = 0, stdout = [[{"image":{"name":"image","description":"Functions for image processing","links":[{"label":"GPL-3.0-or-later","url":"https://example.invalid/COPYING"},{"label":"repository","url":"https://github.com/gnu-octave/packages-image"}],"maintainers":[{"name":"Maintainer One","contact":"maintainer@example.org"}],"versions":[{"id":"2.16.1","date":"2025-05-04","sha256":"abc123","url":"https://downloads.sourceforge.net/project/octave/image-2.16.1.tar.gz","depends":["octave (>= 7.1.0)","pkg"]}]},"signal":{"name":"signal","description":"Signal processing tools","links":[{"label":"GPL-3.0-or-later","url":"https://example.invalid/COPYING"}],"maintainers":[],"versions":[{"id":"1.4.7","date":"2026-01-10","sha256":"sig","url":"https://downloads.sourceforge.net/project/octave/signal-1.4.7.tar.gz","depends":["octave (>= 3.8.0)","control (>= 2.4.0)","pkg"]}]}}]], stderr = "", success = true },
    { match = "command -v 'curl' >/dev/null 2>&1", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "command -v 'octave-cli' 2>/dev/null || command -v 'octave' 2>/dev/null", exitCode = 1, stdout = "", stderr = "", success = false },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "image",
    resultVersion = "",
  }
}
