return {
  name = "logtalk install latest default registry pack",
  request = {
    action = "install",
    system = "logtalk",
    packages = {
      { name = "lflat" },
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
      match = "command -v 'swilgt' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = [=[LOGTALKPACKS='/home/test/.reqpack-data/logtalk/logtalk_packs' 'swilgt' -q -g 'set_logtalk_flag(report,off),logtalk_load(packs(loader)),once((packs::pack_object('\''talkshow'\'','\''lflat'\'',O),O::version(V,_,_,_,_,_),V=A:B:C,format('\''REQPACK|^|~d.~d.~d~n'\'',[A,B,C])))' -t halt]=],
      exitCode = 0,
      stdout = "REQPACK|^|2.1.0\n",
      stderr = "",
      success = true,
    },
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
