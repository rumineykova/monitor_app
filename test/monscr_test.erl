%% @author aku
%% @doc @todo Add description to monscr_test.


-module(monscr_test).
-include_lib("eunit/include/eunit.hrl").

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
  {ok,Res} = monscr:register(monscr, self()),
  ?assertEqual(conf_done, Res),
  global:unregister_name(monscr).

config_test() ->

  NRefOrg = spawn_link(?MODULE, aux_method_org, [self()]),

  {ok, Mn} = monscr:start_link([]),
  {ok, Res} = monscr:register(monscr,NRefOrg),
  ?assertEqual(conf_done, Res),

  Pr = {NRefOrg,{ [{bid_sebay,client,[sebay]}],
    [{bid_sebay,client,response_item,response_item},
      {bid_sebay,client,lower,lower},
      {bid_sebay,client,accept,accept},
      {bid_sebay,client,send_update,send_update}
    ] }},

  %TODO: This is no like this anymore
  M = monscr:config_protocol(Mn,Pr),
  ?assertEqual(ok, M),

  R = receive
    Resp -> Resp
  end,

  NRefOrg ! exit,

  ?assertEqual(ok, R).



aux_method_org(Args) ->
    receive
      {_,From,_} -> gen_server:reply(From,{ok,[{response_item,2},{lower,2},{accept,2},{send_update,2},{ready,2},{terminated,2},{config_done,2},{cancel,2}]}),
                    aux_method_org(Args);
      {'$gen_cast',{timeout}} -> Args ! ok,
                    aux_method_org(Args);
      {'$gen_cast',{callback,ready,{ready}}} -> Args ! ok,
                    aux_method_org(Args);
      {'$gen_cast',{callback, config_done,Reply}} -> Args ! {config_done, Reply},
                    aux_method_org(Args);
      exit -> ok;
      M -> Args ! {error,M},
                    aux_method_org(Args)

    end.