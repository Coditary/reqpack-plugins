return {
  name = "sbt install dependency",
  fixtureRoot = "/tmp/opencode/sbt-install-case",
  request = {
    action = "install",
    system = "sbt",
    flags = { "data-root=/tmp/opencode/sbt-install-case/.reqpack-data" },
    packages = {
      { name = "org.typelevel:cats-core_2.13", version = "2.12.0" }
    },
  },
  fixtureDirs = {
    ".reqpack-data",
    ".reqpack-data/sbt-project/project",
    ".reqpack-data/sbt-global",
    ".reqpack-data/sbt-boot",
    ".reqpack-data/ivy2",
    ".reqpack-data/coursier",
    ".reqpack-data/query/search",
    ".reqpack-data/query/info",
  },
  fakeExec = {
    {
      match = "command -v sbt >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat /tmp/opencode/sbt-install-case/.reqpack-data/deps.json",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh HOME=\"$HOME\" XDG_CONFIG_HOME=\"$HOME/.config\" XDG_CACHE_HOME=\"$HOME/.cache\" XDG_DATA_HOME=\"$HOME/.local/share\" XDG_STATE_HOME=\"$HOME/.local/state\" sh -lc 'cd /tmp/opencode/sbt-install-case/.reqpack-data/sbt-project && exec sbt --batch --error --no-colors -Dsbt.global.base=/tmp/opencode/sbt-install-case/.reqpack-data/sbt-global -Dsbt.boot.directory=/tmp/opencode/sbt-install-case/.reqpack-data/sbt-boot -Dsbt.ivy.home=/tmp/opencode/sbt-install-case/.reqpack-data/ivy2 -Dsbt.coursier.home=/tmp/opencode/sbt-install-case/.reqpack-data/coursier -Dsbt.log.noformat=true -Dsbt.supershell=false -Dsbt.color=false -Dsbt.ci=true update'",
      exitCode = 0,
      stdout = "update ok\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v sbt >/dev/null 2>&1",
      "cat /tmp/opencode/sbt-install-case/.reqpack-data/deps.json",
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh HOME=\"$HOME\" XDG_CONFIG_HOME=\"$HOME/.config\" XDG_CACHE_HOME=\"$HOME/.cache\" XDG_DATA_HOME=\"$HOME/.local/share\" XDG_STATE_HOME=\"$HOME/.local/state\" sh -lc 'cd /tmp/opencode/sbt-install-case/.reqpack-data/sbt-project && exec sbt --batch --error --no-colors -Dsbt.global.base=/tmp/opencode/sbt-install-case/.reqpack-data/sbt-global -Dsbt.boot.directory=/tmp/opencode/sbt-install-case/.reqpack-data/sbt-boot -Dsbt.ivy.home=/tmp/opencode/sbt-install-case/.reqpack-data/ivy2 -Dsbt.coursier.home=/tmp/opencode/sbt-install-case/.reqpack-data/coursier -Dsbt.log.noformat=true -Dsbt.supershell=false -Dsbt.color=false -Dsbt.ci=true update'"
    },
    events = { "installed", "success" },
    stdout = {
      "update ok\n"
    },
  }
}
