-module(monscr_app).

-behaviour(application).
-include("records.hrl").
-compile([{parse_transform, lager_transform}]).

%% Application callbacks
-export([start/2, stop/1]).

%% ===================================================================
%% Application callbacks
%% ===================================================================

start(_StartType, _StartArgs) ->
  db_utils:install(node(),"db"),

  %Start the monscr suppervisor  == Starts the application
  R = monscr_sup:start_link(),
  lager:warning(" After sup ~p", [R]),R.


stop(_State) ->
    ok.

