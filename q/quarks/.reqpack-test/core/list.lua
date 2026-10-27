return {
  name = "quarks list cached installed packages",
  fixtureRoot = "/tmp/opencode/quarks-list-case",
  request = {
    action = "list",
    system = "quarks",
    flags = { "data-root=/tmp/opencode/quarks-list-case/.reqpack-data" },
  },
  fixtureDirs = {
    ".reqpack-data/quarks/state",
  },
  fixtureFiles = {
    { path = ".reqpack-data/quarks/state/installed.tsv", content = "" },
  },
  fakeExec = {
    { match = "command -v 'sclang' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-list-case/.reqpack-data/quarks'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-list-case/.reqpack-data/quarks/home'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-list-case/.reqpack-data/quarks/home/.config'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-list-case/.reqpack-data/quarks/home/.local/share'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-list-case/.reqpack-data/quarks/home/.cache'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-list-case/.reqpack-data/quarks/config'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-list-case/.reqpack-data/quarks/runtime'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-list-case/.reqpack-data/quarks/cache'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-list-case/.reqpack-data/quarks/state'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-list-case/.reqpack-data/quarks/runtime/scripts'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "printf %s '(\nvar reqpackSanitize = { |value|", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C HOME='/tmp/opencode/quarks-list-case/.reqpack-data/quarks/home' XDG_CONFIG_HOME='/tmp/opencode/quarks-list-case/.reqpack-data/quarks/home/.config' XDG_DATA_HOME='/tmp/opencode/quarks-list-case/.reqpack-data/quarks/home/.local/share' XDG_CACHE_HOME='/tmp/opencode/quarks-list-case/.reqpack-data/quarks/home/.cache' sclang -D '/tmp/opencode/quarks-list-case/.reqpack-data/quarks/runtime/scripts/quarks-list.scd'", exitCode = 0, stdout = "REQPACK\tITEM\tMathLib\t1.0.0\tMath library\thttps://github.com/supercollider-quarks/MathLib.git\ttags/1.0.0\t/tmp/opencode/quarks-list-case/.reqpack-data/quarks/home/.local/share/SuperCollider/downloaded-quarks/MathLib\ttrue\nREQPACK\tITEM\tMyQuark\t\tMy local quark\t\t\t/tmp/opencode/quarks-list-case/local/MyQuark\tfalse\n", stderr = "", success = true },
    { match = "date -u +%Y-%m-%dT%H:%M:%SZ", exitCode = 0, stdout = "2026-05-31T00:00:00Z\n", stderr = "", success = true },
    { match = "printf %s 'MathLib\t1.0.0\tMath library\thttps://github.com/supercollider-quarks/MathLib.git\ttags/1.0.0\t/tmp/opencode/quarks-list-case/.reqpack-data/quarks/home/.local/share/SuperCollider/downloaded-quarks/MathLib\tdirectory\ttrue\t2026-05-31T00:00:00Z\nMyQuark\t\tMy local quark\t\t\t/tmp/opencode/quarks-list-case/local/MyQuark\tlocal-path\tfalse\t2026-05-31T00:00:00Z\n' > '/tmp/opencode/quarks-list-case/.reqpack-data/quarks/state/installed.tsv'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    resultCount = 2,
    resultName = "MathLib",
    resultVersion = "1.0.0",
    events = { "listed" },
  },
}
