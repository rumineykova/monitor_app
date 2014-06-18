Nonterminals
local_protocol_decl
local_protocol_body
local_interaction_block
local_interaction_sequence
local_interaction
to_send
to_receive
local_choice
local_choice_cont
local_parallel
local_parallel_cont
local_recursion
local_continue
role_name
message_signature
message_operator
payload_type
identifier
role_list.


Terminals 'and' 'as' 'at' 'by' 'catch' 'choice' 'continue' 'create' 'do' 'enter' 'from' 'global' 'import' 'instantiates' 'interruptible' 'local' 'or' 'par'	'protocol' 'rec' 'role' 'spawns' 'throw' 'to' 'with' '(' ')' '{' '}' ';' ',' 'atom'.
Rootsymbol local_protocol_decl.

local_protocol_decl -> 'local' 'protocol' identifier 'at' role_name '(' role_list ')' local_protocol_body : {protocol, '$3','$5','$7','$9'}.


role_list -> 'role' role_name ',' role_list : ['$2'] ++ '$4'.
role_list -> 'role' role_name  : '$2'.

role_name -> 'atom' : '$1'.

local_protocol_body -> local_interaction_block : '$1'.
local_interaction_block ->	'{' local_interaction_sequence '}' : '$2'.

local_interaction_sequence -> local_interaction : '$1'.
local_interaction_sequence -> local_interaction local_interaction_sequence : '$1' ++ '$2'.

local_interaction -> to_send : ['$1'].
local_interaction -> to_receive : ['$1'].
local_interaction -> local_choice : ['$1', [{erec,none}]].
local_interaction -> local_parallel : ['$1'].
local_interaction -> local_recursion : ['$1'].
local_interaction -> local_continue : ['$1'].


to_send ->	message_signature 'to' role_name ';' : {to, '$1', '$3'}.
to_receive -> message_signature 'from' role_name ';'  : {from, '$1', '$3'}.


%NOT EXACT!!!!! Be careful
message_signature -> message_operator  '(' ')' : '$1'.
message_signature -> message_operator  '(' payload_type ')'  : '$1'.

message_operator -> 'atom' : '$1'.


local_choice -> 'choice' 'at' role_name  local_interaction_block local_choice_cont : {choice, '$3', ['$4'++[{econtinue,none}], '$5']}.
local_choice -> 'choice' 'at' role_name  local_interaction_block : {choice, '$3', ['$4', [{econtinue,none}]]}.
local_choice_cont -> 'or'  local_interaction_block local_choice_cont : [{'or','$2'++ [{econtinue,none}]}] ++ '$3'.
local_choice_cont -> 'or'  local_interaction_block : [{'or', '$2' ++ [{econtinue,none}]}].


local_parallel -> 'par' local_interaction_block  local_parallel_cont : {par, ['$2', '$3'] }.
local_parallel -> 'par' local_interaction_block : {par, ['$2']}.
local_parallel_cont -> 'and' local_interaction_block  local_parallel_cont : [{'and', '$2'}] ++ '$3'.
local_parallel_cont -> 'and' local_interaction_block : [{'and', '$2'}].


local_recursion -> 'rec' identifier local_interaction_block : {rec,'$2',['$3']}.

local_continue -> 'continue' identifier ';' : {continue, '$2'}.
 
payload_type -> 'atom' : '$1'. 
identifier -> 'atom' : '$1'.

