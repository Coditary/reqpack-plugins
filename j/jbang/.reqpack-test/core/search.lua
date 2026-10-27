return {
  name = "jbang search aliases",
  request = {
    action = "search",
    system = "jbang",
    prompt = "gav",
  },
  fakeExec = {
    {
      match = "command -v 'jbang' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "jbang alias list --format json",
      exitCode = 0,
      stdout = [=[[{"name":"gavsearch","catalogName":"jbangdev","fullName":"gavsearch@jbangdev","scriptRef":"gavsearch@jbangdev","description":"Search Maven artifacts"},{"name":"hello","catalogName":"jbangdev","fullName":"hello@jbangdev","scriptRef":"hello@jbangdev","description":"Say hello"}]]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = { "jbang alias list --format json" },
    events = { "searched" },
    resultCount = 1,
    resultName = "gavsearch@jbangdev",
  }
}
