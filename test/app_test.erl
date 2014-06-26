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
  monscr_app:start(nano, monscr),

  monscr_app:stop(monscr).
