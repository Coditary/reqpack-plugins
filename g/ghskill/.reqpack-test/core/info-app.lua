return {
  name = "ghskill info app",
  request = {
    action = "info",
    system = "ghskill",
    prompt = "app:ghskill",
  },
  fixtureRoot = "../fixtures-info-app",
  fixtureDirs = {
    "home/.local/share/ghskill/reqpack",
  },
  fixtureFiles = {
    {
      path = "home/.local/share/ghskill/reqpack/app.json",
      content = [[{"version":"2.90.0","detected_at":"2026-05-29T12:00:00Z"}]],
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "app:ghskill",
    resultVersion = "2.90.0",
  }
}
