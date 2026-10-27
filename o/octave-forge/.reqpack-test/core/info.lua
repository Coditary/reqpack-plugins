return {
  name = "octave-forge info remote package",
  request = {
    action = "info",
    system = "octave-forge",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    prompt = "image",
  },
  fakeExec = {
    { match = "command -v 'octave-cli' 2>/dev/null || command -v 'octave' 2>/dev/null", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "cat '${fixtureRoot}/.reqpack-data/cache/packages.json'", exitCode = 0, stdout = [[{"image":{"name":"image","description":"Functions for image processing","links":[{"label":"GPL-3.0-or-later","url":"https://example.invalid/COPYING"},{"label":"repository","url":"https://github.com/gnu-octave/packages-image"}],"maintainers":[{"name":"Maintainer One","contact":"maintainer@example.org"}],"versions":[{"id":"2.16.1","date":"2025-05-04","sha256":"abc123","url":"https://downloads.sourceforge.net/project/octave/image-2.16.1.tar.gz","depends":["octave (>= 7.1.0)","pkg"]}]}}]], stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultName = "image",
    resultVersion = "",
  }
}
