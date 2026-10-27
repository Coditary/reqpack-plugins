return {
  name = "octave-forge outdated packages",
  request = {
    action = "outdated",
    system = "octave-forge",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
  },
  fakeExec = {
    { match = "command -v 'octave-cli' 2>/dev/null || command -v 'octave' 2>/dev/null", exitCode = 0, stdout = "/usr/bin/octave-cli\n", stderr = "", success = true },
    { match = [=[HOME='${fixtureRoot}/.reqpack-data/home' XDG_CONFIG_HOME='${fixtureRoot}/.reqpack-data/config' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-data/cache' TMPDIR='${fixtureRoot}/.reqpack-data/tmp' LC_ALL=C LANG=C LANGUAGE=C NO_COLOR=1 REQPACK_STATE_ROOT='${fixtureRoot}/.reqpack-data' REQPACK_ACTION='list' '/usr/bin/octave-cli' --quiet --no-init-file --eval 'addpath('\''/home/Leodoras/Dev/Coditary/ReqPack/rqp-plugins/o/octave-forge/scripts'\''); reqpack_driver()']=], exitCode = 0, stdout = "local\timage\t2.16.0\tLoaded\ttrue\t${fixtureRoot}/.reqpack-data/prefix/image-2.16.0\t${fixtureRoot}/.reqpack-data/arch-prefix/image-2.16.0\t2025-03-03\tFunctions for image processing\thttps://packages.octave.org/image\thttps://packages.octave.org/image\toctave (>= 7.1.0),pkg\n", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-data/cache/packages.json'", exitCode = 0, stdout = [[{"image":{"name":"image","description":"Functions for image processing","links":[{"label":"GPL-3.0-or-later","url":"https://example.invalid/COPYING"},{"label":"repository","url":"https://github.com/gnu-octave/packages-image"}],"maintainers":[{"name":"Maintainer One","contact":"maintainer@example.org"}],"versions":[{"id":"2.16.1","date":"2025-05-04","sha256":"abc123","url":"https://downloads.sourceforge.net/project/octave/image-2.16.1.tar.gz","depends":["octave (>= 7.1.0)","pkg"]}]}}]], stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "image",
    resultVersion = "2.16.0",
  }
}
