%% @author aku
%% @doc @todo Add description to monscr.

-module(monscr).
-behaviour(gen_server).

-compile([{parse_transform, lager_transform}]).

-include("records.hrl").

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
%% ====================================================================
%% API exports
%% ====================================================================
-export([start_link/1,register/2,config_protocol/2]).


%% ====================================================================
%% API functions
%% ====================================================================

%% register/2
%% ====================================================================
%% @doc
%%
%% @end
register(Name,Pid) ->
  gen_server:call(Name,{register,Pid}).


%% config_protocol/2
%% ====================================================================
%% @doc
%%
%% @end
config_protocol(Name,Protocol) ->
  gen_server:cast(Name, {config,Protocol}).



%% ====================================================================
%% Behavioural functions 
%% ====================================================================
start_link([]) ->
	gen_server:start_link(?MODULE, [], []).


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
	erlang:register(monscr, self()),
	{ok,Main_sup} = sup_role_sup:start_link(),
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
handle_call({register,Id},_From,State) ->
	{UState,Reply} = register_imp(Id, State),
	{reply,Reply,UState};
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
handle_cast({config,{Pid,_ } = Config } , State) ->
  lager:info("handle_caset config"),
  {ok,UState, Reply} = config_protocol_imp(Config, State),
  lager:info("send ids list back"),
  gen_monrcp:send(Pid, {callback, config_done,Reply}),
  {noreply, UState};
handle_cast(_Msg, State) ->
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
handle_info(_Info, State) ->
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
%% ====================================================================


%% register_imp/2
%% ====================================================================
%% @doc The recieved Id is initialized in the data structure
-spec register_imp(Id :: pid(), State :: term()) -> Result when
  Result :: {term(), Reply},
  Reply :: {ok, conf_done} | {error, not_pid}.
%% ====================================================================
register_imp(Id, State) when is_pid(Id)->
  UState = data_utils:internal_add_regp(State, Id),
  {UState,{ok,conf_done}};
register_imp(_Id, State) ->
  {State, {error, no_pid}}.



%% config_protocol_imp/2
%% ====================================================================
%% @doc
-spec config_protocol_imp(Msg :: term(), State :: term()) -> Result when
  Result :: {term(), Reply},
  Reply :: {ok, {ids, RolesIds :: list() }} |
  {error, error_creating_config}.
%% ====================================================================
config_protocol_imp(Config, State)->
  case internal_create_config(Config,State) of
    {ok, UState} ->
      {NUState, RolesIds} = start_roles(UState),
      lager:info("Roles Started ~p",[RolesIds]),
      {ok,NUState, {ids, RolesIds}};
    {error,_Reason} -> {State, {error, "[monscr.erl][config_protocol_imp] Error"}}
    %TODO: why I'm returning State when error? required?
  end.


%% internal_create_config/2
%% ====================================================================
%% @doc
-spec internal_create_config(Conf, State :: term()) -> Result when
  Result :: {ok, term()} | {error, atom()},
  Conf :: {pid(), term()}.
