%% @author aku
%% @doc @todo Add description to role.

-module(role).
-behaviour(gen_server).

-compile([{parse_transform, lager_transform}]).

-include("records.hrl").

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-export([bcast_msg_to_roles/4,bcast_msg_to_roles/3]).
%% ====================================================================
%% API Exports
%% ====================================================================

-export([start_link/2, send/4, 'end'/2, create/2, cancel/2,  stop/1, get_init_state/1]).

-compile(export_all).


%TODO: this has to be in a config file
-define(USER,  <<"test">>).
-define(PWD,  <<"test">>).
-define(HOST,  "94.23.60.219").
-define(DHOST, "localhost").
-define(PORT, 65005).

-define(TIMER_TIMEOUT, 2000).
%TODO: another reason why callbacks, I can verify that the methods are thre with handle_cast I can't
-define(MUST_METHODS, [{ready,2},
        {config_done,2},
        {cancel,2},
        {terminated,2}]).

%% ====================================================================
%% API functions
%% ====================================================================
create(Name, Protocol)->
    gen_server:call(Name, {create,Protocol}).

'end'(Name,Reason)->
    gen_server:cast(Name,{'end',Reason}).

cancel(Name,Reason)->
    ok = gen_server:cast(Name,{Reason}).

send(Name, Destination, Signature, Content) ->
    gen_server:cast(Name, {send,Destination, Signature, Content}).

stop(Name)->
    gen_server:cast(Name,{stop}).

crash(Name) ->
    gen_server:cast(Name, {crash}).

get_init_state(Name)->
    gen_server:call(Name, {init_state}).

disconnect(Name) ->
    gen_server:call(Name, {disconnect}).

%=============================================================================================================================================================
%=============================================================================================================================================================


%% start_link/1
%% ====================================================================
%% @doc
-spec start_link(Path:: term(), State :: term()) -> Result when
    Result :: {ok, State}
    | {ok, State, Timeout}
    | {ok, State, hibernate}
    | {stop, Reason :: term()}
    | ignore,
    State :: term(),
    Timeout :: non_neg_integer() | infinity.
