%%%-------------------------------------------------------------------
%%% @author aku
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 20. Jun 2014 00:45
%%%-------------------------------------------------------------------
-module(db_utils_test).
-author("aku").

-include_lib("eunit/include/eunit.hrl").

-compile([{parse_transform, lager_transform}]).

%% ====================================================================
%% MNesia functions
%% ====================================================================

db_usage_test()->
  {ok,Data} = file:read_file("../test/test_resources/client.scr"),
  {ok,Final,_} = erl_scan:string(binary_to_list(Data),1,[{reserved_word_fun, fun mytokens/1}]),
  {ok,Scr} = scribble:parse(Final),

  db_utils:install(node(),"db"),

  {created, TblName} = db_utils:get_table(test_table),

  role:translate_parsed_to_mnesia(TblName,Scr),

  %db_utils:print_db(TblName,[0]),

  Insts = [{to,request_item,sebay},
    {from,response_item,sebay},
    {choice,client,[{'or',3},{'or',13}]},
    {to,makebid,sebay},
    {to,send_newPrice,sebay},
    {choice,sebay,[{'or',6},{'or',9}]},
    {from,lower,sebay},
    {continue,1},
    {continue,12},
    {from,accept,sebay},
    {from,send_update,sebay},
    {continue,12},
    {continue,15},
    {to,nobid,sebay},
    {continue,15}],
  RowLines = lists:seq(0, 100),

  Rows = gen_list(Insts, RowLines,[]),
  lists:foreach( fun({Num,Row}) ->
                            Record = db_utils:get_row(TblName, Num),
                            ?assertEqual(Row, Record) end,Rows).



db_update_test()->
  db_utils:install(node(),"db"),

  {created, TblName} = db_utils:get_table(test_table),

  db_utils:add_row(TblName, 0,{this_is_sparta}),

  ?assertEqual({this_is_sparta},db_utils:get_row(TblName, 0)).



%% ====================================================================
%% ETS functions
%% ====================================================================


ets_test()->

  db_utils:install(node(),"db"),

  Name = db_utils:ets_create(aux, [set]),

  db_utils:ets_insert(Name, {kk, bond}),

  ?assertEqual(bond, db_utils:ets_lookup(Name, kk)).

ets_child_test()->

  db_utils:install(node(),"db"),

  db_utils:ets_create(child,  [set, named_table, public, {keypos,1}, {write_concurrency,false}, {read_concurrency,true}]),

  db_utils:ets_insert(child, {{p1,c1} , '<0.549.0>'}),

  ?assertEqual( '<0.549.0>', db_utils:ets_lookup(child, {p1,c1} )).




%% ====================================================================
%% Auxiliar functions
%% ====================================================================

gen_list([],_, Acc)->  Acc;
gen_list([I | Inst], [L | Lines], Acc)->
  gen_list(Inst, Lines, [ {L, I} | Acc ]).



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
