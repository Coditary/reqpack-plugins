return {
  name = "octave-forge list managed packages",
  request = {
    action = "list",
    system = "octave-forge",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
  },
  fakeExec = {
    { match = "command -v 'octave-cli' 2>/dev/null || command -v 'octave' 2>/dev/null", exitCode = 0, stdout = "/usr/bin/octave-cli\n", stderr = "", success = true },
    { match = [=[HOME='${fixtureRoot}/.reqpack-data/home' XDG_CONFIG_HOME='${fixtureRoot}/.reqpack-data/config' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-data/cache' TMPDIR='${fixtureRoot}/.reqpack-data/tmp' LC_ALL=C LANG=C LANGUAGE=C NO_COLOR=1 REQPACK_STATE_ROOT='${fixtureRoot}/.reqpack-data' REQPACK_ACTION='list' '/usr/bin/octave-cli' --quiet --no-init-file --eval 'addpath('\''/home/Leodoras/Dev/Coditary/ReqPack/rqp-plugins/o/octave-forge/scripts'\''); reqpack_driver()']=], exitCode = 0, stdout = "local\timage\t2.16.0\tLoaded\ttrue\t${fixtureRoot}/.reqpack-data/prefix/image-2.16.0\t${fixtureRoot}/.reqpack-data/arch-prefix/image-2.16.0\t2025-03-03\tFunctions for image processing\thttps://packages.octave.org/image\thttps://packages.octave.org/image\toctave (>= 7.1.0),pkg\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 1,
    resultName = "image",
    resultVersion = "2.16.0",
  }
}
