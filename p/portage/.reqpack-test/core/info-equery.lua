return {
  name = "portage info package via equery",
  request = {
    action = "info",
    system = "portage",
    prompt = "app-misc/brightnessctl",
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
      match = "command -v 'equery' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C equery meta -- 'app-misc/brightnessctl'",
      exitCode = 0,
      stdout = " * app-misc/brightnessctl [guru]\n Homepage:    https://github.com/Hummer12007/brightnessctl\n Location:    /var/db/repos/guru/app-misc/brightnessctl\n Keywords:    0.5.1:0: ~amd64\n License:     MIT\n",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C equery meta --description -- 'app-misc/brightnessctl'",
      exitCode = 0,
      stdout = "Backlight control utility\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'equery' >/dev/null 2>&1",
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C equery meta -- 'app-misc/brightnessctl'",
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C equery meta --description -- 'app-misc/brightnessctl'",
    },
    resultCount = 1,
    resultName = "app-misc/brightnessctl",
    resultVersion = "0.5.1",
    events = { "informed" },
  }
}
