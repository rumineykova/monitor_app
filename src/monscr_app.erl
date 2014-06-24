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
  %Start the log system
	lager:start(),

  %Start the database
  db_utils:install(node(),"db"),

  db_utils:ets_create(child,  [set, named_table, public, {keypos,1}, {write_concurrency,false}, {read_concurrency,true}]),

  %Start the monscr suppervisor  == Starts the application
  R = monscr_sup:start_link(),
  lager:warning(" After sup ~p", [R]),R.


stop(_State) ->
    ok.

