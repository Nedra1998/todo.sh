#!/usr/bin/env bash

_arg_promote_id=()
_arg_promote_demote=false
_arg_promote_states="todo,doing,pending"
_arg_promote_state=""

function todo_short_promote() {
    echo "Promote the state of a task through several stages."
}

function todo_help_promote() {
    help_usage "promote" "[STATE]" "ID..."
    help_long "Promote the state of a task through several stages."
    help_section "Arguments"
    help_columns \
        "STATE;Specify a specific state for the tasks, rather than just moving the the next state in the list." \
        "ID;The task IDs to be promoted."
    help_section "Options"
    help_columns \
        "-h;--help;;Show this help message and exit." \
        "-s;--states;STAGES;Comma separated list of states to cycle tasks through (open is always the first state, and done is always the final state)." \
        "-d;--demote;;Move a task backwards rather than forwards through the stages."
}

function todo_parse_promote() {
    _first_positional=true

    while test $# -gt 0; do
        local key="$1"
        case "$key" in
        -h | --help)
            todo_help_promote
            exit 0
            ;;
        -h*)
            todo_help_promote
            exit 0
            ;;
        -s | --states)
            if [ $# -lt 2 ]; then
                printf "%bMissing value for the optional argument '%s'%b\n" "$RED" "$key" "$RESET"
                exit 1
            fi
            _arg_promote_states="$2"
            ;;
        --states=*)
            _arg_promote_states="${key##--stages=}"
            ;;
        -s*)
            _arg_promote_states="${key##-s}"
            ;;
        -d | --demote)
            _arg_promote_demote=true
            ;;
        -d*)
            _arg_promote_demote=true
            _next="${key##-d}"
            if [ -n "$_next" ] && [ "$_next" != "$key" ]; then
                shift
                set -- "-d" "-${_next}" "$@"
            fi
            ;;
        -*)
            todo_help_promote
            printf "%bGot an unexpected argument '%s'%b\n" "$RED" "$key" "$RESET"
            exit 1
            ;;
        *)
            if [ "$_first_positional" == true ] && ! [[ "$key" =~ ^[0-9]+$ ]]; then
                _arg_promote_state="$key"
            else
                _arg_promote_id+=("$(validate_int "ID" "$key")") || exit 1
            fi
            _first_positional=false
            ;;
        esac
        shift
    done
}

function todo_promote() {
    if ! [[ "$_arg_promote_states" = ^open,* ]]; then
        _arg_promote_states="open,$_arg_promote_states"
    fi
    if ! [[ "$_arg_promote_states" = *,done$ ]]; then
        _arg_promote_states="$_arg_promote_states,done"
    fi
    IFS=',' read -ra states <<<"$_arg_promote_states"

    for id in "${_arg_promote_id[@]}"; do
        local task="$($_sed "${id}q;d" "$TODO_FILE")"
        if [ -z "$task" ]; then
            printf "%bNo task exists with the id '%d', it will be skipped%b\n" "$YELLOW" "$id" "$RESET" 1>&2
            continue
        fi

        local current_state="open"

        if [ "${task:0:1}" == "x" ]; then
            current_state="done"
        elif [[ "$task" = *state:* ]]; then
            current_state="$($_grep -oE "state:[^ ]+" <<<"$task")"
            current_state="${current_state##state:}"
        fi

        local next_state=""

        if [ -n "$_arg_promote_state" ]; then
            if [ "$_arg_promote_state" == "$current_state" ]; then
                printf "%bThe task '%d' is already in the desired state, it will be skipped%b\n" "$YELLOW" "$id" "$RESET" 1>&2
                continue
            fi
            next_state="$_arg_promote_state"
        elif [ "$_arg_promote_demote" == true ]; then
            if [ "$current_state" == "open" ]; then
                printf "%bThe task '%d' is already in the open state, it cannot be demonted any further%b\n" "$YELLOW" "$id" "$RESET" 1>&2
                continue
            else
                for i in "${!states[@]}"; do
                    if [ "${states[$i]}" == "${current_state}" ]; then
                        next_state="${states[$((i - 1))]}"
                        break
                    fi
                done
                if [ -z "$next_state" ]; then
                    printf "%bThe state of task '%d' is included in the --states option, it will be skipped%b\n" "$YELLOW" "$id" "$RESET" 1>&2
                    continue
                fi
            fi
        else
            if [ "$current_state" == "done" ]; then
                printf "%bThe task '%d' is already in the done state, it cannot be promoted any further%b\n" "$YELLOW" "$id" "$RESET" 1>&2
                continue
            else
                for i in "${!states[@]}"; do
                    if [ "${states[$i]}" == "${current_state}" ]; then
                        next_state="${states[$((i + 1))]}"
                        break
                    fi
                done
                if [ -z "$next_state" ]; then
                    printf "%bThe state of task '%d' is included in the --states option, it will be skipped%b\n" "$YELLOW" "$id" "$RESET" 1>&2
                    continue
                fi
            fi
        fi

        if [ "$current_state" == "done" ]; then
            task="$($_sed -nE "s/^x (\([A-Z]\) )?([0-9]{4}-[0-9]{2}-[0-9]{2} )(.*)/\1\3/p" <<<"$task")"
        fi

        if [ "$next_state" == "done" ]; then
            if [[ "$task" = *state:* ]]; then
                task="$($_sed -nE "s/^(\([A-Z]\) )?(.*)( state:[^ ]+)(.*)/x \1$($_date +%Y-%m-%d) \2\4/p" <<<"$task")"
            else
                task="$($_sed -nE "s/^(\([A-Z]\) )?(.*)/x \1$($_date +%Y-%m-%d) \2/p" <<<"$task")"
            fi
        elif [ "$next_state" == "open" ]; then
            if [[ "$task" = *state:* ]]; then
                task="$($_sed -nE "s/^(.*)( state:[^ ]+)(.*)/\1\3/p" <<<"$task")"
            fi
        else
            if [[ "$task" = *state:* ]]; then
                task="$($_sed -nE "s/^(.*)( state:[^ ]+)(.*)/\1 state:$next_state\3/p" <<<"$task")"
            else
                task="$task state:$next_state"
            fi
        fi

        $_sed -i "${id} s/^.*$/$task/" "$TODO_FILE"

        echo "Updated task state: $(highlight_task "$task")"
    done
}
