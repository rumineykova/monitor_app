%% @author aku
%% @doc @todo Add description to role_sup_test.


-module(role_sup_test).
-include_lib("eunit/include/eunit.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-export([]).
-compile(export_all).


%% ====================================================================
%% Internal functions
%% ====================================================================

start_test() ->
	Rs = role_sup:start_link(),
	ok.