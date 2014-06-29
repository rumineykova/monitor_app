%% @author aku
%% @doc @todo Add description to monscr.

-module(monscr).
-behaviour(gen_server).

-compile([{parse_transform, lager_transform}]).

-include("records.hrl").


%% ====================================================================
%% Default values in case of no config
%% ====================================================================

-define(RESOURCES_PATH,"resources/").



%% ====================================================================
%% API exports
%% ====================================================================
%% Gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
%% Public API
-export([start_link/0,start_link/1, register/1, register/2, config_protocol/1, config_protocol/2, request_id/2, request_id/3]).
%% Testing purposses
-export([stop/1]).

%% ====================================================================
%% API functions
%% ====================================================================

%% register/2
%% ====================================================================
%% @doc
%%
%% @end
register(Process, Pid) ->
  gen_server:call(Process, {register, Pid}).
register(Pid) ->
  gen_server:call({global, monscr},{register,Pid}).


%% config_protocol/2
%% ====================================================================
%% @doc
%%
%% @end
config_protocol(Process, Protocol) ->
  gen_server:cast(Process, {config,Protocol}).
config_protocol(Protocol) ->
  gen_server:cast({global,monscr}, {config,Protocol}).



%% request_id/2
%% ====================================================================
%% @doc
%%
%% @end
request_id(Process, Protocol, Role) ->
  gen_server:call(Process, {request_id, Protocol, Role}).
request_id(Protocol, Role) ->
  gen_server:call({global, monscr}, {request_id, Protocol, Role}).



%get_all_processes_from({P, _X}) ->
%  ok;
%get_all_processes_from(P) ->
%  ok.

%% stop/1
%% ====================================================================
%% @doc
%%
%% @end
stop(Process) ->
    gen_server:cast(Process, {stop}).





%% ====================================================================
%% Behavioural functions 
%% ====================================================================
%% start_link/0
%% ====================================================================
%% @doc
%% @end
%% ====================================================================
start_link() ->
  start_link([]).

%% start_link/1
%% ====================================================================
%% @doc
%% @end
%% ====================================================================
start_link([]) ->
	gen_server:start_link(?MODULE, [], []);
start_link(Args) ->
  gen_server:start_link(?MODULE, Args, []).




%% init/1
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:init-1">gen_server:init/1</a>
-spec init(Args :: term()) -> Result when
	Result :: {ok, State}
			| {ok, State, Timeout}
			| {ok, State, hibernate}
			| {stop, Reason :: term()}
			| ignore,
	State :: term(),
	Timeout :: non_neg_integer() | infinity.
%% ====================================================================
init(_State) ->
  %% Start the in ram table for preserve role states
  db_utils:ets_create(child,  [set, named_table, public, {keypos,2}, {write_concurrency,false}, {read_concurrency,true}]),

  %% Register monscr to be use globally with the names
  global:register_name(monscr,self()),

  %% Start the supervisor for the supervisor of the roles
	{ok,Main_sup} = sup_role_sup:start_link(),

  %% Update State and finish
  UState = data_utils:internal_create(Main_sup, [], []),
  {ok, UState}.


%% handle_call/3
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:handle_call-3">gen_server:handle_call/3</a>
-spec handle_call(Request :: term(), From :: {pid(), Tag :: term()}, State :: term()) -> Result when
	Result :: {reply, Reply, NewState}
			| {reply, Reply, NewState, Timeout}
			| {reply, Reply, NewState, hibernate}
			| {noreply, NewState}
			| {noreply, NewState, Timeout}
			| {noreply, NewState, hibernate}
			| {stop, Reason, Reply, NewState}
			| {stop, Reason, NewState},
	Reply :: term(),
	NewState :: term(),
	Timeout :: non_neg_integer() | infinity,
	Reason :: term().
%% ====================================================================
handle_call({register,Pid},_From,State) ->
	Reply = register_imp(Pid),
	{reply,Reply,State};
handle_call({request_id, Id}, _From, State) ->
  {reply, db_utils:ets_lookup_child_pid(Id), State};
handle_call(_Request,_From,State)->
	{reply,{error,bad_args},State}.


%% handle_cast/2
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:handle_cast-2">gen_server:handle_cast/2</a>
-spec handle_cast(Request :: term(), State :: term()) -> Result when
	Result :: {noreply, NewState}
			| {noreply, NewState, Timeout}
			| {noreply, NewState, hibernate}
			| {stop, Reason :: term(), NewState},
	NewState :: term(),
	Timeout :: non_neg_integer() | infinity.
