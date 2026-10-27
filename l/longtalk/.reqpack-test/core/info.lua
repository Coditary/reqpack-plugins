return {
  name = "longtalk info explicit registry pack",
  request = {
    action = "info",
    system = "longtalk",
    prompt = "talkshow::lflat",
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
      match = "packs::pack_object(talkshow,lflat,Object)",
      exitCode = 0,
      stdout = "REQPACK\tINFO\ttalkshow\tlflat\t2:0:2\t2:1:0\ttrue\tfalse\tL-FLAT package\tMIT\thttps://example.com/lflat\thttps://example.com/lflat-2.0.2.tar.gz\t/home/test/logtalk_packs/packs/talkshow/lflat\tfalse\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultName = "lflat",
    resultVersion = "2:0:2",
  },
}
