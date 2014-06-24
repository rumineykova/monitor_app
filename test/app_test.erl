%%%-------------------------------------------------------------------
%%% @author aku
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 21. Jun 2014 00:46
%%%-------------------------------------------------------------------
-module(app_test).
-author("aku").

-include_lib("eunit/include/eunit.hrl").

start_stop_test() ->
  global:unregister_name(monscr),
  monscr_app:start(nano, monscr),
  %timer:sleep(1500),
  monscr_app:stop(monscr).