%% ====================================================================
handle_cast({config,{Id,_ } = Config } , State) ->

  %% Colling the actual implementation of the configuration
  {ok, Reply} = config_protocol_imp(Config, State),

  %% performing a callback to config_done in the client
  Pid = db_utils:ets_lookup_client_pid(Id),
  gen_monrcp:send(Pid, {callback, config_done, Reply}),
  {noreply, State};
handle_cast({stop},State) ->
  %% method to stop the monscr ||| Testing purposes not suppose to be use!
  {stop,normal, State};
handle_cast(Msg, State) ->
  lager:info("UKNOWN cast ~p",[Msg]),
  {noreply, State}.


%% handle_info/2
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:handle_info-2">gen_server:handle_info/2</a>
-spec handle_info(Info :: timeout | term(), State :: term()) -> Result when
	Result :: {noreply, NewState}
			| {noreply, NewState, Timeout}
			| {noreply, NewState, hibernate}
			| {stop, Reason :: term(), NewState},
	NewState :: term(),
	Timeout :: non_neg_integer() | infinity.
%% ====================================================================
handle_info({'DOWN',_MonRef,process,Pid,noconnection}, State) ->
  lager:info("Process ~p down",[Pid]),
  role:stop(self()),
  {noreply, State};
handle_info({'DOWN',_MonRef,process,Pid,Reason}, State) ->
  lager:info("Process ~p down reason: ~p",[Pid, Reason]),
  role:stop(self()),
  {noreply, State};
handle_info({'EXIT', Pid, Reason} , State) when Pid =:= State#internal.main_sup ->
  lager:info("Exit From the main supervisor ~p ",[Pid, Reason]),
  {noreply, State};
handle_info({nodedown, Node}, State) ->
  lager:info("NOdedown received ~p",[Node]),
  {noreply, State};
handle_info(timeout, State) ->
  lager:info("Timeout received"),
  {noreply, State};
handle_info(Msg, State) ->
  lager:info("Msg received ~p",[Msg]),
  {noreply, State}.


%% terminate/2
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:terminate-2">gen_server:terminate/2</a>
-spec terminate(Reason, State :: term()) -> Any :: term() when
	Reason :: normal
			| shutdown
			| {shutdown, term()}
			| term().
%% ====================================================================
terminate(_Reason, _State) ->
    %% Clean the registry when stop or crash
    global:unregister_name(monscr),
    ok.


%% code_change/3
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:code_change-3">gen_server:code_change/3</a>
-spec code_change(OldVsn, State :: term(), Extra :: term()) -> Result when
	Result :: {ok, NewState :: term()} | {error, Reason :: term()},
	OldVsn :: Vsn | {down, Vsn},
	Vsn :: term().
%% ====================================================================
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.










%% ====================================================================
%% Internal functions
%%
%% ====================================================================


%% register_imp/2
%% ====================================================================
%% @doc The recieved Id is initialized in the data structure
-spec register_imp(State :: term()) -> Result when
  Result :: {term(), Reply},
  Reply :: {ok, conf_done} | {error, not_pid}.
