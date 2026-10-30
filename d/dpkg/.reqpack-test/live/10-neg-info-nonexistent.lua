return {
  name = "live info rejects nonexistent package",
  request = {
    action = "info",
    system = "dpkg",
    prompt = "reqpack-definitely-does-not-exist-99999",
  },
  expect = {
    success = false,
  },
}
