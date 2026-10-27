return {
  name = "pinokio info app",
  request = {
    action = "info",
    system = "pinokio",
    prompt = "app:pinokio",
  },
  fixtureRoot = "../fixtures-info-app",
  fixtureDirs = {
    "home/pinokio/reqpack",
  },
  fixtureFiles = {
    { path = "home/pinokio/reqpack/app.json", content = [[{"version":"7.1.12","install_root":"${fixtureRoot}/home/pinokio/app/Pinokio.AppImage"}]] },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "app:pinokio",
    resultVersion = "7.1.12",
  }
}
