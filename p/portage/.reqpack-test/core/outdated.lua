return {
  name = "portage outdated packages",
  request = {
    action = "outdated",
    system = "portage",
  },
  fakeExec = {
    {
      match = "command -v 'emerge' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C emerge --pretend --update --deep --newuse @world",
      exitCode = 0,
      stdout = "[ebuild U  ] www-client/firefox-128.1::gentoo [128.0::gentoo]\n[ebuild UD ] dev-lang/python-3.11::gentoo [3.12::gentoo]\n[ebuild N  ] app-editors/neovim-0.10.0::gentoo\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C emerge --pretend --update --deep --newuse @world",
    },
    resultCount = 2,
    resultName = "www-client/firefox",
    resultVersion = "128.0",
    events = { "outdated" },
  }
}
