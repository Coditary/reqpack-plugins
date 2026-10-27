return {
  name = "logtalk install exact pack version",
  request = {
    action = "install",
    system = "logtalk",
    packages = {
      { name = "talkshow::lflat", version = "2.1.0" },
    },
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
      match = [=[LOGTALKPACKS='/home/test/.reqpack-data/logtalk/logtalk_packs' 'swilgt' -q -g 'set_logtalk_flag(report,off),logtalk_load(packs(loader)),(registries::defined(talkshow,_,_,_)->true;registries::add('\''https://github.com/LogtalkDotOrg/talkshow.git'\''))' -t halt]=],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = [=[LOGTALKPACKS='/home/test/.reqpack-data/logtalk/logtalk_packs' 'swilgt' -q -g 'set_logtalk_flag(report,off),logtalk_load(packs(loader)),packs::install('\''talkshow'\'','\''lflat'\'',2:1:0,[])' -t halt]=],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
