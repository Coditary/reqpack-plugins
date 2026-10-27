return {
  name = "oobabooga info app",
  request = {
    action = "info",
    system = "oobabooga",
    prompt = "app:oobabooga",
  },
  fixtureRoot = "../fixtures-info-app",
  fixtureDirs = {
    "home/.local/share/oobabooga/reqpack",
  },
  fixtureFiles = {
    {
      path = "home/.local/share/oobabooga/reqpack/app.json",
      content = [[{"version":"4.2","asset_name":"textgen-portable-4.2-linux-cpu.tar.gz","install_root":"${fixtureRoot}/home/.local/share/oobabooga/text-generation-webui"}]],
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "app:oobabooga",
    resultVersion = "4.2",
  }
}
