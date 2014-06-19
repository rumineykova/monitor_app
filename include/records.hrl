

%%
%% Monscr related structures
%% ---------------------------------------------------

-record(internal,{main_sup,
		regp = [],
		prot_sup = []}
).

-record(prot_sup,{protocol,
  ref,
  roles}
).

-record(lrole,{role,
		roles,
		ref,
		imp_ref,
		funcs}
).

-record(func,{sign,
		func}
).


%%
%% Role related structures
%% ---------------------------------------------------

-record(role_data,{spec,
		conn,
		exc,
    state}
).

-record(spec,{protocol, 
		role,
		roles,
		ref, 
		imp_ref,
		funcs,
		projection,
    lines}
).

-record(conn,{connection,
		active_chn,
		con_id,
		active_q,
		active_exc,
		active_cns}).

-record(exc,{state,
		count}
).


%%
%% Database realted structures
%% -----------------------------------------------------

-record(row, {num, 
		inst}
).


