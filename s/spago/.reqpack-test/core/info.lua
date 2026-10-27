return {
  name = "spago registry info",
  request = {
    action = "info",
    system = "spago",
    prompt = "prelude",
  },
  fakeExec = {
    {
      match = "command -v 'spago' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "spago registry info --json prelude",
      exitCode = 0,
      stdout = [[{"location":{"githubOwner":"purescript","githubRepo":"purescript-prelude"},"published":{"6.0.1":{"publishedTime":"2022-08-18T20:04:00.000Z","compilers":["0.15.16"],"hash":"sha256-old","ref":""},"6.0.2":{"publishedTime":"2025-02-15T18:25:08.000Z","compilers":["0.15.16"],"hash":"sha256-new","ref":""}},"unpublished":{}}]],
      stderr = "",
      success = true,
    },
    {
      match = "spago ls paths --json",
      exitCode = 0,
      stdout = [[{"Global cache path":"/home/test/.cache/spago-nodejs","Global registry path":"/home/test/.cache/spago-nodejs/registry","Local cache path":"/workspace/.spago","Local cache packages path":"/workspace/.spago/packages"}]],
      stderr = "",
      success = true,
    },
    {
      match = "spago registry package-sets --json",
      exitCode = 0,
      stdout = [=[[{"version":"66.0.0","date":"2026-01-01","compiler":"0.15.16","packages":{"prelude":"6.0.2","effect":"4.0.0"}}]]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultName = "prelude",
    resultVersion = "6.0.2",
  }
}
