return {
  name = "quarks remove installed package",
  fixtureRoot = "/tmp/opencode/quarks-remove-case",
  request = {
    action = "remove",
    system = "quarks",
    flags = { "data-root=/tmp/opencode/quarks-remove-case/.reqpack-data" },
    packages = {
      { name = "MathLib" }
    },
  },
  fixtureDirs = {
    ".reqpack-data/quarks/state",
  },
  fixtureFiles = {
    { path = ".reqpack-data/quarks/cache/directory.tsv", content = "" },
    { path = ".reqpack-data/quarks/state/installed.tsv", content = "MathLib\t1.0.0\tMath library\thttps://github.com/supercollider-quarks/MathLib.git\ttags/1.0.0\t/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/home/.local/share/SuperCollider/downloaded-quarks/MathLib\tdirectory\ttrue\t2026-05-31T00:00:00Z\n" },
  },
  fakeExec = {
    { match = "command -v 'sclang' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/state/installed.tsv'", exitCode = 0, stdout = "MathLib\t1.0.0\tMath library\thttps://github.com/supercollider-quarks/MathLib.git\ttags/1.0.0\t/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/home/.local/share/SuperCollider/downloaded-quarks/MathLib\tdirectory\ttrue\t2026-05-31T00:00:00Z\n", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-remove-case/.reqpack-data/quarks'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/home'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/home/.config'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/home/.local/share'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/home/.cache'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/config'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/runtime'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/cache'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/state'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/runtime/scripts'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "printf %s '(\nvar reqpackSanitize = { |value|", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C HOME='/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/home' XDG_CONFIG_HOME='/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/home/.config' XDG_DATA_HOME='/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/home/.local/share' XDG_CACHE_HOME='/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/home/.cache' sclang -D '/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/runtime/scripts/quarks-remove.scd'", exitCode = 0, stdout = "compiled\n", stderr = "", success = true },
    { match = "printf %s '(\nvar reqpackSanitize = { |value|", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C HOME='/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/home' XDG_CONFIG_HOME='/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/home/.config' XDG_DATA_HOME='/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/home/.local/share' XDG_CACHE_HOME='/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/home/.cache' sclang -D '/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/runtime/scripts/quarks-list.scd'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "printf %s '' > '/tmp/opencode/quarks-remove-case/.reqpack-data/quarks/state/installed.tsv'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    result = true,
    events = { "deleted", "success" },
  },
}
