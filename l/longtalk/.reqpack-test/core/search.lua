return {
  name = "longtalk search available packs",
  request = {
    action = "search",
    system = "longtalk",
    prompt = "flat",
  },
  fakeExec = {
    {
      match = "command -v 'swilgt' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "forall((packs::available(Registry,Pack),packs::pack_object(Registry,Pack,Object),",
      exitCode = 0,
      stdout = "REQPACK\tSEARCH\ttalkshow\tlflat\t2:1:0\ttrue\tL-FLAT package\thttps://example.com/lflat\nREQPACK\tSEARCH\ttalkshow\tfoo\t1:0:0\tfalse\tFoo package\thttps://example.com/foo\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "lflat",
    resultVersion = "2:1:0",
  },
}
