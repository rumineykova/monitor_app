%% @author aku
%% @doc @todo Add description to monscr_test.


-module(monscr_test).
-include_lib("eunit/include/eunit.hrl").

-compile([{parse_transform, lager_transform}]).

%% ====================================================================
%% API functions
%% ====================================================================
-export([aux_method_org/1]).

%% ====================================================================
%% Internal functions
%% ====================================================================


start_test() ->
  {ok, Mn} = monscr:start_link([]),
	?assertEqual(true, is_pid(Mn) ),
  global:unregister_name(monscr).


register_test()->
  {ok, Mn} = monscr:start_link([]),
  ?assertEqual(true, is_pid(Mn) ),
  {ok,Res} = monscr:register(self()),
  ?assertEqual(conf_done, Res),
  global:unregister_name(monscr),
  monscr:stop(Res).

config_test() ->
  ok = file:make_dir("resources/"),
  lager:start(),
  NRefOrg = spawn_link(?MODULE, aux_method_org, [self()]),
  lager:info("reach"),

  {ok, Mn} = monscr:start_link([]),
  lager:info("reach"),

  {ok, Res} = monscr:register(Mn, NRefOrg),
  ?assertEqual(conf_done, Res),
  lager:info("reach"),

  Pr = {NRefOrg,{ [{bid_sebay,client,[sebay]}],
    [{bid_sebay,client,response_item,response_item},
      {bid_sebay,client,lower,lower},
      {bid_sebay,client,accept,accept},
      {bid_sebay,client,send_update,send_update}
    ] }},

  lager:info("reach2"),

  M = monscr:config_protocol(Mn,Pr),
  ?assertEqual(ok, M),
  lager:info("reach3"),

  R = receive
    Resp -> Resp
  end,
  lager:info("reach2"),

  NRefOrg ! exit,
  global:unregister_name(monscr),

  monscr:stop(Mn),
  {config_done,{[{bid_sebay,client,P}],[]}} = R,
  ?assertEqual(true, is_pid(P)).



aux_method_org(Args) ->
  lager:info("here"),
    receive
      {_,From,_} -> lager:info("list"), gen_server:reply(From,{ok,[{response_item,2},{lower,2},{accept,2},{send_update,2},{ready,2},{terminated,2},{config_done,2},{cancel,2}]}),
                    aux_method_org(Args);
      {'$gen_cast',{timeout}} -> lager:info("timeout"), Args ! ok,
                    aux_method_org(Args);
      {'$gen_cast',{callback,ready,{ready}}} -> lager:info("ready"), Args ! ok,
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
