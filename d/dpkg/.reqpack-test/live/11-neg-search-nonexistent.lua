return {
  name = "live search returns no hits for nonsense query",
  request = {
    action = "search",
    system = "dpkg",
    prompt = "reqpack-definitely-does-not-exist-99999",
  },
  expect = {
    success = true,
    maxItems = 0,
  },
}
