-module(monscr_app).

-behaviour(application).
-include("records.hrl").


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

  %Start the monscr suppervisor  == Starts the application
  monscr_sup:start_link().


stop(_State) ->
    ok.

