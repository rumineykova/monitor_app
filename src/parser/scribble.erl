-module(scribble).
-export([parse/1, parse_and_scan/1, format_error/1]).

-file("/usr/local/Cellar/erlang/R16B03-1/lib/erlang/lib/parsetools-2.0.10/include/yeccpre.hrl", 0).
%%
%% %CopyrightBegin%
%%
%% Copyright Ericsson AB 1996-2013. All Rights Reserved.
%%
%% The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved online at http://www.erlang.org/.
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%%
%% %CopyrightEnd%
%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% The parser generator will insert appropriate declarations before this line.%

-type yecc_ret() :: {'error', _} | {'ok', _}.

-spec parse(Tokens :: list()) -> yecc_ret().
parse(Tokens) ->
    yeccpars0(Tokens, {no_func, no_line}, 0, [], []).

-spec parse_and_scan({function() | {atom(), atom()}, [_]}
                     | {atom(), atom(), [_]}) -> yecc_ret().
parse_and_scan({F, A}) ->
    yeccpars0([], {{F, A}, no_line}, 0, [], []);
parse_and_scan({M, F, A}) ->
    Arity = length(A),
    yeccpars0([], {{fun M:F/Arity, A}, no_line}, 0, [], []).

-spec format_error(any()) -> [char() | list()].
format_error(Message) ->
    case io_lib:deep_char_list(Message) of
        true ->
            Message;
        _ ->
            io_lib:write(Message)
    end.

%% To be used in grammar files to throw an error message to the parser
%% toplevel. Doesn't have to be exported!
-compile({nowarn_unused_function, return_error/2}).
-spec return_error(integer(), any()) -> no_return().
return_error(Line, Message) ->
    throw({error, {Line, ?MODULE, Message}}).

-define(CODE_VERSION, "1.4").

yeccpars0(Tokens, Tzr, State, States, Vstack) ->
    try yeccpars1(Tokens, Tzr, State, States, Vstack)
    catch 
        error: Error ->
            Stacktrace = erlang:get_stacktrace(),
            try yecc_error_type(Error, Stacktrace) of
                Desc ->
                    erlang:raise(error, {yecc_bug, ?CODE_VERSION, Desc},
                                 Stacktrace)
            catch _:_ -> erlang:raise(error, Error, Stacktrace)
            end;
        %% Probably thrown from return_error/2:
        throw: {error, {_Line, ?MODULE, _M}} = Error ->
            Error
    end.

yecc_error_type(function_clause, [{?MODULE,F,ArityOrArgs,_} | _]) ->
    case atom_to_list(F) of
        "yeccgoto_" ++ SymbolL ->
            {ok,[{atom,_,Symbol}],_} = erl_scan:string(SymbolL),
            State = case ArityOrArgs of
                        [S,_,_,_,_,_,_] -> S;
                        _ -> state_is_unknown
                    end,
            {Symbol, State, missing_in_goto_table}
    end.

yeccpars1([Token | Tokens], Tzr, State, States, Vstack) ->
    yeccpars2(State, element(1, Token), States, Vstack, Token, Tokens, Tzr);
yeccpars1([], {{F, A},_Line}, State, States, Vstack) ->
    case apply(F, A) of
        {ok, Tokens, Endline} ->
            yeccpars1(Tokens, {{F, A}, Endline}, State, States, Vstack);
        {eof, Endline} ->
            yeccpars1([], {no_func, Endline}, State, States, Vstack);
        {error, Descriptor, _Endline} ->
            {error, Descriptor}
    end;
yeccpars1([], {no_func, no_line}, State, States, Vstack) ->
    Line = 999999,
    yeccpars2(State, '$end', States, Vstack, yecc_end(Line), [],
              {no_func, Line});
yeccpars1([], {no_func, Endline}, State, States, Vstack) ->
    yeccpars2(State, '$end', States, Vstack, yecc_end(Endline), [],
              {no_func, Endline}).

%% yeccpars1/7 is called from generated code.
%%
%% When using the {includefile, Includefile} option, make sure that
%% yeccpars1/7 can be found by parsing the file without following
%% include directives. yecc will otherwise assume that an old
%% yeccpre.hrl is included (one which defines yeccpars1/5).
yeccpars1(State1, State, States, Vstack, Token0, [Token | Tokens], Tzr) ->
    yeccpars2(State, element(1, Token), [State1 | States],
              [Token0 | Vstack], Token, Tokens, Tzr);
