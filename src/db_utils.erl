%%%-------------------------------------------------------------------
%%% @author aku
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. Jun 2014 23:33
%%%-------------------------------------------------------------------
-module(db_utils).
-author("aku").


-include("records.hrl").
-compile([{parse_transform, lager_transform}]).

%% API
-export([install/2, get_row/2, update_row/3, add_row/3, get_table/1]).
-export([ets_create/2, ets_lookup/2, ets_insert/2]).

%Might be removed ->
-export([print_db/2]).

install(Nodes, Path)->

  %Set the directory to store the file for the data base
  %THIS IS IMPORTANT !!!!! NOT remove
  application:set_env(mnesia, dir, Path),

  mnesia:create_schema([Nodes]),
  %lager:info("[~p][install] Schmea created",[?MODULE]),

  application:start(mnesia).
  %lager:info("[~p][install] Mnesia started",[?MODULE]).



get_table(TableName)->
  %When create gets emptied
  lager:info("mnesia get table"),
  mnesia:create_table(TableName, [{attributes, record_info(fields, row)},
    {record_name,row},
    {ram_copies, [node()]}
  ]),

  lager:info("wait for table"),
  mnesia:wait_for_tables([TableName], infinity), {created, TableName}.
  %TODO: recover without filling
  %case exist_table(TableName, mnesia:system_info(tables)) of
  %  {false} ->    lager:info("[~p][get_table] Mnesia started",[?MODULE]),
  %              mnesia:create_table(TableName, [{attributes, record_info(fields, row)},
  %                                              {record_name,row},
  %                                              {ram_copies, [node()]}
  %                                             ]),
  %              mnesia:wait_for_tables([TableName], infinity),
  %              {created, TableName};
  %  {true} -> lager:info("[~p][get_table] [MN] table already exits ~p",[self(), TableName]),
  %            {exists, TableName};
  %  Reason -> lager:error("[~p][get_table] Unkown success => ~p",[self(), Reason]),
  %            {error, Reason}
  %end.

%exist_table(_Tbl,[])->
%  {false};
%exist_table(Tbl,[T|R])->
%  case T of
%    T when Tbl =:= T -> {true};
%    _ -> exist_table(Tbl,R)
%   end.



%% add_row/3
%% ====================================================================
%% @doc
-spec add_row(TbName :: atom(), Num :: term(), Instr :: term()) -> Result when
  Result :: term().
%% ====================================================================
add_row(TbName, Num, Instr)->
  %lager:info("[~p] Add row to ~p #~p int=~p",[self(),TbName,Num,Instr]),
  F = fun() ->
    mnesia:write(TbName,#row{num = Num,inst = Instr},write)
  end,
  mnesia:activity(ets, F).



get_row(TableName, RowNumber) ->
  [{_,_,Record}] = mnesia:dirty_match_object(TableName, #row{ num = RowNumber , inst = '_'}),
  Record.


update_row(TableName, CodeLine, NewContent)->

  F = fun()-> case mnesia:read(TableName, CodeLine, write) of
                [P] -> ok = mnesia:write(TableName, P#row{inst = NewContent}, write);
                _ -> mnesia:abort("No such person")
              end
      end,

  case mnesia:transaction(F) of
    {aborted, Reason} -> lager:info("aborted: ~p",[Reason]);
    {atomic, _ResultOfFun} -> ok
  end.


print_db(Tname, Ls)->
  lists:foreach(fun(Num) ->
    [{_,_,Record}] = mnesia:dirty_match_object(Tname,#row{num = Num, inst = '_'}),
    lager:warning("~p ~p",[Num, Record])
  end, Ls).


%% ================================================================================
%% Ets Methods
%% ================================================================================

ets_create(Name, Options) ->
    lager:info("creating ets"),
    ets:new(Name,Options).


ets_lookup(Mer, CName)->
  [{_,Line}] = ets:lookup(Mer,CName),
  Line.

ets_insert(TbName, Content) when is_tuple(Content) ->
  ets:insert(TbName, Content).
