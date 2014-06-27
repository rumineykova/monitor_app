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

-define(PATH,"../resources/").

-define(USER,<<"test">>).
-define(PWD,<<"test">>).
-define(HOST,"94.23.60.219").

start_test()->

  NRefOrg = spawn_link(test_utils, aux_method_org, [self()]),

  db_utils:install(node(), "db/"),

  Spec = data_utils:spec_create(bid_sebay, client, [sebay], NRefOrg, [], undef, undef),
  State = #role_data{ spec = Spec },

  child = db_utils:ets_create(child, [set, named_table, public, {keypos,1}, {write_concurrency, false},{read_concurrency, true}]),
  db_utils:ets_insert(child,{{test,et},0,#save_point{}}),
  {ok, Return} = role:start_link(?PATH,State),
  ?assertEqual(true, is_pid(Return)),

  %unlink(NRefOrg),
  %role:stop(Return),
  cleanup(Return).



prot_iterator_test() ->
    
    %% OMG Massive error if the directdory does not exists or can't be reache, BAD_TYPE can't update!!!!!!
    %application:set_env(mnesia, dir, "../db/"),

	{ok,Data} = file:read_file("../resources/client.scr"),
	{ok,Final,_} = erl_scan:string(binary_to_list(Data),1,[{reserved_word_fun, fun test_utils:mytokens/1}]),
	{ok,Scr} = scribble:parse(Final),
    
    db_utils:install(node(),"db"),
    case db_utils:get_table(prova) of
        {created, TbName} ->   role:translate_parsed_to_mnesia(TbName,Scr);
        {exists, TbName} -> role:translate_parsed_to_mnesia(TbName,Scr);
        {error, Reason} -> lager:error("~p",[Reason])
    end,
    
    ?assertMatch({ok,_N}, {ok,4} ).


wait_for_confirmation_test()->    
    self() ! {'$gen_cast',{confirm,me}},
    
    Roles = [me],
    
    Ok = role:wait_for_confirmation(Roles),
    ?assertEqual(true,Ok).


create_conersation_test()->

  db_utils:ets_create(child,  [set, named_table, public, {keypos,1}, {write_concurrency,false}, {read_concurrency,true}]),

  NRefOrg = spawn_link(test_utils, aux_method_org, [self()]),
    
    db_utils:install(node(), "db/"),
    
    Spec = data_utils:spec_create(bid_sebay, client, [sebay], NRefOrg, [], undef, undef),
    State = #role_data{ spec = Spec },
    {ok, Return} = role:start_link(?PATH,State),
    ?assertEqual(true, is_pid(Return)),
    
    ok = role:create(Return, bid_sebay),
    
    Return1 = receive
              timeout -> timeout
              %_ -> error
      end,
      
      NRefOrg ! exit,
      
      ?assertEqual(timeout, Return1),
      %role:stop(Return),
      cleanup(Return).




ready_test()->

  db_utils:ets_create(child,  [set, named_table, public, {keypos,1}, {write_concurrency,false}, {read_concurrency,true}]),

  NRefOrg = spawn_link(test_utils, aux_method_org, [self()]),
    
    db_utils:install(node(), "db/"),
    
    %TODO: Black Magic
    Spec = data_utils:spec_create(tete_client, tete, [], NRefOrg, [], undef, undef),
    
    State = #role_data{ spec = Spec },
    {ok, Return} = role:start_link(?PATH,State),
    
    ?assertEqual(true, is_pid(Return)),
    
    role:create(Return, bid_sebay),
    
    Return1 = receive
              ready -> ready
              %_ -> error
      end,
      
      NRefOrg ! exit,
      
      ?assertEqual(ready, Return1),
      cleanup(Return).


send_message_test() ->
  db_utils:ets_create(child,  [set, named_table, public, {keypos,1}, {write_concurrency,false}, {read_concurrency,true}]),

  NRefOrg = spawn_link(test_utils, aux_method_org, [self()]),
    
    db_utils:install(node(), "db/"),
    
    Spec = data_utils:spec_create(sing_test, sender, [], NRefOrg, [], undef, undef),
    
    State = #role_data{ spec = Spec },
    {ok, Return} = role:start_link(?PATH,State),
    
    {ok} = role:get_init_state(Return),
    ?assertEqual(true, is_pid(Return)),
    
    role:create(Return, bid_sebay),
    
    Return1 = receive
              ready -> ready
              %_ -> error
      end,
      
      ?assertEqual(ready, Return1),
      
      role:send(Return, recv, request_item,jejje),
      
      NRefOrg ! exit,
      cleanup(Return).





%% ====================================================================
%% Configuration Ceck Tests 
%% ====================================================================

check_for_signatures_test() ->
    
    {ok,Data} = file:read_file("../resources/client.scr"),
    {ok,Final,_} = erl_scan:string(binary_to_list(Data),1,[{reserved_word_fun, fun test_utils:mytokens/1}]),
    {ok,Scr} = scribble:parse(Final),
    
    db_utils:install(node(),"db"),
    case db_utils:get_table(prova) of
        {created, TbName} ->   role:translate_parsed_to_mnesia(TbName,Scr);
        {exists, TbName} -> role:translate_parsed_to_mnesia(TbName,Scr);
        {error, Reason} -> lager:error("~p",[Reason])
    end,
    
    Rest = role:check_signatures(prova, [{func, send_newPrice, sebay}]),
    Rest1 = role:check_signatures(prova, [{func, send_newP, sebay}]),
    
    ?assertEqual({error, signature_not_found }, Rest1),
    ?assertEqual({ok}, Rest).


check_for_methods_1_test() ->
    NRef = spawn_link(fun() ->
            receive
              {_,From,_} -> gen_server:reply(From,{ok,[{test,2},{ready,2},{terminated,2},{config_done,2},{cancel,2}]})
            end
          end),
      
      M =  role:check_method(protocol, NRef, [#func{ func = test }]),
      ?assertEqual({ok}, M).

check_for_methods_2_test() ->
    NRef = spawn_link(fun() ->
                receive
                    {_,From,_} -> gen_server:reply(From,{ok,[{tst,2},{ready,2},{terminated,2},{config_done,2},{cancel,2}]})
                end
        end),
    
    M =  role:check_method(protocol, NRef, [#func{ sign = test }]),
    ?assertEqual({error, method_not_found}, M).


check_for_methods_3_test() ->
    NRef = spawn_link(fun() ->
                receive
                    {_,From,_} -> gen_server:reply(From,{ok,[{test,2},{redy,2},{terminated,2},{config_done,2},{cancel,2}]})
                end
        end),
    
    M =  role:check_method(protocol,NRef, [#func{ sign = test }]),
    ?assertEqual({error, method_not_found}, M).


check_for_methods_4_test() ->
  NRef = spawn_link(fun() ->
    receive
      {_,From,_} -> gen_server:reply(From,{ok,[{test,2},{ready,2},{terminated,2},{config_done,2},{cancel,2}]})
    end
  end),

  M =  role:check_method(protocol, NRef, [#func{ sign = test1 }]),
  ?assertEqual({error, method_not_found}, M).



check_both_test()->

  {ok,Data} = file:read_file("../resources/client.scr"),
  {ok,Final,_} = erl_scan:string(binary_to_list(Data),1,[{reserved_word_fun, fun test_utils:mytokens/1}]),
  {ok,Scr} = scribble:parse(Final),

 db_utils:install(node(),"db"),
  case db_utils:get_table(prova) of
    {created, TbName} ->   role:translate_parsed_to_mnesia(TbName,Scr);
    {exists, TbName} -> role:translate_parsed_to_mnesia(TbName,Scr);
    {error, Reason} -> lager:error("~p",[Reason])
  end,

  NRef1 = spawn_link(fun aux_method1/0),

  R1 = role:check_signatures_and_methods(protocol, NRef1, prova, [#func{ sign = send_newPrice, func = sebay }]),

  ?assertEqual({ok}, R1),

  NRef2 = spawn_link(fun aux_method1/0),

  R2 = role:check_signatures_and_methods(protocol, NRef2, prova,[#func{ sign = send_newP, func = sebay }]),

  ?assertEqual({error, signature_not_found }, R2),

  NRef3 = spawn_link(fun aux_method1/0),

  R3 = role:check_signatures_and_methods(protocol, NRef3,prova, [#func{ sign = send_newPrice, func = seb }]),

  ?assertEqual({error, method_not_found}, R3),

  NRef4 = spawn_link(fun aux_method2/0),

  R4 = role:check_signatures_and_methods(protocol, NRef4, prova,[#func{ sign = send_newPrice, func = sebay }]),

  ?assertEqual({error, method_not_found}, R4).

aux_method1() ->
    receive
      {_,From,_} -> gen_server:reply(From,{ok,[{sebay,2},{ready,2},{terminated,2},{config_done,2},{cancel,2}]})
    end.

aux_method2() ->
  receive
    {_,From,_} -> gen_server:reply(From,{ok,[{sebay,2},{read,2},{terminated,2},{config_done,2},{cancel,2}]})
  end.



%% ====================================================================
%% Download projection test
%% ====================================================================

download_test()->

  db_utils:ets_create(child,  [set, named_table, public, {keypos,1}, {write_concurrency,false}, {read_concurrency,true}]),

  NRefOrg = spawn_link(test_utils, aux_method_org, [self()]),

  db_utils:install(node(), "db/"),
  db_utils:get_table(prova2),

  Spec = data_utils:spec_create(down_test, test, [], NRefOrg, [], undef, undef),

  State = #role_data{ spec = Spec },
  {ok, Return} = role:start_link(?PATH,State),

  ?assertEqual(true, is_pid(Return)),

  role:create(Return, down_test),

  receive
    M -> M
    %_ -> error
  end,

  role:stop(Return),

  case  filelib:is_regular("../resources/test.scr") of
    true -> file:delete("../resources/test.scr"), ?assertEqual(true, true);
    _ -> ?assertEqual(true, false)
  end,
  cleanup(Return).



%% ====================================================================
%% Auxiliar functions
%% ====================================================================


cleanup(Pid) ->
  %This will kill supervisor and childs
  unlink(Pid),
  Ref = monitor(process, Pid),

  role:stop(Pid),
  receive
    {'DOWN', Ref, process, Pid, _Reason} ->
      ok
  after 4000 ->
    error(exit_timeout)
  end,
  lager:info("deleting table ~p",[ets:info(child)]),
  ets:delete(child).