yeccpars1(State1, State, States, Vstack, Token0, [], {{_F,_A}, _Line}=Tzr) ->
    yeccpars1([], Tzr, State, [State1 | States], [Token0 | Vstack]);
yeccpars1(State1, State, States, Vstack, Token0, [], {no_func, no_line}) ->
    Line = yecctoken_end_location(Token0),
    yeccpars2(State, '$end', [State1 | States], [Token0 | Vstack],
              yecc_end(Line), [], {no_func, Line});
yeccpars1(State1, State, States, Vstack, Token0, [], {no_func, Line}) ->
    yeccpars2(State, '$end', [State1 | States], [Token0 | Vstack],
              yecc_end(Line), [], {no_func, Line}).

%% For internal use only.
yecc_end({Line,_Column}) ->
    {'$end', Line};
yecc_end(Line) ->
    {'$end', Line}.

yecctoken_end_location(Token) ->
    try
        {text, Str} = erl_scan:token_info(Token, text),
        {line, Line} = erl_scan:token_info(Token, line),
        Parts = re:split(Str, "\n"),
        Dline = length(Parts) - 1,
        Yline = Line + Dline,
        case erl_scan:token_info(Token, column) of
            {column, Column} ->
                Col = byte_size(lists:last(Parts)),
                {Yline, Col + if Dline =:= 0 -> Column; true -> 1 end};
            undefined ->
                Yline
        end
    catch _:_ ->
        yecctoken_location(Token)
    end.

-compile({nowarn_unused_function, yeccerror/1}).
yeccerror(Token) ->
    Text = yecctoken_to_string(Token),
    Location = yecctoken_location(Token),
    {error, {Location, ?MODULE, ["syntax error before: ", Text]}}.

-compile({nowarn_unused_function, yecctoken_to_string/1}).
yecctoken_to_string(Token) ->
    case catch erl_scan:token_info(Token, text) of
        {text, Txt} -> Txt;
        _ -> yecctoken2string(Token)
    end.

yecctoken_location(Token) ->
    case catch erl_scan:token_info(Token, location) of
        {location, Loc} -> Loc;
        _ -> element(2, Token)
    end.

-compile({nowarn_unused_function, yecctoken2string/1}).
yecctoken2string({atom, _, A}) -> io_lib:write(A);
yecctoken2string({integer,_,N}) -> io_lib:write(N);
yecctoken2string({float,_,F}) -> io_lib:write(F);
yecctoken2string({char,_,C}) -> io_lib:write_char(C);
yecctoken2string({var,_,V}) -> io_lib:format("~s", [V]);
yecctoken2string({string,_,S}) -> io_lib:write_string(S);
yecctoken2string({reserved_symbol, _, A}) -> io_lib:write(A);
yecctoken2string({_Cat, _, Val}) -> io_lib:format("~p",[Val]);
yecctoken2string({dot, _}) -> "'.'";
yecctoken2string({'$end', _}) ->
    [];
yecctoken2string({Other, _}) when is_atom(Other) ->
    io_lib:write(Other);
yecctoken2string(Other) ->
    io_lib:write(Other).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



-file("src/parser/scribble.erl", 188).

