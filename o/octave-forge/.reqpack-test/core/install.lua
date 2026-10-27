return {
  name = "octave-forge install remote package",
  request = {
    action = "install",
    system = "octave-forge",
    flags = { "data-root=${fixtureRoot}/.reqpack-data", "nodeps" },
    packages = {
      { name = "image" }
    },
  },
  fakeExec = {
    { match = "command -v 'octave-cli' 2>/dev/null || command -v 'octave' 2>/dev/null", exitCode = 0, stdout = "/usr/bin/octave-cli\n", stderr = "", success = true },
    { match = [=[HOME='${fixtureRoot}/.reqpack-data/home' XDG_CONFIG_HOME='${fixtureRoot}/.reqpack-data/config' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-data/cache' TMPDIR='${fixtureRoot}/.reqpack-data/tmp' LC_ALL=C LANG=C LANGUAGE=C NO_COLOR=1 REQPACK_STATE_ROOT='${fixtureRoot}/.reqpack-data' REQPACK_ACTION='install' REQPACK_SCOPE='local' REQPACK_PACKAGE='image' REQPACK_LOCAL_INSTALL='0' REQPACK_NODEPS='1' REQPACK_VERBOSE='0' '/usr/bin/octave-cli' --quiet --no-init-file --eval 'addpath('\''/home/Leodoras/Dev/Coditary/ReqPack/rqp-plugins/o/octave-forge/scripts'\''); reqpack_driver()']=], exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
