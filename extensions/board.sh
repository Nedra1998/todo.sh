#!/usr/bin/env bash

_arg_board_filter=()
_arg_board_columns="open,todo,doing,pending"

function todo_short_board() {
    echo "View the todo list as a kanban board."
}

function todo_help_board() {
    help_usage "board" "[FILTER...]"
    help_long "View the todo list as a kanban board."
    help_section "Arguments"
    help_columns \
        "FILTER;A filter expression to filter the tasks included in the board."
    help_section "Options"
    help_columns \
        "-h;--help;;Show this help message and exit." \
        "-c;--columns;COLUMNS;Comma separated list of columns to include in the board."
}

function todo_parse_board() {
    while test $# -gt 0; do
        local key="$1"
        case "$key" in
        -h | --help)
            todo_help_board
            exit 0
            ;;
        -h*)
            todo_help_board
            exit 0
            ;;
        *)
            todo_help_board
            printf "%bGot an unexpected argument '%s'%b\n" "$RED" "$key" "$RESET"
            exit 1
            ;;
        esac
        shift
    done
}

function todo_board() {
    IFS=',' read -ra columns <<<"$_arg_board_columns"

    max_lines=0
    data=()

    headers=""

    for col in "${columns[@]}"; do
        headers="$headers$(echo -e "${BOLD}===== ${col^} =====${RESET},")"

        if [ "$col" == "open" ]; then
            tasks="$(read_tasks "$TODO_FILE" "^ *[0-9]+[[:space:]][^x]" "${_arg_board_filter[@]}")"
            tasks="$(grep -Ev " state:" <<<"$tasks")"
        elif [ "$col" == "done" ]; then
            tasks="$(read_tasks "$TODO_FILE" "^ *[0-9]+[[:space:]]x " "${_arg_board_filter[@]}")"
        else
            tasks="$(read_tasks "$TODO_FILE" " state:$col( |$)" "${_arg_board_filter[@]}")"
        fi

        lines="$(wc -l <<<"$tasks")"
        if [ "$lines" -gt "$max_lines" ]; then
            max_lines="$lines"
        fi

        data+=("$(echo "$tasks" | awk -F';' '''
            { 
                if ($2 == "x") { printf "ZZ" }
                if (match($3, /[A-Z]/)) {
                    printf "%c", $3
                } else {
                    printf "ZZ"
                }
                printf "%03d\t%s\n", $1, $0
            }
            ''' | sort -dk1 | cut -f2- | awk -F';' '''
            {
                printf "\033[1m%s)\033[0m ", $1

                col=""

                if (match($3, /[A]/)) {
                    col="\033[1m\033[31m"
                } else if (match($3, /[BC]/)) {
                    col="\033[31m"
                } else if (match($3, /[DEF]/)) {
                    col="\033[33m"
                } else if (match($3, /[GHIJ]/)) {
                    col="\033[35m"
                } else if (match($3, /[KLMNO]/)) {
                    col="\033[34m"
                } else if (match($3, /[PQRSTU]/)) {
                    col="\033[32m"
                } else if (match($3, /[V-Z]/)) {
                    col="\033[90m"
                }

                n = split($6, words, " ")

                printf "%s", col

                for (i = 0; ++i <= n;) {
                        if (words[i] ~ /^[+].*[A-Za-z0-9_]$/) {
                            printf "\033[0m\033[34m%s\033[0m %s", words[i], col
                        } else if (words[i] ~ /^[@].*[A-Za-z0-9_]$/) {
                            printf "\033[0m\033[33m%s\033[0m %s", words[i], col
                        } else if (words[i] ~ /^[A-Za-z0-9]+:[^ ]+$/) {
                            if (words[i] ~ /^due:/) {
                                printf "\033[0m\033[36m%s\033[0m %s", words[i], col
                            }
                        } else {
                            printf "%s ", words[i]
                        }
                }

                printf "\033[0m\n"
            }
            ''')")
    done

    table=""
    for row in $(seq 1 "$max_lines"); do
        for col in "${data[@]}"; do
            if [ "$(wc -l <<<"$col")" -lt "$row" ]; then
                table="$table;"
            else
                table="$table$(sed "${row}q;d" <<<"$col");"
            fi
        done
        table="$table\n"
    done

    # TODO: Find a better way to handle the columns and text wrapping for long
    # tasks. The column command breaks the ANSI escape codes used for colors
    # when wrapping text.
    echo -e "$(echo -e "$table" | column -ts';' -N "${headers%,}")"
}