yeccpars2(0=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_0(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(1=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_1(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(2=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_2(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(3=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_3(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(4=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(5=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_5(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(6=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_6(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(7=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_3(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(8=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_8(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(9=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_9(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(10=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_10(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(11=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_11(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(12=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_12(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(13=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_13(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(14=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_14(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(15=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_15(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(16=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_3(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(17=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_3(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(18=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_18(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(19=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_19(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(20=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_3(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(21=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_21(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(22=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_22(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(23=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_23(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(24=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_24(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(25=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_25(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(26=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_3(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(27=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_27(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(28=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_28(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(29=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_3(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(30=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_30(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(31=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_31(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(32=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_32(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(33=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_33(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(34=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_34(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(35=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_35(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(36=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_31(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(37=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_37(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(38=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_34(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(39=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_39(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(40=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_40(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(41=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_41(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(42=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_42(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(43=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_43(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(44=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_44(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(45=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_45(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(46=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_46(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(47=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_47(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(48=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_48(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(49=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_49(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(50=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_50(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(51=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_51(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(52=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_52(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(53=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_53(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(54=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_54(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(55=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_55(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(56=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_3(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(57=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_40(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(58=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_3(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(59=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_40(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(60=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_60(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(61=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_61(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(62=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_62(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(63=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_40(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(64=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_64(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(65=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_65(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(66=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_66(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(67=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_67(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(68=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_31(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(69=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_40(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(70=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_70(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(71=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_71(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(72=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_40(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(73=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_73(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(74=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_74(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(75=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_75(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(76=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_76(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(77=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_77(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(78=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_78(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(79=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_79(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(80=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_80(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(81=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_81(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(82=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_31(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(83=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_31(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(84=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_84(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(85=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_85(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(86=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_86(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(87=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_87(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(88=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_88(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(89=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_89(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(90=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_90(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(91=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_3(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(92=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_92(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(93=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_93(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(94=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_3(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(95=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_95(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(96=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_96(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(97=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_97(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(98=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_98(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(99=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_11(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(100=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_100(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(101=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_101(S, Cat, Ss, Stack, T, Ts, Tzr);
%% yeccpars2(102=S, Cat, Ss, Stack, T, Ts, Tzr) ->
%%  yeccpars2_102(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(Other, _, _, _, _, _, _) ->
 erlang:error({yecc_bug,"1.4",{missing_state_in_action_table, Other}}).

yeccpars2_0(S, module, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 3, Ss, Stack, T, Ts, Tzr);
yeccpars2_0(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_1(S, from, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_1(S, import, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_1(S, local, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_1(S, type, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_1(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_2(_S, '$end', _Ss, Stack, _T, _Ts, _Tzr) ->
 {ok, hd(Stack)};
yeccpars2_2(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_3(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 6, Ss, Stack, T, Ts, Tzr);
yeccpars2_3(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_4(S, ';', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_5(S, '.', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 7, Ss, Stack, T, Ts, Tzr);
yeccpars2_5(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_5_(Stack),
 yeccgoto_package_name(hd(Ss), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_6(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccgoto_identifier(hd(Ss), Cat, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_7: see yeccpars2_3

yeccpars2_8(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_|Nss] = Ss,
 NewStack = yeccpars2_8_(Stack),
 yeccgoto_package_name(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_9(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_|Nss] = Ss,
 NewStack = yeccpars2_9_(Stack),
 yeccgoto_package_decl(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_10(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_|Nss] = Ss,
 NewStack = yeccpars2_10_(Stack),
 yeccgoto_module_imp(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_11(S, local, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_11(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_12(S, type, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_12(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_12_(Stack),
 yeccgoto_payload_type_decl_iterator(hd(Ss), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_13(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccgoto_protocol_decl(hd(Ss), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_14(S, local, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_14(S, type, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_14(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_15(S, from, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_15(S, import, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_15(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_15_(Stack),
 yeccgoto_import_decl_iterator(hd(Ss), Cat, Ss, NewStack, T, Ts, Tzr).

%% yeccpars2_16: see yeccpars2_3

%% yeccpars2_17: see yeccpars2_3

yeccpars2_18(S, protocol, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_18(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_19(S, '<', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_19(_, _, _, _, T, _, _) ->
 yeccerror(T).

%% yeccpars2_20: see yeccpars2_3

yeccpars2_21(S, '>', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_21(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_22(S, string, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_22(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_23(S, from, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_23(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_24(S, string, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_24(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_25(S, as, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_25(_, _, _, _, T, _, _) ->
 yeccerror(T).

%% yeccpars2_26: see yeccpars2_3

yeccpars2_27(S, ';', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_27(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_28(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_,_,_,_,_,_,_,_|Nss] = Ss,
 NewStack = yeccpars2_28_(Stack),
 yeccgoto_payload_type_decl(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_29: see yeccpars2_3

yeccpars2_30(S, at, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_30(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_31(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_31(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_32(S, '(', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_32(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_33(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccgoto_role_name(hd(Ss), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_34(S, role, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_34(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_35(S, ')', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_35(_, _, _, _, T, _, _) ->
 yeccerror(T).

%% yeccpars2_36: see yeccpars2_31

yeccpars2_37(S, ',', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_37(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_|Nss] = Ss,
 NewStack = yeccpars2_37_(Stack),
 yeccgoto_role_list(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_38: see yeccpars2_34

yeccpars2_39(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_,_|Nss] = Ss,
 NewStack = yeccpars2_39_(Stack),
 yeccgoto_role_list(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_40(S, '{', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_40(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_41(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_,_,_,_,_,_,_|Nss] = Ss,
 NewStack = yeccpars2_41_(Stack),
 yeccgoto_local_protocol_decl(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_42(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccgoto_local_protocol_body(hd(Ss), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_43(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_43(S, choice, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_43(S, continue, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_43(S, par, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_43(S, rec, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_43(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_44(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_44_(Stack),
 yeccgoto_local_interaction(hd(Ss), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_45(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_45_(Stack),
 yeccgoto_local_interaction(hd(Ss), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_46(S, from, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_46(S, to, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_46(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_47(S, '(', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_47(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_48(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_48_(Stack),
 yeccgoto_local_interaction(hd(Ss), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_49(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_49_(Stack),
 yeccgoto_local_interaction(hd(Ss), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_50(S, '}', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_50(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_51(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_51(S, choice, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_51(S, continue, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_51(S, par, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_51(S, rec, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_51(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccgoto_local_interaction_sequence(hd(Ss), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_52(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_52_(Stack),
 yeccgoto_local_interaction(hd(Ss), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_53(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_53_(Stack),
 yeccgoto_local_interaction(hd(Ss), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_54(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccgoto_message_operator(hd(Ss), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_55(S, at, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_55(_, _, _, _, T, _, _) ->
 yeccerror(T).

%% yeccpars2_56: see yeccpars2_3

%% yeccpars2_57: see yeccpars2_40

%% yeccpars2_58: see yeccpars2_3

%% yeccpars2_59: see yeccpars2_40

yeccpars2_60(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_|Nss] = Ss,
 NewStack = yeccpars2_60_(Stack),
 yeccgoto_local_recursion(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_61(S, 'and', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_61(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_|Nss] = Ss,
 NewStack = yeccpars2_61_(Stack),
 yeccgoto_local_parallel(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_62(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_|Nss] = Ss,
 NewStack = yeccpars2_62_(Stack),
 yeccgoto_local_parallel(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_63: see yeccpars2_40

yeccpars2_64(S, 'and', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_64(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_|Nss] = Ss,
 NewStack = yeccpars2_64_(Stack),
 yeccgoto_local_parallel_cont(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_65(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_|Nss] = Ss,
 NewStack = yeccpars2_65_(Stack),
 yeccgoto_local_parallel_cont(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_66(S, ';', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_66(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_67(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_|Nss] = Ss,
 NewStack = yeccpars2_67_(Stack),
 yeccgoto_local_continue(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_68: see yeccpars2_31

%% yeccpars2_69: see yeccpars2_40

yeccpars2_70(S, 'or', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_70(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_,_|Nss] = Ss,
 NewStack = yeccpars2_70_(Stack),
 yeccgoto_local_choice(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_71(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_,_,_|Nss] = Ss,
 NewStack = yeccpars2_71_(Stack),
 yeccgoto_local_choice(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_72: see yeccpars2_40

yeccpars2_73(S, 'or', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_73(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_|Nss] = Ss,
 NewStack = yeccpars2_73_(Stack),
 yeccgoto_local_choice_cont(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_74(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_|Nss] = Ss,
 NewStack = yeccpars2_74_(Stack),
 yeccgoto_local_choice_cont(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_75(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_|Nss] = Ss,
 NewStack = yeccpars2_75_(Stack),
 yeccgoto_local_interaction_sequence(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_76(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_|Nss] = Ss,
 NewStack = yeccpars2_76_(Stack),
 yeccgoto_local_interaction_block(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_77(S, ')', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_77(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_77(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_78(S, ')', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_78(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_79(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_|Nss] = Ss,
 NewStack = yeccpars2_79_(Stack),
 yeccgoto_message_signature(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_80(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccgoto_payload_type(hd(Ss), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_81(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_,_|Nss] = Ss,
 NewStack = yeccpars2_81_(Stack),
 yeccgoto_message_signature(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_82: see yeccpars2_31

%% yeccpars2_83: see yeccpars2_31

yeccpars2_84(S, ';', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_84(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_85(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_,_|Nss] = Ss,
 NewStack = yeccpars2_85_(Stack),
 yeccgoto_to_send(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_86(S, ';', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_86(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_87(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_,_|Nss] = Ss,
 NewStack = yeccpars2_87_(Stack),
 yeccgoto_to_receive(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_88(S, ';', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_88(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_89(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_|Nss] = Ss,
 NewStack = yeccpars2_89_(Stack),
 yeccgoto_import_decl(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_90(S, import, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_90(_, _, _, _, T, _, _) ->
 yeccerror(T).

%% yeccpars2_91: see yeccpars2_3

yeccpars2_92(S, ';', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_92(S, as, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_92(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_93(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_,_,_|Nss] = Ss,
 NewStack = yeccpars2_93_(Stack),
 yeccgoto_import_decl(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_94: see yeccpars2_3

yeccpars2_95(S, ';', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_95(_, _, _, _, T, _, _) ->
 yeccerror(T).

yeccpars2_96(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_,_,_,_,_|Nss] = Ss,
 NewStack = yeccpars2_96_(Stack),
 yeccgoto_import_decl(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_97(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_|Nss] = Ss,
 NewStack = yeccpars2_97_(Stack),
 yeccgoto_import_decl_iterator(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_98(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_|Nss] = Ss,
 NewStack = yeccpars2_98_(Stack),
 yeccgoto_module_imp(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_99: see yeccpars2_11

yeccpars2_100(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_,_|Nss] = Ss,
 NewStack = yeccpars2_100_(Stack),
 yeccgoto_module_imp(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_101(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_|Nss] = Ss,
 NewStack = yeccpars2_101_(Stack),
 yeccgoto_payload_type_decl_iterator(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_102(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 [_,_|Nss] = Ss,
 NewStack = yeccpars2_102_(Stack),
 yeccgoto_module_imp(hd(Nss), Cat, Nss, NewStack, T, Ts, Tzr).

yeccgoto_identifier(3, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_5(5, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_identifier(7=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_8(_S, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_identifier(16, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_5(5, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_identifier(17, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_5(5, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_identifier(20, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_21(21, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_identifier(26, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_27(27, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_identifier(29, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_30(30, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_identifier(56, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_66(66, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_identifier(58, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_40(59, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_identifier(91, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_92(92, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_identifier(94, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_95(95, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_import_decl(1, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_15(15, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_import_decl(15, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_15(15, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_import_decl_iterator(1, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_14(14, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_import_decl_iterator(15=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_97(_S, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_local_choice(43=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_53(_S, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_local_choice(51=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_53(_S, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_local_choice_cont(70=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_71(_S, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_local_choice_cont(73=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_74(_S, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_local_continue(43=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_52(_S, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_local_continue(51=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_52(_S, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_local_interaction(43, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_51(51, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_local_interaction(51, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_51(51, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_local_interaction_block(40=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_42(_S, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_local_interaction_block(57, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_61(61, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_local_interaction_block(59=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_60(_S, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_local_interaction_block(63, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_64(64, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_local_interaction_block(69, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_70(70, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_local_interaction_block(72, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_73(73, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_local_interaction_sequence(43, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_50(50, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_local_interaction_sequence(51=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_75(_S, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_local_parallel(43=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_49(_S, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_local_parallel(51=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_49(_S, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_local_parallel_cont(61=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_62(_S, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_local_parallel_cont(64=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_65(_S, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_local_protocol_body(40=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_41(_S, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_local_protocol_decl(1=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_13(_S, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_local_protocol_decl(11=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_13(_S, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_local_protocol_decl(14=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_13(_S, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_local_protocol_decl(99=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_13(_S, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_local_recursion(43=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_48(_S, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_local_recursion(51=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_48(_S, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_message_operator(43, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_47(47, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_message_operator(51, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_47(47, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_message_signature(43, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_46(46, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_message_signature(51, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_46(46, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_module_imp(0, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_2(2, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_package_decl(0, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_1(1, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_package_name(3, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(4, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_package_name(16, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_90(90, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_package_name(17, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_88(88, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_payload_type(77, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_78(78, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_payload_type_decl(1, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_12(12, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_payload_type_decl(12, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_12(12, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_payload_type_decl(14, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_12(12, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_payload_type_decl_iterator(1, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_11(11, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_payload_type_decl_iterator(12=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_101(_S, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_payload_type_decl_iterator(14, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_11(99, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_protocol_decl(1=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_10(_S, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_protocol_decl(11=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_102(_S, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_protocol_decl(14=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_98(_S, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_protocol_decl(99=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_100(_S, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_role_list(34, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_35(35, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_role_list(38=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_39(_S, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_role_name(31, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_32(32, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_role_name(36, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_37(37, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_role_name(68, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_40(69, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_role_name(82, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_86(86, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_role_name(83, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_84(84, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_to_receive(43=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_45(_S, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_to_receive(51=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_45(_S, Cat, Ss, Stack, T, Ts, Tzr).

yeccgoto_to_send(43=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_44(_S, Cat, Ss, Stack, T, Ts, Tzr);
yeccgoto_to_send(51=_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_44(_S, Cat, Ss, Stack, T, Ts, Tzr).

-compile({inline,yeccpars2_5_/1}).
-file("src/parser/scribble.yrl", 0).
yeccpars2_5_(__Stack0) ->
 [__1 | __Stack] = __Stack0,
 [begin
   '$undefined'
  end | __Stack].

-compile({inline,yeccpars2_8_/1}).
-file("src/parser/scribble.yrl", 0).
yeccpars2_8_(__Stack0) ->
 [__3,__2,__1 | __Stack] = __Stack0,
 [begin
   '$undefined'
  end | __Stack].

-compile({inline,yeccpars2_9_/1}).
-file("src/parser/scribble.yrl", 0).
yeccpars2_9_(__Stack0) ->
 [__3,__2,__1 | __Stack] = __Stack0,
 [begin
   '$undefined'
  end | __Stack].

-compile({inline,yeccpars2_10_/1}).
-file("src/parser/scribble.yrl", 33).
yeccpars2_10_(__Stack0) ->
 [__2,__1 | __Stack] = __Stack0,
 [begin
   __2
  end | __Stack].

-compile({inline,yeccpars2_12_/1}).
-file("src/parser/scribble.yrl", 0).
yeccpars2_12_(__Stack0) ->
 [__1 | __Stack] = __Stack0,
 [begin
   '$undefined'
  end | __Stack].

-compile({inline,yeccpars2_15_/1}).
-file("src/parser/scribble.yrl", 0).
yeccpars2_15_(__Stack0) ->
 [__1 | __Stack] = __Stack0,
 [begin
   '$undefined'
  end | __Stack].

-compile({inline,yeccpars2_28_/1}).
-file("src/parser/scribble.yrl", 0).
yeccpars2_28_(__Stack0) ->
 [__10,__9,__8,__7,__6,__5,__4,__3,__2,__1 | __Stack] = __Stack0,
 [begin
   '$undefined'
  end | __Stack].

-compile({inline,yeccpars2_37_/1}).
-file("src/parser/scribble.yrl", 61).
yeccpars2_37_(__Stack0) ->
 [__2,__1 | __Stack] = __Stack0,
 [begin
   __2
  end | __Stack].

-compile({inline,yeccpars2_39_/1}).
-file("src/parser/scribble.yrl", 60).
yeccpars2_39_(__Stack0) ->
 [__4,__3,__2,__1 | __Stack] = __Stack0,
 [begin
   [ __2 ] ++ __4
  end | __Stack].

-compile({inline,yeccpars2_41_/1}).
-file("src/parser/scribble.yrl", 57).
yeccpars2_41_(__Stack0) ->
 [__9,__8,__7,__6,__5,__4,__3,__2,__1 | __Stack] = __Stack0,
 [begin
   { protocol , __3 , __5 , __7 , __9 }
  end | __Stack].

-compile({inline,yeccpars2_44_/1}).
-file("src/parser/scribble.yrl", 71).
yeccpars2_44_(__Stack0) ->
 [__1 | __Stack] = __Stack0,
 [begin
   [ __1 ]
  end | __Stack].

-compile({inline,yeccpars2_45_/1}).
-file("src/parser/scribble.yrl", 72).
yeccpars2_45_(__Stack0) ->
 [__1 | __Stack] = __Stack0,
 [begin
   [ __1 ]
  end | __Stack].

-compile({inline,yeccpars2_48_/1}).
-file("src/parser/scribble.yrl", 75).
yeccpars2_48_(__Stack0) ->
 [__1 | __Stack] = __Stack0,
 [begin
   [ __1 ]
  end | __Stack].

-compile({inline,yeccpars2_49_/1}).
-file("src/parser/scribble.yrl", 74).
yeccpars2_49_(__Stack0) ->
 [__1 | __Stack] = __Stack0,
 [begin
   [ __1 ]
  end | __Stack].

-compile({inline,yeccpars2_52_/1}).
-file("src/parser/scribble.yrl", 76).
yeccpars2_52_(__Stack0) ->
 [__1 | __Stack] = __Stack0,
 [begin
   [ __1 ]
  end | __Stack].

-compile({inline,yeccpars2_53_/1}).
-file("src/parser/scribble.yrl", 73).
yeccpars2_53_(__Stack0) ->
 [__1 | __Stack] = __Stack0,
 [begin
   [ __1 , [ { erec , none } ] ]
  end | __Stack].

-compile({inline,yeccpars2_60_/1}).
-file("src/parser/scribble.yrl", 102).
yeccpars2_60_(__Stack0) ->
 [__3,__2,__1 | __Stack] = __Stack0,
 [begin
   { rec , __2 , [ __3 ] }
  end | __Stack].

-compile({inline,yeccpars2_61_/1}).
-file("src/parser/scribble.yrl", 97).
yeccpars2_61_(__Stack0) ->
 [__2,__1 | __Stack] = __Stack0,
 [begin
   { par , [ __2 ] }
  end | __Stack].

-compile({inline,yeccpars2_62_/1}).
-file("src/parser/scribble.yrl", 96).
yeccpars2_62_(__Stack0) ->
 [__3,__2,__1 | __Stack] = __Stack0,
 [begin
   { par , [ __2 , __3 ] }
  end | __Stack].

-compile({inline,yeccpars2_64_/1}).
-file("src/parser/scribble.yrl", 99).
yeccpars2_64_(__Stack0) ->
 [__2,__1 | __Stack] = __Stack0,
 [begin
   [ { 'and' , __2 } ]
  end | __Stack].

-compile({inline,yeccpars2_65_/1}).
-file("src/parser/scribble.yrl", 98).
yeccpars2_65_(__Stack0) ->
 [__3,__2,__1 | __Stack] = __Stack0,
 [begin
   [ { 'and' , __2 } ] ++ __3
  end | __Stack].

-compile({inline,yeccpars2_67_/1}).
-file("src/parser/scribble.yrl", 104).
yeccpars2_67_(__Stack0) ->
 [__3,__2,__1 | __Stack] = __Stack0,
 [begin
   { continue , __2 }
  end | __Stack].

-compile({inline,yeccpars2_70_/1}).
-file("src/parser/scribble.yrl", 91).
yeccpars2_70_(__Stack0) ->
 [__4,__3,__2,__1 | __Stack] = __Stack0,
 [begin
   { choice , __3 , [ __4 , [ { econtinue , none } ] ] }
  end | __Stack].

-compile({inline,yeccpars2_71_/1}).
-file("src/parser/scribble.yrl", 90).
yeccpars2_71_(__Stack0) ->
 [__5,__4,__3,__2,__1 | __Stack] = __Stack0,
 [begin
   { choice , __3 , [ __4 ++ [ { econtinue , none } ] , __5 ] }
  end | __Stack].

-compile({inline,yeccpars2_73_/1}).
-file("src/parser/scribble.yrl", 93).
yeccpars2_73_(__Stack0) ->
 [__2,__1 | __Stack] = __Stack0,
 [begin
   [ { 'or' , __2 ++ [ { econtinue , none } ] } ]
  end | __Stack].

-compile({inline,yeccpars2_74_/1}).
-file("src/parser/scribble.yrl", 92).
yeccpars2_74_(__Stack0) ->
 [__3,__2,__1 | __Stack] = __Stack0,
 [begin
   [ { 'or' , __2 ++ [ { econtinue , none } ] } ] ++ __3
  end | __Stack].

-compile({inline,yeccpars2_75_/1}).
-file("src/parser/scribble.yrl", 69).
yeccpars2_75_(__Stack0) ->
 [__2,__1 | __Stack] = __Stack0,
 [begin
   __1 ++ __2
  end | __Stack].

-compile({inline,yeccpars2_76_/1}).
-file("src/parser/scribble.yrl", 66).
yeccpars2_76_(__Stack0) ->
 [__3,__2,__1 | __Stack] = __Stack0,
 [begin
   __2
  end | __Stack].

-compile({inline,yeccpars2_79_/1}).
-file("src/parser/scribble.yrl", 84).
yeccpars2_79_(__Stack0) ->
 [__3,__2,__1 | __Stack] = __Stack0,
 [begin
   __1
  end | __Stack].

-compile({inline,yeccpars2_81_/1}).
-file("src/parser/scribble.yrl", 85).
yeccpars2_81_(__Stack0) ->
 [__4,__3,__2,__1 | __Stack] = __Stack0,
 [begin
   __1
  end | __Stack].

-compile({inline,yeccpars2_85_/1}).
-file("src/parser/scribble.yrl", 79).
yeccpars2_85_(__Stack0) ->
 [__4,__3,__2,__1 | __Stack] = __Stack0,
 [begin
   { to , __1 , __3 }
  end | __Stack].

-compile({inline,yeccpars2_87_/1}).
-file("src/parser/scribble.yrl", 80).
yeccpars2_87_(__Stack0) ->
 [__4,__3,__2,__1 | __Stack] = __Stack0,
 [begin
   { from , __1 , __3 }
  end | __Stack].

-compile({inline,yeccpars2_89_/1}).
-file("src/parser/scribble.yrl", 0).
yeccpars2_89_(__Stack0) ->
 [__3,__2,__1 | __Stack] = __Stack0,
 [begin
   '$undefined'
  end | __Stack].

-compile({inline,yeccpars2_93_/1}).
-file("src/parser/scribble.yrl", 0).
yeccpars2_93_(__Stack0) ->
 [__5,__4,__3,__2,__1 | __Stack] = __Stack0,
 [begin
   '$undefined'
  end | __Stack].

-compile({inline,yeccpars2_96_/1}).
-file("src/parser/scribble.yrl", 0).
yeccpars2_96_(__Stack0) ->
 [__7,__6,__5,__4,__3,__2,__1 | __Stack] = __Stack0,
 [begin
   '$undefined'
  end | __Stack].

-compile({inline,yeccpars2_97_/1}).
-file("src/parser/scribble.yrl", 0).
yeccpars2_97_(__Stack0) ->
 [__2,__1 | __Stack] = __Stack0,
 [begin
   '$undefined'
  end | __Stack].

-compile({inline,yeccpars2_98_/1}).
-file("src/parser/scribble.yrl", 34).
yeccpars2_98_(__Stack0) ->
 [__3,__2,__1 | __Stack] = __Stack0,
 [begin
   __3
  end | __Stack].

-compile({inline,yeccpars2_100_/1}).
-file("src/parser/scribble.yrl", 36).
yeccpars2_100_(__Stack0) ->
 [__4,__3,__2,__1 | __Stack] = __Stack0,
 [begin
   __4
  end | __Stack].

-compile({inline,yeccpars2_101_/1}).
-file("src/parser/scribble.yrl", 0).
yeccpars2_101_(__Stack0) ->
 [__2,__1 | __Stack] = __Stack0,
 [begin
   '$undefined'
  end | __Stack].

-compile({inline,yeccpars2_102_/1}).
-file("src/parser/scribble.yrl", 35).
yeccpars2_102_(__Stack0) ->
 [__3,__2,__1 | __Stack] = __Stack0,
 [begin
   __3
  end | __Stack].


