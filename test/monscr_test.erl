%% @author aku
%% @doc @todo Add description to monscr_test.


-module(monscr_test).
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
	Mn = monscr:start_link([]),
	ok.