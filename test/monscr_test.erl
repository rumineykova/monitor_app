%% @author aku
%% @doc @todo Add description to monscr_test.


-module(monscr_test).
-include_lib("eunit/include/eunit.hrl").

%% ====================================================================
%% API functions
%% ====================================================================


%% ====================================================================
%% Internal functions
%% ====================================================================


start_test() ->
  {ok, Mn} = monscr:start_link([]),
	?assertEqual(true, is_pid(Mn) ),
  erlang:unregister(monscr).


register_test()->
  {ok, Mn} = monscr:start_link([]),
  {ok,Res} = monscr:register(Mn, self()),
  ?assertEqual(conf_done, Res),
  erlang:unregister(monscr).

config_test() ->
  {ok, Mn} = monscr:start_link([]),
  {ok, Res} = monscr:register(Mn,self()),
  ?assertEqual(conf_done, Res),

  Pr = {self(),{ [{bid_sebay,client,[sebay]}],
    [{bid_sebay,client,response_item,response_item},
      {bid_sebay,client,lower,lower},
      {bid_sebay,client,accept,accept},
      {bid_sebay,client,send_update,send_update}
    ] }},

  {ids,[{bid_sebay,client,Res2}]} = monscr:config_protocol(Mn,Pr),
  ?assertEqual(true, is_pid(Res2)).