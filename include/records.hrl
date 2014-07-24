

%%
%% Monscr data for recovery 
%% ---------------------------------------------------
-record(child_entry, {id,
        worker,
        client,
        data}
).

-record(child_data, {protocol,
        role,
        secret_number,
        count,
        num_lines}
).


%%
%% Monscr related structures
%% ---------------------------------------------------
-record(internal,{main_sup,
        prot_sup = []}
).

-record(prot_sup,{protocol,
        ref,
        roles}
).

-record(func,{sign,
        func}
).


%%
%% Role related structures
%% ---------------------------------------------------
-record(role_data,{id,
        spec,
        conn,
        exc,
        state}
).

-record(spec,{protocol, 
        role,
        roles,
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
        count,
        secret_number,
        confirmation_list,
        confirmation_state,
        timer_pid}
).

%%
%% Database realted structures
%% -----------------------------------------------------
-record(row, {num, 
        inst}
).

