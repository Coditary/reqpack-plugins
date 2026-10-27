return {
  name = "logtalk info package",
  request = {
    action = "info",
    system = "logtalk",
    prompt = "lflat",
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
      match = [=[LOGTALKPACKS='/home/test/.reqpack-data/logtalk/logtalk_packs' 'swilgt' -q -g 'set_logtalk_flag(report,off),logtalk_load(packs(loader)),once((packs::pack_object(R,'\''lflat'\'',O),P='\''lflat'\'',(O::description(D)->true;D=none),(O::license(L)->true;L=none),(O::home(H)->true;H=none),(packs::installed(R,P,IV,_)->(IV=IA:IB:IC,format(atom(IS),'\''~d.~d.~d'\'',[IA,IB,IC]));IS=none),once(O::version(LV,Status,U,_,_,_)),LV=LA:LB:LC,format(atom(LS),'\''~d.~d.~d'\'',[LA,LB,LC]),format('\''REQPACK|^|~w|^|~w|^|~w|^|~w|^|~w|^|~w|^|~w|^|~w~n'\'',[R,P,IS,LS,Status,D,L,H,U])))' -t halt]=],
      exitCode = 0,
      stdout = "REQPACK|^|talkshow|^|lflat|^|2.1.0|^|2.1.0|^|stable|^|L-FLAT|^|MIT|^|https://github.com/l-flat/lflat|^|https://github.com/l-flat/lflat/archive/refs/tags/v2.1.0.tar.gz\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultName = "lflat",
    resultVersion = "2.1.0",
  }
}