%% ====================================================================
internal_create_config({Pid,{Roles_list, Function_list}}, State) when is_pid(Pid), is_list(Roles_list), is_list(Function_list)->
      {_Pid,New_protocol_sup_list} = lists:foldl(fun config_prot_roles/2, {Pid, State#internal.prot_sup}, Roles_list),
      {_pid,New_protocol_sup_list2} = lists:foldl(fun config_funcs/2 , {Pid,New_protocol_sup_list}, Function_list),
      {ok, data_utils:internal_update(prot_sup, State,New_protocol_sup_list2)};
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
config_prot_roles({Prot,Role,Roles}, {Pid,Protocol_sup_list}) ->
  Return = case lists:keyfind(Prot, 1, Protocol_sup_list) of
    false -> NewRole = data_utils:lrole_create(Role, Roles, Pid, []),
             El = data_utils:prot_sup_create(Prot, undef, [NewRole]),
             [El];
    Sup_intance ->
      NewRole = data_utils:lrole_create(Role, Roles, Pid, []),
      Updated_prot_sup  = data_utils:prot_sup_add_role(Sup_intance, NewRole),
      lists:keyreplace(Prot, 1, Protocol_sup_list, Updated_prot_sup)
  end,
  {Pid,Return};
config_prot_roles(_, _) ->
  {error, "[monscr.erl][config_prot_roles] Wrong call parameters"}.


%% config_funcs/2
%% ====================================================================
%% @doc
-spec config_funcs(Config, Data) -> Result when
  Result :: {pid(), list()},
  Config :: {term(), atom(), term(), atom()},
  Data :: {pid(), term()}.
%% ====================================================================
config_funcs({Protocol, Role, Message,Function},{Pid,Acc}) ->
  Return = case lists:keyfind(Protocol, 2, Acc) of
    false -> {error, bad_arguments};
    M -> case lists:keyfind(Role, 2, M#prot_sup.roles) of
           false -> {error, role_not_defined};
           L ->
             New_Func = data_utils:func_create(Message, Function),
             New = data_utils:lrole_add_func(L, New_Func),

             Nprot = lists:keyreplace(Role, 2, M#prot_sup.roles, New),
             NM = data_utils:prot_sup_update(roles, M, Nprot),
             lists:keyreplace(Protocol, 2, Acc, NM)
         end
  end,
  {Pid,Return};
config_funcs(_,_) ->
  {error, "[monscr.erl][config_funcs] Wrong call parameters"}.



%% start_roles/1
%% ====================================================================
%% @doc
-spec start_roles(State :: term()) -> Result when
  Result :: {list(),term()}.
%% ====================================================================
start_roles(State) ->
  UState = lists:foldl(fun  traverse_supervisors/2, State, State#internal.prot_sup),
  Started_roles = generate_list(UState),
  {UState, Started_roles}.


traverse_supervisors(Prot_supervisor, Acc) ->
    Protocol = Prot_supervisor#prot_sup.protocol,
    Roles = Prot_supervisor#prot_sup.roles,

    {ok,RSup} = sup_role_sup:start_child(Acc#internal.main_sup,none),
    {_,_,NRoles} = lists:foldl(fun spawn_role/2,{Protocol, RSup, Roles}, Roles),
    NM = data_utils:prot_sup_update(roles, Prot_supervisor, NRoles),
    Almost = lists:keyreplace(Protocol, 2, Acc#internal.prot_sup, NM),
  data_utils:internal_update(prot_sup, Acc, Almost).



spawn_role(Role, {Prot, RSup, Acc}) ->
  RRole = Role#lrole.role,
  RRoles = Role#lrole.roles,
  RImpRef = Role#lrole.imp_ref,
  RFuncs = Role#lrole.funcs,

  Result = case Role#lrole.ref of
    undefined  ->
      New_spec = data_utils:spec_create(Prot, RRole, RRoles, undef, RImpRef, RFuncs, undef, undef),
      New_role_data = data_utils:role_data_create(New_spec, undef, enf),
      {ok,RoleId} =  role_sup:start_child(RSup, New_role_data),
      lists:keyreplace(Role#lrole.role, 2, Acc, data_utils:lrole_update(ref, Role, RoleId));
    _ -> lager:info("[~p] already added NOT adding it again",[Role]),
      Acc
  end,
  {Prot, RSup, Result}.


%% generate_list/1
%% ====================================================================
%% @doc <a href="http://www.erlang.org/doc/man/gen_server.html#Module:handle_info-2">gen_server:handle_info/2</a>
-spec generate_list(State :: term()) -> Result when
  Result :: term().
%% ====================================================================
generate_list(State) ->
  lists:foldl(fun(Protocol_sup, Acc1) ->
    lists:foldl(fun(Role, Acc2) ->
      [{Protocol_sup#prot_sup.protocol,
        Role#lrole.role,
        Role#lrole.ref}|Acc2]
    end, Acc1, Protocol_sup#prot_sup.roles)
  end, [], State#internal.prot_sup).







