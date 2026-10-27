return {
  name = "gleam search hex packages",
  request = {
    action = "search",
    system = "gleam",
    prompt = "gleam",
  },
  fakeExec = {
    { match = "command -v 'curl' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh HOME=\"$HOME\" XDG_CONFIG_HOME=\"$HOME/.config\" XDG_CACHE_HOME=\"$HOME/.cache\" XDG_DATA_HOME=\"$HOME/.local/share\" XDG_STATE_HOME=\"$HOME/.local/state\" 'curl' -fsSL 'https://hex.pm/api/packages?search=gleam'", exitCode = 0, stdout = [=[[{"name":"gleam_stdlib","latest_version":"1.0.3","latest_stable_version":"1.0.3","html_url":"https://hex.pm/packages/gleam_stdlib","docs_html_url":"https://gleam-stdlib.hexdocs.pm/","meta":{"description":"A standard library for the Gleam programming language","licenses":["Apache-2.0"],"links":{"Repository":"https://github.com/gleam-lang/stdlib","Website":"https://gleam.run/"}},"releases":[{"version":"1.0.3"}]}]]=], stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "gleam_stdlib",
    resultVersion = "1.0.3",
  },
}
