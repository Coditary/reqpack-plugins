return {
  name = "quarks update installed package",
  fixtureRoot = "/tmp/opencode/quarks-update-case",
  request = {
    action = "update",
    system = "quarks",
    flags = { "data-root=/tmp/opencode/quarks-update-case/.reqpack-data" },
    packages = {
      { name = "MathLib" }
    },
  },
  fixtureDirs = {
    ".reqpack-data/quarks/state",
  },
  fixtureFiles = {
    { path = ".reqpack-data/quarks/cache/directory.tsv", content = "" },
    { path = ".reqpack-data/quarks/state/installed.tsv", content = "MathLib\t1.0.0\tMath library\thttps://github.com/supercollider-quarks/MathLib.git\tmain\t/tmp/opencode/quarks-update-case/.reqpack-data/quarks/home/.local/share/SuperCollider/downloaded-quarks/MathLib\tdirectory\ttrue\t2026-05-31T00:00:00Z\n" },
  },
  fakeExec = {
    { match = "command -v 'sclang' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '/tmp/opencode/quarks-update-case/.reqpack-data/quarks/state/installed.tsv'", exitCode = 0, stdout = "MathLib\t1.0.0\tMath library\thttps://github.com/supercollider-quarks/MathLib.git\tmain\t/tmp/opencode/quarks-update-case/.reqpack-data/quarks/home/.local/share/SuperCollider/downloaded-quarks/MathLib\tdirectory\ttrue\t2026-05-31T00:00:00Z\n", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-update-case/.reqpack-data/quarks'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-update-case/.reqpack-data/quarks/home'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-update-case/.reqpack-data/quarks/home/.config'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-update-case/.reqpack-data/quarks/home/.local/share'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-update-case/.reqpack-data/quarks/home/.cache'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-update-case/.reqpack-data/quarks/config'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-update-case/.reqpack-data/quarks/runtime'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-update-case/.reqpack-data/quarks/cache'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-update-case/.reqpack-data/quarks/state'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/quarks-update-case/.reqpack-data/quarks/runtime/scripts'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "printf %s '(\nvar reqpackSanitize = { |value|", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C HOME='/tmp/opencode/quarks-update-case/.reqpack-data/quarks/home' XDG_CONFIG_HOME='/tmp/opencode/quarks-update-case/.reqpack-data/quarks/home/.config' XDG_DATA_HOME='/tmp/opencode/quarks-update-case/.reqpack-data/quarks/home/.local/share' XDG_CACHE_HOME='/tmp/opencode/quarks-update-case/.reqpack-data/quarks/home/.cache' sclang -D '/tmp/opencode/quarks-update-case/.reqpack-data/quarks/runtime/scripts/quarks-update.scd'", exitCode = 0, stdout = "compiled\n", stderr = "", success = true },
    { match = "printf %s '(\nvar reqpackSanitize = { |value|", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C HOME='/tmp/opencode/quarks-update-case/.reqpack-data/quarks/home' XDG_CONFIG_HOME='/tmp/opencode/quarks-update-case/.reqpack-data/quarks/home/.config' XDG_DATA_HOME='/tmp/opencode/quarks-update-case/.reqpack-data/quarks/home/.local/share' XDG_CACHE_HOME='/tmp/opencode/quarks-update-case/.reqpack-data/quarks/home/.cache' sclang -D '/tmp/opencode/quarks-update-case/.reqpack-data/quarks/runtime/scripts/quarks-list.scd'", exitCode = 0, stdout = "REQPACK\tITEM\tMathLib\t1.1.0\tMath library\thttps://github.com/supercollider-quarks/MathLib.git\tmain\t/tmp/opencode/quarks-update-case/.reqpack-data/quarks/home/.local/share/SuperCollider/downloaded-quarks/MathLib\ttrue\n", stderr = "", success = true },
    { match = "date -u +%Y-%m-%dT%H:%M:%SZ", exitCode = 0, stdout = "2026-05-31T00:10:00Z\n", stderr = "", success = true },
    { match = "printf %s 'MathLib\t1.1.0\tMath library\thttps://github.com/supercollider-quarks/MathLib.git\tmain\t/tmp/opencode/quarks-update-case/.reqpack-data/quarks/home/.local/share/SuperCollider/downloaded-quarks/MathLib\tdirectory\ttrue\t2026-05-31T00:00:00Z\n' > '/tmp/opencode/quarks-update-case/.reqpack-data/quarks/state/installed.tsv'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    result = true,
    events = { "updated", "success" },
  },
}
