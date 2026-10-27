return {
  name = "snap info package",
  request = {
    action = "info",
    system = "snap",
    prompt = "vlc",
  },
  fakeExec = {
    {
      match = "command -v 'snap' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "snap info 'vlc'",
      exitCode = 0,
      stdout = "name:      vlc\nsummary:   The ultimate media player\npublisher: VideoLAN*\ncontact:   https://www.videolan.org/support/\nlicense:   GPL-2.0+\ndescription: |\n  VLC is the VideoLAN project's media player.\n  It plays multimedia files.\ninstalled:  3.0.7            (1049) 212MB -\ntracking:   latest/stable\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "vlc",
    resultVersion = "3.0.7",
  }
}
