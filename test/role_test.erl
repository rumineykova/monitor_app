%% @author aku
%% @doc @todo Add description to role_test.


-module(role_test).
-include("../include/records.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").
%% ====================================================================
%% API functions
%% ====================================================================
-compile(export_all).

-compile([{parse_transform, lager_transform}]).
%% ====================================================================
%% Internal functions
%% ====================================================================

start_test()->
  db_utils:install(node(), "../db/"),
  db_utils:get_table(prova),

  Spec = data_utils:spec_create(bid_sebay, client, [sebay], undef, self(), [], undef, undef),
	State = #role_data{ spec = Spec },
  {ok, Return} = role:start_link(State),
	?assertEqual(true, is_pid(Return)).

prot_iterator_test() ->
	lager:start(),
	
  %% OMG Massive error if the directdory does not exists or can't be reache, BAD_TYPE can't update!!!!!!
  %application:set_env(mnesia, dir, "../db/"),


	{ok,Data} = file:read_file("../resources/client.scr"),
	{ok,Final,_} = erl_scan:string(binary_to_list(Data),1,[{reserved_word_fun, fun mytokens/1}]),
	{ok,Scr} = scribble:parse(Final),

  db_utils:install(node(),"db"),
  case db_utils:get_table(prova) of
    {created, TbName} ->   role:translate_parsed_to_mnesia(TbName,Scr);
    {exists, TbName} -> role:translate_parsed_to_mnesia(TbName,Scr);
    {error, Reason} -> lager:error("~p",[Reason])
  end,

	?assertMatch({ok,_N}, {ok,4} ).


wait_for_confirmation_test()->

  self() ! {confirm, me},

  Roles = [me],

  Ok = role:wait_for_confirmation(Roles),
  ?assertEqual(ok,Ok).



create_conersation_test()->
  db_utils:install(node(), "../db/"),
  db_utils:get_table(prova),

  Spec = data_utils:spec_create(bid_sebay, client, [sebay], undef, self(), [], undef, undef),
  State = #role_data{ spec = Spec },
  {ok, Return} = role:start_link(State),
  ?assertEqual(true, is_pid(Return)),

  role:create(Return, bid_sebay),
  timer:sleep(3500),
  %TODO: fix this

  Return1 = receive
             {'$gen_call',_,{timeout}} -> ok ;
             _ -> error
           end,
  ?assertEqual(ok, Return1).


%Todo this does not works
%ready_test()->
%  db_utils:install(node(), "../db/"),
%  db_utils:get_table(prova),
%
%  Spec = data_utils:spec_create(bid_sebay, client, [], undef, self(), [], undef, undef),
%  State = #role_data{ spec = Spec },
%  {ok, Return} = role:start_link(State),
%  ?assertEqual(true, is_pid(Return)),
%
%  %TODO: what happends if wrong protocol is specified
%  role:create(Return, bid_sebay),
%  %TODO: fix this
%
%  Return1 = receive
%             M -> M;
%             _ -> error
%           end,
%  ?assertEqual(ok, Return1).


%% ====================================================================
%% Auxiliar functions
%% ====================================================================


mytokens(Word) ->
  case Word of
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
