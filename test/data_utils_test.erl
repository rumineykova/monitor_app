%%%-------------------------------------------------------------------
%%% @author aku
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 19. Jun 2014 01:02
%%%-------------------------------------------------------------------
-module(data_utils_test).
-author("aku").

-include_lib("eunit/include/eunit.hrl").

%% -record(internal,{main_sup, regp, prot_sup}).
internal_test()->
  Int = data_utils:internal_create('<0.66.0>',[],[]),

  data_utils:internal_add_regp(Int,'<0.67.0>').
