
-module(aux).

-compile([{parse_transform, lager_transform}]).

-export([aux_method_org/1]).

aux_method_org(Args) ->
  lager:info("here"),
    receive
      {_,From,_} -> lager:info("list"), gen_server:reply(From,{ok,[{response_item,2},{lower,2},{accept,2},{send_update,2},{ready,2},{terminated,2},{config_done,2},{cancel,2}]}),
                    aux_method_org(Args);
      {'$gen_cast',{timeout}} -> lager:info("timeout"), Args ! timeout,
                    aux_method_org(Args);
      {'$gen_cast',{callback,ready,{ready}}} -> lager:info("ready"), Args ! ready,
                    aux_method_org(Args);
      {'$gen_cast',{callback, config_done,Reply}} ->lager:info("config"), Args ! {config_done, Reply},
                    aux_method_org(Args);

      {'$gen_cast',{callback,projection_request,{send, FileName, Host, Port}}} ->
        lager:warning("FileName ~p",[FileName]),
        {ok, Socket} = gen_tcp:connect(list_to_atom(Host), Port, [binary, {active, false}]),
        PathFile = "../test/test_resources/" ++ FileName,
        true = filelib:is_regular(PathFile),
        {ok, _} = file:sendfile(PathFile, Socket),
        ok = gen_tcp:close(Socket),
        aux_method_org(Args);
      exit -> lager:info("exit"), ok;
      M -> lager:info("unkown ~p",[M]), Args ! {error,M},
                    aux_method_org(Args)
    end.