%% ====================================================================
start_link(Path, State) ->
    NState = data_utils:role_data_update(conn, State, data_utils:conn_create(undef,undef,undef,undef,undef,undef)),
    gen_server:start_link(?MODULE, {Path,NState}, []).



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
init({Path, State}) ->
    case db_utils:ets_lookup_raw(child,State#role_data.id) of
        [P] -> lager:info("[~p] Normal initialitzation",[self()]),
            db_utils:ets_insert(child, P#child_entry{worker = self()} ),
            recovery_init(State, P#child_entry.data);
        []  -> lager:info("[~p] Recovery initialitzation",[self()]),
            SData = #child_data{ protocol = State#role_data.spec#spec.protocol, role = State#role_data.spec#spec.role, secret_number = undef, count = 0, num_lines = undef},
            Ce = #child_entry{ id = State#role_data.id, worker = self(), client = State#role_data.spec#spec.imp_ref, data = SData},
            true = db_utils:ets_insert(child, Ce),
            zero_init(Path, State);
        M -> lager:info("~p",[M]), error
    end.




zero_init(Path, State) ->

    Role = State#role_data.spec#spec.role,

    %This method will load and in case of not having the file requestes it from the source
    Scr = manage_projection_file(Path, State),

    {ok, NumLines} = case db_utils:get_table(Role) of
        {created, TbName} -> lager:info("C"),translate_parsed_to_mnesia(TbName,Scr);
        {exists, TbName} ->  lager:info("E"),translate_parsed_to_mnesia(TbName,Scr);
        P -> lager:info("~p",[P]),P
    end,

    St = check_signatures_and_methods(State#role_data.spec#spec.protocol,
        State#role_data.spec#spec.imp_ref,
        Role,
        State#role_data.spec#spec.funcs),


    {Connection, Channel} = case application:get_env(kernel, rbbt_config) of
        undefined ->   Con  = rbbt_utils:connect(?HOST, ?USER, ?PWD ),
            Ch = rbbt_utils:open_channel(Con),{Con, Ch};
        {ok, {User, Pwd, Host}} -> Con = rbbt_utils:connect(Host, User, Pwd ),
            Ch = rbbt_utils:open_channel(Con), {Con, Ch}
    end,

    Q = rbbt_utils:bind_to_global_exchange(State#role_data.spec#spec.protocol,
        Channel,
        Role),

    Cons = role_consumer:start_link({Channel,Q,self()}),

    Conn = data_utils:conn_create(Connection, Channel, undef, Q, State#role_data.spec#spec.protocol, Cons),

    NSpec = data_utils:spec_update(lines, State#role_data.spec, NumLines),

    Exc = data_utils:exc_create(waiting, 0, undef)}
    ExcU = data_utils:exc_update_mult(Exc, [{confirmation_list, [State#role_data.spec#spec.role | State#role_data.spec#spec.roles] },
                                                            {confirmation_state, none}]),
    NArgs = data_utils:role_data_update_mult(State, [{conn, Conn},{spec,NSpec},{state, St},{exc, ExcU]),

    erlang:monitor(process, State#role_data.spec#spec.imp_ref),
    {ok, NArgs}.



recovery_init(State, SavedState) when SavedState#child_data.secret_number =:= undef->

    %TODO: make sure table exists
    {Connection, Channel} = case application:get_env(kernel, rbbt_config) of
        undefined ->   Con  = rbbt_utils:connect(?HOST, ?USER, ?PWD ),
            Ch = rbbt_utils:open_channel(Con),{Con, Ch};
        {ok, {User, Pwd, Host}} -> Con = rbbt_utils:connect(Host, User, Pwd ),
            Ch = rbbt_utils:open_channel(Con), {Con, Ch}
    end,

    %Bind to the prvious q and exchange
    BName = State#role_data.spec#spec.role,
    Prot =  State#role_data.spec#spec.protocol,

    %Declare the queue an bind it to the new exchange
    Q = rbbt_utils:bind_to_global_exchange(Prot, Channel, BName),

    %Spawn a new consumer for the new queue
    Cons = role_consumer:start_link({Channel,Q,self()}),

    Conn = data_utils:conn_create(Connection, Channel, undef, Q, Prot, Cons),

    NSpec = data_utils:spec_update(lines, State#role_data.spec, SavedState#child_data.num_lines),
    NArgs = data_utils:role_data_update_mult(State, [{conn, Conn},
                                                     {spec,NSpec},
                                                     {state, {ok}},
                                                     {exc, data_utils:exc_create(waiting, SavedState#child_data.count, SavedState#child_data.secret_number)}]),

    erlang:monitor(process, State#role_data.spec#spec.imp_ref),
    {ok, NArgs};
recovery_init(State, SavedState) ->

    %TODO: make sure table exists
    {Connection, Channel} = case application:get_env(kernel, rbbt_config) of
        undefined ->   Con  = rbbt_utils:connect(?HOST, ?USER, ?PWD ),
            Ch = rbbt_utils:open_channel(Con),{Con, Ch};
        {ok, {User, Pwd, Host}} -> Con = rbbt_utils:connect(Host, User, Pwd ),
            Ch = rbbt_utils:open_channel(Con), {Con, Ch}
    end,


    BName = list_to_binary(atom_to_list(State#role_data.spec#spec.role) ++ "_" ++ SavedState#child_data.secret_number),
    Prot = list_to_binary(atom_to_list(State#role_data.spec#spec.protocol) ++ "_" ++ SavedState#child_data.secret_number),
    %Declare the queue an bind it to the new exchange
    Q = rbbt_utils:declare_q(Channel, BName),

    rbbt_utils:bind_q_to_exc(Q, Prot, State#role_data.spec#spec.role, Channel),

    %Spawn a new consumer for the new queue
    Cons = role_consumer:start_link({Channel,Q,self()}),

    Conn = data_utils:conn_create(Connection, Channel, undef, Q, State#role_data.spec#spec.protocol, Cons),

    NSpec = data_utils:spec_update(lines, State#role_data.spec, SavedState#child_data.num_lines),
    NArgs = data_utils:role_data_update_mult(State, [{conn, Conn},{spec,NSpec},{exc, data_utils:exc_create(conver, SavedState#child_data.count, SavedState#child_data.secret_number)}]),

    erlang:monitor(process, State#role_data.spec#spec.imp_ref),
    {ok, NArgs}.






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
handle_call({create,_Protocol},_From,State) when State#role_data.exc#exc.state =:= waiting->
    lager:info("[~p] Create call received",[self()]),
    % Generate aleatori number for private conversations
	Rand =[integer_to_list(crypto:rand_uniform(1, 10)) || _ <- lists:seq(1, 6)],
    % [integer_to_list(random:uniform(10)) || _ <- lists:seq(1, 6)],

    % Form the name for exchange
    Prot = list_to_binary(atom_to_list(State#role_data.spec#spec.protocol) ++ "_" ++ Rand),

    %% NEW Exchange for the specific comunication
    rbbt_utils:declare_exc(State#role_data.conn#conn.active_chn, Prot, <<"direct">>, true),

    % Publish create message to all participiant  === JOIN CONVERSATION
    rbbt_utils:publish_msg(State#role_data.conn#conn.active_chn,
        State#role_data.conn#conn.active_exc,
        {create,State#role_data.spec#spec.role,Rand}),

    Timer = spawn(?MODULE, the_timer, [self(), ?TIMER_TIMEOUT]),


    % Update State with the new data
    Conn = data_utils:conn_update(active_exc, State#role_data.conn, Prot),
    NState = data_utils:role_data_update(conn, State, Conn),
    %NState = data_utils:role_data_update_mult(State,[{conn, Conn},{exc,Exc}]),
    
    {reply,ok,NState};
handle_call({create,_Protocol},_From,State) ->
    {reply, {error, "already in a conversation"}, State};

handle_call({init_state}, _From, State)->

    %% Similar to wait in  posix the process is alive until someone read that the has been an error
    %% If an error is the response then the process ends itself, if not continues as normal
    lager:info("init_state ~p",[State#role_data.state]),
    case State#role_data.state of
        {ok} -> {reply, {ok}, State};
        {error, R} = K -> lager:info("st error"), {stop,R,K,State}
    end;
handle_call(Request, _From, State) ->
    lager:warning("[~p] Unkwon call ~p",[self(),Request]),
    {reply, ok, State}.


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
handle_cast({create, Scr, Rand},State) when State#role_data.exc#exc.state =:= waiting, State#role_data.spec#spec.role =:= Src->
    lager:info("[~p] IM THE SPECIAL ~p",[self(), State]),
    %Terminating the consumer
    ok = terminate_consumer(State),
    %role_consumer:stop(State#role_data.conn#conn.active_cns),

    %Form random names for the queue and exchange
    BName = list_to_binary(atom_to_list(State#role_data.spec#spec.role) ++ "_" ++ Rand),
    Prot = list_to_binary(atom_to_list(State#role_data.spec#spec.protocol) ++ "_" ++ Rand),

    Chn = State#role_data.conn#conn.active_chn,

    %Declare the queue an bind it to the new exchange
    Q = rbbt_utils:declare_q(Chn, BName),
    rbbt_utils:bind_q_to_exc(Q, Prot, State#role_data.spec#spec.role, State#role_data.conn#conn.active_chn),

    %Spawn a new consumer for the new queue
    Cons = role_consumer:start_link({Chn, Q, self()}),

    %Update the State with the new data
    Conn = data_utils:conn_update_mult(State#role_data.conn, [{active_cns, Cons},{active_q, Q},{active_exc, Prot}]),
    Exc = data_utils:exc_update_mult(State#role_data.exc, [{secret_number, Rand},{state, conver}]),
    %Exc = data_utils:exc_update(secret_number, State#role_data.exc, Rand),
    NState = data_utils:role_data_update_mult(State, [{conn, Conn}, {exc, Exc}]),

    %Publish the confirmation of join
    rbbt_utils:publish_msg(Chn, Prot, Src, {confirm, State#role_data.spec#spec.role}),

    {noreply, NState};
handle_cast({create, Src, Rand},State) when State#role_data.exc#exc.state =:= waiting->
    lager:info("[~p] Create cast received from ~p",[self(), Src]),
    lager:info("[~p] Not ~p",[self(), State]),

    %Terminating the consumer
    ok = terminate_consumer(State),
    %role_consumer:stop(State#role_data.conn#conn.active_cns),

    %Form random names for the queue and exchange
    BName = list_to_binary(atom_to_list(State#role_data.spec#spec.role) ++ "_" ++ Rand),
    Prot = list_to_binary(atom_to_list(State#role_data.spec#spec.protocol) ++ "_" ++ Rand),

    Chn = State#role_data.conn#conn.active_chn,

    %Declare the queue an bind it to the new exchange
    Q = rbbt_utils:declare_q(Chn, BName),
    rbbt_utils:bind_q_to_exc(Q, Prot, State#role_data.spec#spec.role, State#role_data.conn#conn.active_chn),

    %Spawn a new consumer for the new queue
    Cons = role_consumer:start_link({Chn, Q, self()}),

    %Update the State with the new data
    Conn = data_utils:conn_update_mult(State#role_data.conn, [{active_cns, Cons},{active_q, Q},{active_exc, Prot}]),
    Exc = data_utils:exc_update_mult(State#role_data.exc, [{secret_number, Rand},{state, conver}]),
    %Exc = data_utils:exc_update(secret_number, State#role_data.exc, Rand),
    NState = data_utils:role_data_update_mult(State, [{conn, Conn}, {exc, Exc}]),

    %Publish the confirmation of join
    timer:sleep(crypto:rand_uniform(1000,3000)),
    rbbt_utils:publish_msg(Chn, Prot, Src, {confirm, State#role_data.spec#spec.role}),
    lager:info("Confirmation message sent from ~p",[State#role_data.spec#spec.role]),
    {noreply, NState};
handle_cast({confirm,Role},State) ->
    lager:info("~p",[State]),
    NState = case lists:delete(Role, State#role_data.exc#exc.confirmation_list) of
        [] ->   State#role_data.exc#exc.timer_pid ! kill,
                lager:info("[~p] All roles confirmed",[self()]),
                bcast_msg_to_roles(all,State,{ready}),
                Exc = data_utils:exc_update_mult(State#role_data.exc, [{confirmation_list,[]},{confirmation_state, all_confirmed}]),
                data_utils:role_data_update(exc, State, Exc);

        New_waiting_list -> State#role_data.exc#exc.timer_pid ! restart,
                Exc = data_utils:exc_update( confirmation_list , State#role_data.exc, New_waiting_list),
                data_utils:role_data_update(exc, State, Exc)
    end,
    {noreply, NState};
handle_cast({confirmation_timeout}, State) ->
    lager:error("[~p] Timeout",[self()]),
    bcast_msg_to_roles(others, State, {cancel, State#role_data.spec#spec.protocol}),
    gen_monrcp:send(State#role_data.spec#spec.imp_ref, {callback,cancel,{timeout}}),
    role:'end'(self(),"time_out waiting for confirmation"),
    Exc = data_utils:exc_update(secret_number, State#role_data.exc, undef),
    data_utils:role_data_update_mult(State, [{exc, Exc}]),

    {noreply, State};
handle_cast({ready},State) ->
    lager:info("[~p] Sending READY to ~p",[self(), State#role_data.spec#spec.imp_ref]),
    gen_monrcp:send(State#role_data.spec#spec.imp_ref, {callback,ready,{ready}}),
    Exc = data_utils:exc_update_mult(State#role_data.exc, [{state, conver},{count, 0}]),
    {noreply, data_utils:role_data_update(exc, State, Exc)};
handle_cast({send,Dest,Sig,Cont} = Pc, State) when State#role_data.exc#exc.state =:= conver ->

    Record = db_utils:get_row(State#role_data.spec#spec.role, State#role_data.exc#exc.count),

    Exc = case match_directive(Record,
            to,
            Pc,
            State#role_data.exc#exc.count,
            State#role_data.spec#spec.lines, State#role_data.spec#spec.role) of

        {ok, Num} ->  %If the messgae to be send is correct according to the protocol it is publish
            rbbt_utils:publish_msg(State#role_data.conn#conn.active_chn,
                State#role_data.conn#conn.active_exc,
                Dest,
                {msg, State#role_data.spec#spec.role, Sig, Cont}
            ),

            State#role_data.exc#exc{ count = Num};
        {error} -> lager:info("[~p] error detected aborting comunication!",[self()]),
            cancel_protocol(State),
            State#role_data.exc
    end,

    NState = data_utils:role_data_update(exc, State, Exc),
    check_for_termination(NState, Exc#exc.count),
    {noreply,NState};
handle_cast({send,_Dest,_Sig,_Cont}, State) ->
    gen_monrcp:send(State#role_data.spec#spec.imp_ref,{callback, error,{error, sent_and_no_active_conversation}}),
    {noreply, State};
handle_cast({msg,_Ordest,Sig,Cont}=Pc,State) when State#role_data.exc#exc.state =:= conver ->

    Record = db_utils:get_row(State#role_data.spec#spec.role, State#role_data.exc#exc.count),

    Exc = case match_directive(Record,
            from,
            Pc,
            State#role_data.exc#exc.count,
            State#role_data.spec#spec.lines,
            State#role_data.spec#spec.role) of

        {ok, Num} ->  {func,_s,Fimp} = lists:keyfind(Sig, 2, State#role_data.spec#spec.funcs),

            gen_monrcp:send(State#role_data.spec#spec.imp_ref,{callback,Fimp,{msg,Cont}}),
            State#role_data.exc#exc{ count = Num };
        {error} ->  lager:info("[~p] error detected aborting comunication!",[self()]),
            cancel_protocol(State),
            State#role_data.exc
    end,

    NState = data_utils:role_data_update(exc, State, Exc),
    check_for_termination(NState, Exc#exc.count),
    {noreply,NState};
handle_cast({msg,_Ordest,_Sig,_Cont},State) ->
    gen_monrcp:send(State#role_data.spec#spec.imp_ref,{callback, error, {error, recv_and_no_active_conversation}}),
    {noreply, State};
handle_cast({'end',_Prot},State)->
    lager:info("[~p] 'end' cast",[self()]),
    %Terminating the consumer
    ok = terminate_consumer(State),
    %role_consumer:stop(State#role_data.conn#conn.active_cns),

    Channel = State#role_data.conn#conn.active_chn,

    Q = rbbt_utils:bind_to_global_exchange(State#role_data.spec#spec.protocol,
        Channel,
        State#role_data.spec#spec.role),

    Cons = role_consumer:start_link({Channel,Q,self()}),

    Aux = data_utils:conn_create(State#role_data.conn#conn.connection,Channel,undef,Q,State#role_data.spec#spec.protocol,Cons),
    Exc = data_utils:exc_update_mult(Exc, [{confirmation_list, [State#role_data.spec#spec.role | State#role_data.spec#spec.roles] },
                                            {confirmation_state, none},
                                            {state, waiting}]),
    NArgs = data_utils:role_data_update_mult(State,[{conn, Aux}, {exc, Exc}]),
    %NArgs = data_utils:role_data_update(conn, State, Aux),

    {noreply,NArgs};
handle_cast({terminated,_Prot},State)->
    lager:info("[~p] terminated cast",[self()]),
    gen_monrcp:send(State#role_data.spec#spec.imp_ref,{'callback','terminated',{reason,normal}}),
    role:'end'(self(),State#role_data.spec#spec.protocol),

    Exc = data_utils:exc_update(secret_number, State#role_data.exc, undef),
    NState = data_utils:role_data_update_mult(State, [{exc, Exc}]),
    {noreply,NState};
handle_cast({cancel,Prot},State)->
    role:'end'(self(),Prot),
    {noreply, State};
handle_cast({crash},State)->
    {stop, abnormal, State};
handle_cast({stop},State)->
    {stop, normal, State};
handle_cast(Request, State) ->
    lager:warning("[~p] Unkwon cast ~p",[self(), Request]),
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
handle_info({'DOWN',_MonRef,process,Pid,noconnection}, State) when Pid =:= State#role_data.spec#spec.imp_ref ->
    lager:info("DOWN STOPING FOR noconnection OK"),
    {stop, normal,State};
handle_info({'DOWN',_MonRef,process,Pid,normal}, State) when Pid =:= State#role_data.spec#spec.imp_ref ->
    lager:info("DOwn STOPING FOR normal halt"),
    {stop, normal, State};
handle_info({'DOWN',_MonRef,process,Pid,Reason}, State) ->
    lager:info("Process ~p down reason: ~p ~p",[Pid, State#role_data.spec#spec.imp_ref, Reason]),
    {noreply, State};
handle_info({'EXIT', Pid, Reason} , State) ->
    lager:info("Exit in Role received ~p ~p ",[Pid, Reason]),
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
terminate(normal, State) ->
    lager:info("[~p] Terminating role normally",[self()]),

    db_utils:ets_remove_child_entry(State#role_data.id),

    ok = terminate_consumer(State),

    rbbt_utils:delete_q(State#role_data.conn#conn.active_chn,State#role_data.conn#conn.active_q),
    %% Close the connection
    amqp_channel:close(State#role_data.conn#conn.active_chn),
    amqp_connection:close(State#role_data.conn#conn.connection),
    ok;
terminate(Reason, State) ->
    lager:info("[~p] Terminating role with reason ~p",[self(),Reason]),

    [P] = db_utils:ets_lookup_raw(child, State#role_data.id),
    %TODO: AM I KILLLING THE CHANNEL BEFORE ROLE_CONSUMER ENDS??????
    SData = #child_data{ count = State#role_data.exc#exc.count, secret_number = State#role_data.exc#exc.secret_number},
    lager:info("SDATA ~p",[SData]),

    NP = P#child_entry{data = SData},

    db_utils:ets_insert(child, NP),

    ok = terminate_consumer(State),

    rbbt_utils:delete_q(State#role_data.conn#conn.active_chn,State#role_data.conn#conn.active_q),
    %% Close the connection
    amqp_channel:close(State#role_data.conn#conn.active_chn),
    amqp_connection:close(State#role_data.conn#conn.connection),
    ok.


terminate_consumer(State)->

    Pid = State#role_data.conn#conn.active_cns,
    %role_consumer:stop(State#role_data.conn#conn.active_cns),
    unlink(Pid),
    Ref = monitor(process, Pid),
    role_consumer:stop(Pid),
    receive
        {'DOWN', Ref, process, Pid, _Reason} ->
            ok
    after 1000 ->
            error(exit_timeout)
    end.


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


%%
%% Utilities
%% ===================================================================

check_signatures_and_methods(Protocol, Ref, TableName, CallBackList) ->
    case check_signatures(TableName, CallBackList) of
        {ok} ->  lager:info("[~p] Signature checking done",[self()]),
            %be carefull dont put anything after check_method it modifies the return!!
            check_method(Protocol, Ref, CallBackList);
        M -> M
    end.


%% check_signatures/2
%% ====================================================================
%% @doc
-spec check_signatures(TableName :: term(), CallbackList :: integer()) -> Result when
    Result :: {ok} | {error, Reason},
    Reason :: signature_not_found | wrong_call | unkown.
%% ====================================================================
check_signatures(TableName, CallbackList) when is_list(CallbackList)->

    case catch lists:foreach(fun(Element)->

                    case  mnesia:dirty_match_object(TableName, #row{ num = '_' , inst = {'_', Element#func.sign, '_'}}) of
                        [] -> throw(signature_not_found);
                        _  -> ok
                    end

            end, CallbackList) of
        signature_not_found -> {error, signature_not_found};
        ok -> {ok};
        _ -> lager:error("uknown check_signatures"),
            {error, unkown}
    end;
check_signatures(_TableName, _CallbackList) ->
    {error, wrang_call}.


check_method(Protocol, Ref, Declare_funcs) ->

    %Generate the list of funcions declared by user in the config to check if they are implemented
    Dfuncs = lists:foldl(fun(E,Acc) -> [{E#func.func,2} | Acc] end,[], Declare_funcs),

    lager:info("~p ~p ~n",[Ref,Protocol]),
    case catch gen_server:call(Ref,{methods,Protocol}) of
        {ok, List} -> case check_lists(?MUST_METHODS, List) of
                {ok} -> check_lists(Dfuncs, List);
                M -> M
            end;
        _ -> lager:error("uknown check_medhot"),
            {error, unkown}
    end.


check_lists(L1,L2) ->
    case catch match_lists(L1, L2) of
        {ok} -> {ok};
        method_not_found -> {error, method_not_found};
        arity_missmatch  -> {error, arity_missmatch}
    end.


match_lists([],_)->
    {ok};
match_lists([ {K,A} | Must_list], List) when is_list(List) ->
    case lists:keyfind(K,1,List) of
        {_, Arity} when Arity =:= A -> match_lists(Must_list, List);
        {_, Arity} when Arity =/= A -> throw(arity_missmatch);
        _ -> throw(method_not_found)
    end.


%% check_for_termination/2
%% ====================================================================
%% @doc
-spec check_for_termination(State :: term(), CurLine :: integer()) -> Result when
    Result :: true | false.
%% ====================================================================
check_for_termination(State,CurLine)->
    case State#role_data.spec#spec.lines of
        N when N =:= CurLine ->
            bcast_msg_to_roles(self,State,{terminated,State#role_data.spec#spec.protocol});
        _ -> false
    end.



manage_projection_file(Path, State)->

    %TODO: solve conflictivity folders when downlaod and source in the localhost
    % Answare: There is no conflictivit I dont want to download when running from and app We share folder no?
    FileName = atom_to_list(State#role_data.spec#spec.protocol) ++ "_" ++ atom_to_list(State#role_data.spec#spec.role) ++ ".scr",

    case file:read_file(Path ++ FileName) of
        {ok, Binary} ->
            {ok,Final,_} = erl_scan:string(binary_to_list(Binary),1,[{reserved_word_fun, fun mytokens/1}]),
            {ok,Scr} = scribble:parse(Final),
            Scr;

        {error, _Reason} ->

            {Host, Port} = case application:get_env(kernel, download_port) of
                undefined -> {?DHOST, ?PORT};
                {ok, {H,P}} -> {H,P}
            end,

            Listen = open_reception_socket(Port),

            request_file_source(State#role_data.spec#spec.imp_ref, FileName, Host , Port),
            Socket = acceptor(Listen),

            download_projection_from_source(Socket, Path, FileName),

            {ok, Binary} = file:read_file(Path ++ FileName),
            {ok,Final,_} = erl_scan:string(binary_to_list(Binary),1,[{reserved_word_fun, fun mytokens/1}]),
            {ok,Scr} = scribble:parse(Final),
            Scr
    end.


open_reception_socket(Port)->
    {ok, Listen} = gen_tcp:listen(Port, [binary, {active, false}, {reuseaddr, true}]),
    Listen.

acceptor(Listen) ->
    case gen_tcp:accept(Listen) of
        {ok,Socket} -> Socket;
        {error, Reason} -> lager:error("Could not be accepted ~s ~n",[Reason])
    end.


request_file_source(ImpRef, FileName, Host, Port) ->
    gen_monrcp:send(ImpRef, {callback,projection_request,{send,FileName,Host, Port}}).


download_projection_from_source(Socket, Path, Filename) ->
    Bs = file_receiver_loop(Socket, <<"">>),
    save_file(Path, Filename,Bs).

file_receiver_loop(Socket,Bs)->
    %lager:info("insie"),
    case gen_tcp:recv(Socket, 0) of
        {ok, B} -> file_receiver_loop(Socket,[Bs, B]);
        {error, closed} -> gen_tcp:close(Socket), Bs;
        M -> lager:info("Error uknown ~p",[M])
    end.

save_file(Path, Filename,Bs) ->
    PathFile  = Path ++ Filename,

    {ok, Fd} = file:open(PathFile, write),
    file:write(Fd, Bs),
    file:close(Fd).




%% cancel_protocol/2
%% ====================================================================
%% @doc
-spec cancel_protocol(State :: term()) -> Any :: term().
%% ====================================================================
cancel_protocol(State)->
    Msg = {cancel,State#role_data.spec#spec.protocol},
    bcast_msg_to_roles(all, State, Msg).


%% bcast_msg_to_roles/3
%% ====================================================================
%% @doc Easy methods to call bcas_msg_to_roles/4
-spec bcast_msg_to_roles(Dest :: atom(), State :: term(), Msg :: term()) -> Result when
    Result :: true.
%% ====================================================================

bcast_msg_to_roles(all,State,Msg)->
    bcast_msg_to_roles([State#role_data.spec#spec.role | State#role_data.spec#spec.roles],
        State#role_data.conn#conn.active_exc,
        State#role_data.conn#conn.active_chn,
        Msg);
bcast_msg_to_roles(others,State,Msg)->
    bcast_msg_to_roles(State#role_data.spec#spec.roles,
        State#role_data.conn#conn.active_exc,
        State#role_data.conn#conn.active_chn,
        Msg);
bcast_msg_to_roles(self,State,Msg) ->
    bcast_msg_to_roles([State#role_data.spec#spec.role],
        State#role_data.conn#conn.active_exc,
        State#role_data.conn#conn.active_chn,
        Msg).


%% bcast_msg_to_roles/4
%% ====================================================================
%% @doc Recursive function to send messages to all roles in the list
%-spec bcast_msg_to_roles(List :: list(), Content :: term(), Ex :: term(), Chn :: term()) -> Result when
%    Result :: true.
%% ====================================================================
bcast_msg_to_roles([],_Content,_Ex,_Chn)->
    true;
bcast_msg_to_roles([Role|Roles],Exc,Chn,Content)->
    rbbt_utils:publish_msg(Chn,Exc,Role,Content),
    bcast_msg_to_roles(Roles,Exc,Chn,Content).


%%
%% Verification of protocols
%% ===================================================================



%% match_directive/2
%% ====================================================================
%% @doc
-spec match_directive(Record :: term(), Flag :: atom(), Pc, Num :: integer(), MaxN :: integer(), Tbl :: atom()) -> Result when
    Result :: {error} | term(),
    Pc :: {term(), atom(), atom(), term()}.
%% ====================================================================
match_directive(Record,Flag,{_,Ordest,Sig,_Cont} = Pc,Num,MaxN,Tbl) ->
    case Record of
        {from,Lbl,Src} when Flag =:= from, Lbl =:= Sig, Src =:= Ordest -> case_continue(Pc,Num+1,MaxN,Tbl);  
        {to,Lbl,Dest} when Flag =:= to, Lbl =:= Sig, Dest =:= Ordest -> case_continue(Pc,Num+1,MaxN,Tbl);
        {choice,_name,Lines} -> Npath = find_path(Lines,Pc,Flag,MaxN,Tbl), case_continue(Pc,Npath,MaxN,Tbl);
        {continue,NNum} -> case_continue(Pc,NNum,MaxN,Tbl);
        T -> lager:error("[~p] MISSMATCH Revise your code!!!! ~p, ~p, ~p, ~p",[self(),T, Record, Sig, Ordest]),{error}
    end.



%% case_continue/4
%% ====================================================================
%% @doc
-spec case_continue(Pc :: term(), Num :: term(), MaxN :: integer(), Tbl :: term()) -> Result when
    Result :: {ok, integer()} | {ok, term()}.
%% ====================================================================
case_continue(Pc,Num,MaxN,Tbl) when Num < MaxN ->
    Record =  db_utils:get_row(Tbl, Num),
    case Record of
        {continue, _N} -> match_directive(Record, none,Pc, Num, MaxN,Tbl);
        _ -> {ok, Num}
    end;
case_continue(_Pc,Num,MaxN,_Tbl) when Num >= MaxN ->
    {ok,MaxN}.


%% find_path/5
%% ====================================================================
%% @doc
-spec find_path(Or :: list(), Pc :: term(), Flag :: term(), MaxN :: integer(), Tbl :: term()) -> Result  when
    Result :: term() | {error}.
%% ====================================================================
find_path([],_Pc,_Flag,_MaxN,_Tbl) ->
    {error};
find_path([{'or',Line} | R],Pc,Flag,MaxN,Tbl) ->
    Record =  db_utils:get_row(Tbl, Line),
    case match_directive(Record,Flag,Pc,Line,MaxN,Tbl) of
        {ok, N} -> N;
        {error} -> find_path(R,Pc,Flag,MaxN,Tbl)
    end.




%
% Parsing functions
% ==================================================================


%% translate_parsed_to_mnesia/2
%% ====================================================================
%% @doc
-spec translate_parsed_to_mnesia(Role :: term(), Content :: term()) -> Result when
    Result :: {ok, term()}.
%% ====================================================================
translate_parsed_to_mnesia(Role,Content)->
    %Be careful with the value of the name of the table to avoig colisions!!!! 
    Mer = db_utils:ets_create(tmp_table, [set]),
    {_,_,Tnum,_,_} = prot_iterator(Content, {Role,Mer,0,[],none}),
    fix_endings(Role,Mer,Tnum-1),
    %db_utils:ets_print_table(Role, 0, Tnum),
    {ok,Tnum}.



%% fix_endings/3
%% ====================================================================
%% @doc
-spec fix_endings(TbName :: term(), Mer:: term(), Clines :: term()) -> Result when
    Result :: ok.
%% ====================================================================
fix_endings(_TbName ,_Mer, 0) ->
    ok;
fix_endings(TbName, Mer, Clines) ->
    Record = db_utils:get_row(TbName, Clines),
    case Record of
        {econtinue,CName} ->
            Line = db_utils:ets_lookup(Mer, CName),
            db_utils:update_row(TbName,Clines,{continue, Line});
        _ -> ok
    end,
    fix_endings(TbName, Mer, Clines-1).


%% prot_iterator/2
%% ====================================================================
%% @doc
-spec prot_iterator(Tcp :: term(), St :: {TbName, RName, Num, Special, Erecname})-> Result :: term() when
    TbName :: term(),
    RName :: term(),
    Num :: term(),
    Special :: term(),
    Erecname :: term().
%% ====================================================================
prot_iterator( Tp,{TbName,RName,Num,Special,Erecname}) when is_list(Tp) ->
    lists:foldl(fun prot_iterator/2,{TbName,RName,Num,Special,Erecname}, Tp);
prot_iterator({protocol,_Name,_Role, _Roles,Content}, St) ->
    lists:foldl(fun prot_iterator/2,St, Content);
prot_iterator({from,{atom,_,Lbl},{atom,_,Src}}, {TbName,RName,Num,Special,Erecname}) ->
    db_utils:add_row(TbName,Num,{from,Lbl,Src}),
    {TbName,RName,Num+1,Special,Erecname};
prot_iterator({to,{atom,_,Lbl},{atom,_,Dest}}, {TbName,RName,Num,Special,Erecname}) ->
    db_utils:add_row(TbName,Num,{to,Lbl,Dest}),
    {TbName,RName,Num+1,Special,Erecname};
prot_iterator({choice,{atom,_,Name},Content}, {TbName,RName,Num,Special,Erecname}) ->
    Rn =binary_to_atom(list_to_binary( [integer_to_list(random:uniform(10)) || _ <- lists:seq(1, 6)]),utf8),
    {NTbName, NRName,NNum, NSpecial,_Erecname} = lists:foldl(fun prot_iterator/2, {TbName,RName, Num+1, Special, Rn},Content),
    db_utils:add_row(TbName,Num,{choice,Name,[{'or',Num+1} | NSpecial]}),
    {NTbName, NRName, NNum, [],Erecname};
prot_iterator({rec,{atom,_Num,CName}, RecContent} , {TbName,RName,Num,Special,Erecname}) ->
    db_utils:ets_insert(RName, {CName,Num}),
    lists:foldl(fun prot_iterator/2,{TbName, RName, Num, Special, Erecname}, RecContent);
prot_iterator({continue, {atom,_Num,CName}}, {TbName,RName,Num,Special,Erecname}) ->
    Line = db_utils:ets_lookup(RName, CName),
    db_utils:add_row(TbName,Num,{continue,Line}),
    {TbName,RName,Num+1,Special,Erecname};
prot_iterator({'or', Content}, {TbName,RName,Num,Special,Erecname}) ->
    {NTbName, NRName,NNum, _NSpecial, _Erecname} = lists:foldl(fun prot_iterator/2,{TbName, RName, Num, Special, Erecname}, Content),
    {NTbName,NRName,NNum,[ {'or',Num } | Special ],Erecname};
prot_iterator({par,Content}, {TbName,RName,Num,Special,Erecname}) ->
    {NTbName, NRName,NNum, NSpecial,Erecname} = lists:foldl(fun prot_iterator/2,{TbName, RName, Num+1,Special, Erecname}, Content),
    db_utils:add_row(TbName,Num,{choice,NSpecial}),
    {NTbName, NRName,NNum, [],Erecname};
prot_iterator({'and', Content}, {TbName,RName,Num,Special,Erecname}) ->
    {NTbName, NRName,NNum, _NSpecial, Erecname} = lists:foldl(fun prot_iterator/2,{TbName, RName, Num, Special,Erecname}, Content),
    {NTbName,NRName,NNum,[ {'or',Num } | Special ],Erecname};
prot_iterator({erec, _Content}, {TbName,RName,Num,Special,Erecname}) ->
    {econtinue, CName} = db_utils:get_row(TbName, Num-1),
    db_utils:ets_insert(RName, {CName, Num}),
    {TbName,RName,Num,Special,Erecname};
prot_iterator({econtinue, _Content}, {TbName,RName,Num,Special,Erecname}) ->
    db_utils:add_row(TbName, Num, {econtinue, Erecname}),
    {TbName,RName,Num+1,Special,Erecname};
prot_iterator(M, N) ->
    lager:error("~p ~p",[M, N]),
    abort.




%% timer_process/2
%% ====================================================================
%% @doc

%% ====================================================================
the_timer(Master, Time) ->
    receive
        restart ->
            the_timer(Master, Time);
        kill ->
            done
    after Time ->
            gen_server:cast(Master, {confirmation_timeout})
    end.


%% mytokens/1
%% ====================================================================
%% @doc
-spec mytokens(Word :: term()) -> Result when
    Result :: true
    | false.
%% ====================================================================

mytokens(Word) ->
    case Word of
        '<' -> true;
        '>' -> true;
        type -> true;
        module -> true;
        'and' -> true;
        as -> true;
        at -> true;
        by -> true;
        'catch' -> true;
        choice -> true;
        continue -> true;
        econtinue -> true;
        create -> true;
        do -> true;
        enter -> true;
        from -> true;
        global -> true;
        import -> true;
        instantiates -> true;
        interruptible -> true;
        local -> true;
        'or' -> true;
        par -> true;
        protocol -> true;
        rec -> true;
        erec -> true;
        role -> true;
        spawns -> true;
        throw -> true;
        to -> true;
        with -> true;
        _ -> false
    end.
