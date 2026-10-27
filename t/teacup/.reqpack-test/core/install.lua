return {
  name = "teacup install remote package with entity",
  request = {
    action = "install",
    system = "teacup",
    packages = {
      { action = "install", name = "sqlite3", version = "3.6.17", flags = { "entity=package" } }
    },
  },
  fakeExec = {
    { match = "command -v 'teacup' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.cache/reqpack/teacup'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -d '/home/test/.cache/reqpack/teacup/repository' || teacup create '/home/test/.cache/reqpack/teacup/repository'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "teacup install --at '/home/test/.cache/reqpack/teacup/repository' -is package 'sqlite3' '3.6.17'", exitCode = 0, stdout = "Installing package sqlite3 3.6.17 linux-glibc2.3-ix86\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