%% ====================================================================
register_imp(Pid) when is_pid(Pid)->
  Id = 3,
  true = db_utils:ets_insert(child, #child_entry{ id = Id, client = Pid}),
  {registered, Id};
register_imp(State) ->
  {State, {error, no_pid}}.



%% config_protocol_imp/2
%% ====================================================================
%% @doc
-spec config_protocol_imp(Msg :: term(), State :: term()) -> Result when
  Result :: {term(), Reply},
  Reply :: {ok, {ids, RolesIds :: list() }} |
  {error, error_creating_config}.
%% ====================================================================
config_protocol_imp({Id, Role_list}, State)->
  %{self(), [{Id, bid_sebay,client,[sebay],Funcs}
  %          {}]}


  %[P] = db_utils:ets_lookup_raw(child, Id),
  case internal_create_config(Role_list,State) of
    {ok, UState} ->
      Problems = start_roles(Id,Role_list, UState),
      RolesIds = generate_list(Id),

      io:format("Roles Started ~p",[RolesIds]),

      {ok, {RolesIds, Problems}};
    {error,_Reason} -> {error, "[monscr.erl][config_protocol_imp] Error"}
  end.


%% internal_create_config/2
%% ====================================================================
%% @doc
-spec internal_create_config(Conf, State :: term()) -> Result when
  Result :: {ok, term()} | {error, atom()},
  Conf :: {pid(), term()}.
%% ====================================================================
internal_create_config(Roles_list, State) when is_list(Roles_list) ->
  %{Id, [{bid_sebay,client,[sebay],Funcs}
  %          {}]}

      %% Start protocol supervisor if not exists
      {New_protocol_sup_list, _ } = lists:foldl(fun config_prot_roles/2, {State#internal.prot_sup, State#internal.main_sup}, Roles_list),
      {ok, data_utils:internal_update(prot_sup, State,New_protocol_sup_list)};
internal_create_config(_State,_Other) ->
  {error, "[monscr.erl][internal_create_config] Wrong call perameters"}.


%% config_prot_roles/2
%% ====================================================================
%% @doc
-spec config_prot_roles(Config, Data) -> Result when
  Result :: {pid(), list()},
  Config :: {term(), atom(), list()},
  Data :: {pid(), term()}.
%% ====================================================================

config_prot_roles({Prot,_Role,_Roles, _Funcs}, {Protocol_sup_list, Main_sup}) ->
  Return = case lists:keyfind(Prot, 1, Protocol_sup_list) of
    false ->
      {ok,RSup} = sup_role_sup:start_child(Main_sup,none),
      El = data_utils:prot_sup_create(Prot, RSup, []),
      [El | Protocol_sup_list];
    _ -> Protocol_sup_list
  end,
  {Return, Main_sup};
config_prot_roles(_, _) ->
  {error, "[monscr.erl][config_prot_roles] Wrong call parameters"}.


%% start_roles/1
%% ====================================================================
%% @doc
-spec start_roles(Id :: term(), State :: term(), State :: term()) -> Result when
  Result :: {list(),term()}.
%% ====================================================================
start_roles(Id, Role_list, State) ->
  lists:foldl(fun  traverse_supervisors/2, {State#internal.prot_sup, Id, 1, []}, Role_list).


traverse_supervisors({Protocol, Role, Other, Funcs}, {PSup_list, Id,  K , Problems }) when is_list(PSup_list)->

  PSup = lists:keyfind(Protocol, 2, PSup_list),
  %TODO: consider if this should be a match
  ImpRef = db_utils:ets_lookup_client_pid(Id),
  
  LFuncs = lists:foldl(fun({Sig, Func}, Acc) -> [ #func{ sign = Sig, func = Func}| Acc] end,[], Funcs),

  New_spec = data_utils:spec_create(Protocol, Role, Other, ImpRef, LFuncs, undef, undef),
  MProblems = spawn_role( {Id, K},  New_spec, PSup),

  { PSup_list, Id, K+1, [Problems| MProblems] }.



spawn_role(Id, RoleData, RSup) ->

  New_role_data = data_utils:role_data_create(Id, RoleData, undef, undef),

  %Taking the resources path from the config file
  Path = case application:get_env(kernel, resources_path) of
           undefined -> ?RESOURCES_PATH;
             {P} -> P
         end,

        io:format("ID: ~p | ~p ~n",[Id, RoleData]),
    
        io:format("ID PROT SUP: ~p ~n", [RSup#prot_sup.ref]),
    role_sup:start_child(RSup#prot_sup.ref, {Path , New_role_data}),
    %Check if the role has started correctly if not skip the insertion and display log
    %%% %This call must be done just after Spawning the process !!!!!!!!!!!!!!!!!!!
    case role:get_init_state(db_utils:ets_lookup_child_pid(Id)) of
        {ok} -> [];
        Error -> lager:error("Error starting Role, Reason: ~p",[Error]),
            [{RoleData#spec.role, Error} ]
    end.


%% generate_list/1
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:handle_info-2">gen_server:handle_info/2</a>
-spec generate_list(State :: term()) -> Result when
  Result :: term().
%% ====================================================================
generate_list(Key) ->
  List_of_Roles = db_utils:ets_key_pattern_match(Key),
  lager:info("generate_list ~p ~n ", [List_of_Roles]),

  P = ets:foldl(fun(E, Acc) -> [E|Acc]end,[],child),
  lager:info("generate_list ~p ~n", [P]),

  lists:foldl(fun(Child_ent, Acc) ->

    [{ Child_ent#child_entry.id,
       Child_ent#child_entry.data#child_data.protocol,
       Child_ent#child_entry.data#child_data.role,
       Child_ent#child_entry.worker}
       | Acc]

  end, [] ,List_of_Roles).


