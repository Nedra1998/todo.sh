#!/usr/bin/env bash
#  _____ _____ ____  _____   _____ _____
# |_   _|     |    \|     | |   __|  |  |
#   | | |  |  |  |  |  |  |_|__   |     |
#   |_| |_____|____/|_____|_|_____|__|__|
#

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

TODO_VERSION="0.3.0"
TODO_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/todo"
TODO_FILE="${TODO_FILE:-${TODO_DATA_DIR}/$(date +%Y-%m).txt}"

# --- Colors ---

if [ -t 1 ] && [ -z "${NO_COLOR+x}" ]; then
    RESET="\e[0m"
    BOLD="\e[1m"
    BLACK="\e[30m"
    RED="\e[31m"
    GREEN="\e[32m"
    YELLOW="\e[33m"
    BLUE="\e[34m"
    MAGENTA="\e[35m"
    CYAN="\e[36m"
    WHITE="\e[37m"
    BRIGHT_BLACK="\e[90m"
    BRIGHT_RED="\e[91m"
    BRIGHT_GREEN="\e[92m"
    BRIGHT_YELLOW="\e[93m"
    BRIGHT_BLUE="\e[94m"
    BRIGHT_MAGENTA="\e[95m"
    BRIGHT_CYAN="\e[96m"
else
    RESET=""
    BOLD=""
    BLACK=""
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    MAGENTA=""
    CYAN=""
    WHITE=""
    BRIGHT_BLACK=""
    BRIGHT_RED=""
    BRIGHT_GREEN=""
    BRIGHT_YELLOW=""
    BRIGHT_BLUE=""
    BRIGHT_MAGENTA=""
    BRIGHT_CYAN=""
fi

HELP_SECTION_COLOR="${BOLD}${YELLOW}"
HELP_OPTION_COLOR="${GREEN}"

PROJECT_COLOR="${BLUE}"
TAG_COLOR="${YELLOW}"
DATE_COLOR="${MAGENTA}"
METADATA_COLOR="${CYAN}"

STATE_TODO="${BRIGHT_YELLOW}"
STATE_DOING="${BRIGHT_GREEN}"
STATE_PENDING="${BRIGHT_YELLOW}"
STATE_DONE="${BRIGHT_BLACK}"

# --- GNU Core Utilities ---

if command -v gfmt &>/dev/null; then
    _fmt="gfmt"
elif fmt --version &>/dev/null; then
    _fmt="fmt"
else
    printf "%bGNU fmt%b is required for %s%b\n" "$CYAN" "$RED" "$0" "$RESET" 1>&2
    exit 1
fi

if command -v gawk &>/dev/null; then
    _awk="gawk"
elif awk --version &>/dev/null; then
    _awk="awk"
else
    printf "%bGNU awk%b is required for %s%b\n" "$CYAN" "$RED" "$0" "$RESET" 1>&2
    exit 1
fi

if command -v ggrep &>/dev/null; then
    _grep="ggrep"
elif grep --version &>/dev/null; then
    _grep="grep"
else
    printf "%bGNU grep%b is required for %s%b\n" "$CYAN" "$RED" "$0" "$RESET" 1>&2
    exit 1
fi

if command -v gsed &>/dev/null; then
    _sed="gsed"
elif sed --version &>/dev/null; then
    _sed="sed"
else
    printf "%bGNU sed%b is required for %s%b\n" "$CYAN" "$RED" "$0" "$RESET" 1>&2
    exit 1
fi

if command -v gdate &>/dev/null; then
    _date="gdate"
elif date --version &>/dev/null; then
    _date="date"
else
    printf "%bGNU date%b is required for %s%b\n" "$CYAN" "$RED" "$0" "$RESET" 1>&2
    exit 1
fi

# --- Task Reading/Writing ---

function read_tasks() {
    local source="$1"
    if ! [ -f "$source" ]; then return 0; fi
    shift
    local raw_list=""
    if [ -n "$1" ]; then
        raw_list="$(cat -n "$source")"
        for regex in "$@"; do
            raw_list="$($_grep -E "${regex}" <<<"$raw_list")"
        done
    else
        raw_list="$(cat -n "$source")"
    fi

    sed -nE 's/^ *([0-9]+)[\t:]((x) )?(\(([A-Z])\) )?(([0-9]{4}-[0-9]{2}-[0-9]{2}) )?([0-9]{4}-[0-9]{2}-[0-9]{2}) (.*)/\1;\3;\5;\7;\8;\9/p' <<<"$raw_list"
}

# --- Highlighting and Formatting ---

function highlight_task() {
    echo "$1" | awk '''
        {
            if (match($0, /^x/ )) {
                printf "\033[90m%s\033[0m\n", $0
            } else {
                n = split($0, words, " ")

                for (i = 0; ++i <= n;) {
                    if (i == 1 && words[i] ~ /^\([A-Z]\)$/ ) {
                        if (match(words[i], /\([A]\)/)) {
                            printf "\033[1m\033[31m%s\033[0m ", words[i]
                        } else if (match(words[i], /\([BC]\)/)) {
                            printf "\033[31m%s\033[0m ", words[i]
                        } else if (match(words[i], /\([DEF]\)/)) {
                            printf "\033[33m%s\033[0m ", words[i]
                        } else if (match(words[i], /\([GHIJ]\)/)) {
                            printf "\033[35m%s\033[0m ", words[i]
                        } else if (match(words[i], /\([KLMNO]\)/)) {
                            printf "\033[34m%s\033[0m ", words[i]
                        } else if (match(words[i], /\([PQRSTU]\)/)) {
                            printf "\033[32m%s\033[0m ", words[i]
                        } else if (match(words[i], /\([V-Z]\)/)) {
                            printf "\033[90m%s\033[0m ", words[i]
                        }
                    } else if (words[i] ~ /^[+].*[A-Za-z0-9_]$/) {
                        printf "\033[34m%s\033[0m ", words[i]
                    } else if (words[i] ~ /^[@].*[A-Za-z0-9_]$/) {
                        printf "\033[33m%s\033[0m ", words[i]
                    } else if (words[i] ~ /^[A-Za-z0-9]+:[^ ]+$/) {
                        printf "\033[36m%s\033[0m ", words[i]
                    } else if (words[i] ~ /^(19|20)[0-9][0-9]-(0[1-9]|1[012])-(0[1-9]|[12][0-9]|3[01])$/) {
                        printf "\033[35m%s\033[0m ", words[i]
                    } else {
                        printf "%s ", words[i]
                    }
                }
            }
        }
    '''
}

# --- Help Formatting ---

function help_usage() {
    local cmd="$1"
    shift
    if [ -z "$cmd" ]; then
        printf "%bUsage:%b %s [OPTIONS] %s\n" "$HELP_SECTION_COLOR" "$RESET" "todo.sh" "$*"
    else
        printf "%bUsage:%b %s %s [OPTIONS] %s\n" "$HELP_SECTION_COLOR" "$RESET" "todo.sh" "$cmd" "$*"
    fi
}

function help_long() {
    for par in "$@"; do
        printf "\n%s\n" "$(echo "  $par" | $_fmt)"
    done
}

function help_section() {
    printf "\n%b%s:%b\n" "$HELP_SECTION_COLOR" "$1" "$RESET"
}

function help_columns() {
    local columns="$($_awk -F";" '{print NF-1}' <<<"$1")"
    local widths=()

    for _ in $(seq 0 "$columns"); do
        widths+=(0)
    done

    for row in "$@"; do
        for i in $(seq 0 "$columns"); do
            local seg="${row%%;*}"
            row="${row#*;}"
            local seg_len="${#seg}"
            if [ "$seg_len" -gt "${widths[$i]}" ]; then
                widths[$i]="$seg_len"
            fi
        done
    done

    local indent=$((columns * 2))
    for i in $(seq 0 "$((columns - 1))"); do
        local col_width=${widths[$i]}
        indent=$((indent + col_width))
    done

    local body=""
    for row in "$@"; do
        body="$body  "
        for i in $(seq 0 "$((columns - 1))"); do
            local seg="${row%%;*}"
            row="${row#*;}"
            body="$body$(printf "%b%-*s%b" "$HELP_OPTION_COLOR" "${widths[$i]}" "$seg" "$RESET")  "
        done
        local row_len=${#row}
        local msg="$(printf "%*s" "$((indent + row_len + 2))" "$row" | $_fmt)"
        body="$body${msg#"${msg%%[![:space:]]*}"}\n"
    done

    printf "%b" "$body"
}

# --- Argument Validation ---

function validate_file() {
    if ! test -f "$2"; then
        printf "%bThe value of argument '%s' is '%s', which is not an existing file.%b\n" "$RED" "$1" "$2" "$RESET" 1>&2
        exit 1
    fi
    echo "$2"
}

function validate_char() {
    if ! $_grep -q '^[a-zA-Z]$' <<<"$2"; then
        printf "%bThe value of argument '%s' is '%s', which is not a valid character.%b\n" "$RED" "$1" "$2" "$RESET" 1>&2
        exit 1
    fi
    tr '[:lower:]' '[:upper:]' <<<"$2"
}

function validate_int() {
    if ! $_grep -q '^[0-9]\+$' <<<"$2"; then
        printf "%bThe value of argument '%s' is '%s', which is not a valid integer.%b\n" "$RED" "$1" "$2" "$RESET" 1>&2
        exit 1
    fi
    echo "$2"
}

function validate_date() {
    if ! $_date --date "$2" &>/dev/null; then
        printf "%bThe value of argument '%s' is '%s', which is not a valid date.%b\n" "$RED" "$1" "$2" "$RESET" 1>&2
        exit 1
    fi
    $_date --date "$2" +%Y-%m-%d
}

# --- Main ---

_arg_command="list"

function todo_help_main() {
    local extensions=()
    if [ -d "$TODO_DATA_DIR/extensions" ]; then
        for file in "$TODO_DATA_DIR"/extensions/*.sh; do
            if [ "$file" = "$TODO_DATA_DIR/extensions/*.sh" ]; then continue; fi
            local cmd="$(basename "${file%.sh}")"
            source "$file"
            extensions+=("$cmd;$("todo_short_${cmd}")")
        done
    fi

    if [ -d "$SCRIPT_DIR/extensions" ]; then
        for file in "$SCRIPT_DIR"/extensions/*.sh; do
            if [ "$file" = "$SCRIPT_DIR/extensions/*.sh" ]; then continue; fi
            local cmd="$(basename "${file%.sh}")"
            source "$file"
            extensions+=("$cmd;$("todo_short_${cmd}")")
        done
    fi

    help_usage "" "COMMAND..."
    help_long "An extensiable personal todo list manager."
    help_section "Options"
    help_columns \
        "-h;--help;;Show this help message and exit." \
        ";--list;LIST;Set the todo list file to use." \
        ";--version;;Show the version information and exit."
    help_section "Commands"
    help_columns \
        "add;Add a new task to the todo list." \
        "delete;Permenently delete a task from the todo list." \
        "done;Mark a task as completed." \
        "edit;Open the todo list in the default editor." \
        "list;List the tasks in the todo list." \
        "metadata;Set/Unset a metadata value on a task." \
        "move;Move tasks from the current list to another." \
        "priority;Update the priority of a task."

    if [ "${#extensions[@]}" -ne 0 ]; then
        help_section "Extensions"
        help_columns "${extensions[@]}"
    fi
}

function todo_parse_main() {
    while test $# -gt 0; do
        local key="$1"
        case "$key" in
        -h | --help)
            todo_help_main
            exit 0
            ;;
        -h*)
            todo_help_main
            exit 0
            ;;
        --version)
            printf "%s v%s\n" "todo.sh" "$TODO_VERSION"
            exit 0
            ;;
        --list)
            if [ $# -lt 2 ]; then
                printf "%bMissing value for the optional argument '%s'%b\n" "$RED" "$key" "$RESET" 1>&2
                exit 1
            fi

            if test -f "$2"; then
                TODO_FILE="$2"
            elif test -f "$TODO_DATA_DIR/$2"; then
                TODO_FILE="$TODO_DATA_DIR/$2"
            else
                printf "%bThe value of argument '%s' is '%s', which is not an existing file.%b\n" "$RED" "list" "$2" "$RESET" 1>&2
                exit 1
            fi
            shift
            ;;
        --list=*)
            if test -f "${key##--list=}"; then
                TODO_FILE="${key##--list=}"
            elif test -f "$TODO_DATA_DIR/${key##--list=}"; then
                TODO_FILE="$TODO_DATA_DIR/${key##--list=}"
            else
                printf "%bThe value of argument '%s' is '%s', which is not an existing file.%b\n" "$RED" "list" "$2" "$RESET" 1>&2
                exit 1
            fi
            ;;
        add | delete | done | edit | list | metadata | move | priority)
            _arg_command="$key"
            shift
            "todo_parse_$key" "$@"
            break
            ;;
        *)
            if [ -f "$TODO_DATA_DIR/extensions/$key.sh" ]; then
                source "$TODO_DATA_DIR/extensions/$key.sh"
                _arg_command="$key"
                shift
                "todo_parse_$key" "$@"
                break
            fi
            if [ -f "$SCRIPT_DIR/extensions/$key.sh" ]; then
                source "$SCRIPT_DIR/extensions/$key.sh"
                _arg_command="$key"
                shift
                "todo_parse_$key" "$@"
                break
            fi
            todo_help_main
            printf "%bGot an unexpected argument '%s'%b\n" "$RED" "$key" "$RESET"
            exit 1
            ;;
        esac
        shift
    done
}

# --- Add Command ---

_arg_add_priority=""
_arg_add_description=()

function todo_help_add() {
    help_usage "add" "DESCRIPTION..."
    help_long "Add a new task to the todo list."
    help_section "Arguments"
    help_columns \
        "DESCRIPTION;The description for the new task"
    help_section "Options"
    help_columns \
        "-h;--help;;Show this help message and exit." \
        "-P;--project;STRING;Add a project tag to the new task." \
        "-d;--due;DATE;Set the due date for the new task." \
        "-p;--priority;CHARACTER;The priority for the new task." \
        "-t;--tag;STRING;Add a context tag to the new task." \
        ";--*;*;Set additional key value parameters for the task."
}

function todo_parse_add() {
    while test $# -gt 0; do
        local key="$1"
        case "$key" in
        -h | --help)
            todo_help_add
            exit 0
            ;;
        -h*)
            todo_help_add
            exit 0
            ;;
        -P | --project)
            if [ $# -lt 2 ]; then
                printf "%bMissing value for the optional argument '%s'%b\n" "$RED" "$key" "$RESET" 1>&2
                exit 1
            fi
            _arg_add_description+=("+$2")
            shift
            ;;
        --project=*)
            _arg_add_description+=("+${key##--project=}")
            ;;
        -P*)
            _arg_add_description+=("+${key##-P}")
            ;;
        -d | --due)
            if [ $# -lt 2 ]; then
                printf "%bMissing value for the optional argument '%s'%b\n" "$RED" "$key" "$RESET" 1>&2
                exit 1
            fi
            _arg_add_description+=("due:$(validate_date "due" "$2")") || exit 1
            shift
            ;;
        --due=*)
            _arg_add_description+=("due:$(validate_date "due" "${key##--due=}")") || exit 1
            ;;
        -d*)
            _arg_add_description+=("due:$(validate_date "due" "${key##-d}")") || exit 1
            ;;
        -p | --priority)
            if [ $# -lt 2 ]; then
                printf "%bMissing value for the optional argument '%s'%b\n" "$RED" "$key" "$RESET" 1>&2
                exit 1
            fi
            _arg_add_priority="$(validate_char "priority" "$2")" || exit 1
            shift
            ;;
        --priority=*)
            _arg_add_priority="$(validate_char "priority" "${key##--priority=}")" || exit 1
            ;;
        -p*)
            _arg_add_priority="$(validate_char "priority" "${key##-p}")" || exit 1
            ;;
        -t | --tag)
            if [ $# -lt 2 ]; then
                printf "%bMissing value for the optional argument '%s'%b\n" "$RED" "$key" "$RESET" 1>&2
                exit 1
            fi
            _arg_add_description+=("@$2")
            shift
            ;;
        --tag=*)
            _arg_add_description+=("@${key##--tag=}")
            ;;
        -t*)
            _arg_add_description+=("@${key##-t}")
            ;;
        --*=*)
            key="${key##--}"
            _arg_add_description+=("${key%%=*}:${key##*=}")
            ;;
        --*)
            if [ $# -lt 2 ]; then
                printf "%bMissing value for the optional argument '%s'%b\n" "$RED" "$key" "$RESET" 1>&2
                exit 1
            fi
            _arg_add_description+=("${key#--}:$2")
            shift
            ;;
        -*)
            todo_help_add
            printf "%bGot an unexpected argument '%s'%b\n" "$RED" "$key" "$RESET"
            exit 1
            ;;
        *)
            _arg_add_description+=("$key")
            ;;
        esac
        shift
    done

    if [ ${#_arg_add_description[@]} -eq 0 ]; then
        todo_help_add
        printf "%bMissing required argument 'DESCRIPTION'%b\n" "$RED" "$RESET"
        exit 1
    fi
}

function todo_add() {
    local task="$($_date +%Y-%m-%d) "

    if [ -n "$_arg_add_priority" ]; then task="($_arg_add_priority) $task"; fi

    for word in "${_arg_add_description[@]}"; do
        if [ "${word::4}" == "due:" ]; then
            task="${task}due:$(validate_date "due" "${word:4}") "
        else
            task="$task$word "
        fi
    done

    local dir="$(dirname "$TODO_FILE")"
    if ! [ -d "$dir" ]; then mkdir -p "$dir"; fi

    task="${task% }"
    echo "$task" >>"$TODO_FILE"

    echo "Created new task: $(highlight_task "$task")"
}

# --- Delete Command ---

_arg_delete_force=false
_arg_delete_id=()

function todo_help_delete() {
    help_usage "delete" "ID..."
    help_long "Permenently delete task(s) from the todo list."
    help_section "Arguments"
    help_columns \
        "ID;The task IDs to be deleted"
    help_section "Options"
    help_columns \
        "-h;--help;;Show this help message and exit." \
        "-f;--force;;Delete the tasks without waiting for user confirmation."
}

function todo_parse_delete() {
    while test $# -gt 0; do
        local key="$1"
        case "$key" in
        -h | --help)
            todo_help_delete
            exit 0
            ;;
        -h*)
            todo_help_delete
            exit 0
            ;;
        -f | --force)
            _arg_delete_force=true
            ;;
        -f*)
            _arg_delete_force=true
            _next="${key##-f}"
            if [ -n "$_next" ] && [ "$_next" != "$key" ]; then
                shift
                set -- "-f" "-${_next}" "$@"
            fi
            ;;
        -*)
            todo_help_delete
            printf "%bGot an unexpected argument '%s'%b\n" "$RED" "$key" "$RESET"
            exit 1
            ;;
        *)
            _arg_delete_id+=("$(validate_int "ID" "$key")") || exit 1
            ;;
        esac
        shift
    done

    if [ ${#_arg_delete_id[@]} -eq 0 ]; then
        printf "%bMissing required argument 'ID'%b\n" "$RED" "$RESET"
        exit 1
    fi
}

function todo_delete() {
    IFS=$'\n' sorted=($(sort -r <<<"${_arg_delete_id[*]}"))
    unset IFS

    for id in "${sorted[@]}"; do
        local task="$($_sed "${id}q;d" "$TODO_FILE")"
        if [ -z "$task" ]; then
            printf "%bNo task exists with the id '%d', it will be skipped%b\n" "$YELLOW" "$id" "$RESET" 1>&2
            continue
        fi

        if [ "$_arg_delete_force" == false ]; then
            REPLY=""
            while ! [[ "$REPLY" =~ ^[YyNn]$ ]]; do
                read -p "Delete $(highlight_task "$task")[y/n]? " -n 1 -r
                printf "\n"
                if ! [[ "$REPLY" =~ ^[YyNn]$ ]]; then
                    printf "  %bPlease select either 'Y' or 'N'%b\n" "$RED" "$RESET" 1>&2
                fi
            done
            if [[ "$REPLY" =~ ^[Nn]$ ]]; then
                continue
            fi
        fi

        sed -i "${id}d" "$TODO_FILE"

        echo "Deleted the task: $(highlight_task "$task")"
    done
}

# --- Done Command ---

_arg_done_undo=false
_arg_done_id=()

function todo_help_done() {
    help_usage "done" "ID..."
    help_long "Mark a task(s) as completed."
    help_section "Arguments"
    help_columns \
        "ID;The task IDs to mark as completed"
    help_section "Options"
    help_columns \
        "-h;--help;;Show this help message and exit." \
        "-u;--undo;;Re-Open the already completed tasks."
}

function todo_parse_done() {
    while test $# -gt 0; do
        local key="$1"
        case "$key" in
        -h | --help)
            todo_help_done
            exit 0
            ;;
        -h*)
            todo_help_done
            exit 0
            ;;
        -u | --undo)
            _arg_done_undo=true
            ;;
        -u*)
            _arg_done_undo=true
            _next="${key##-u}"
            if [ -n "$_next" ] && [ "$_next" != "$key" ]; then
                shift
                set -- "-u" "-${_next}" "$@"
            fi
            ;;
        -*)
            todo_help_done
            printf "%bGot an unexpected argument '%s'%b\n" "$RED" "$key" "$RESET"
            exit 1
            ;;
        *)
            _arg_done_id+=("$(validate_int "ID" "$key")") || exit 1
            ;;
        esac
        shift
    done

    if [ ${#_arg_done_id[@]} -eq 0 ]; then
        printf "%bMissing required argument 'ID'%b\n" "$RED" "$RESET"
        exit 1
    fi
}

function todo_done() {
    for id in "${_arg_done_id[@]}"; do
        local task="$($_sed "${id}q;d" "$TODO_FILE")"
        if [ -z "$task" ]; then
            printf "%bNo task exists with the id '%d', it will be skipped%b\n" "$YELLOW" "$id" "$RESET" 1>&2
            continue
        fi

        if [ "$_arg_done_undo" == false ]; then
            if [ "${task:0:1}" == "x" ]; then
                printf "%bTask '%d' is already marked as done, nothing to do%b\n" "$YELLOW" "$id" "$RESET" 1>&2
                continue
            elif [[ "$task" = *state:* ]]; then
                task="$($_sed -nE "s/^(\([A-Z]\) )?(.*)( state:[^ ]+)(.*)/x \1$($_date +%Y-%m-%d) \2\4/p" <<<"$task")"
            else
                task="$($_sed -nE "s/^(\([A-Z]\) )?(.*)/x \1$($_date +%Y-%m-%d) \2/p" <<<"$task")"
            fi

            echo "Marked task as done: $(highlight_task "$task")"
        else
            if [ "${task:0:1}" != "x" ]; then
                printf "%bTask '%d' is already marked as open, nothing to do%b\n" "$YELLOW" "$id" "$RESET" 1>&2
                continue
            else
                task="$($_sed -nE "s/^x (\([A-Z]\) )?([0-9]{4}-[0-9]{2}-[0-9]{2} )(.*)/\1\3/p" <<<"$task")"
            fi

            echo "Reopened completed task: $(highlight_task "$task")"
        fi

        $_sed -i "${id} s/^.*$/$task/" "$TODO_FILE"

    done
}

# --- Edit Command ---

_arg_edit_editor="${EDITOR:-vi}"

function todo_help_edit() {
    help_usage "edit"
    help_long "Open the todo list in the default editor."
    help_section "Options"
    help_columns \
        "-h;--help;;Show this help message and exit." \
        "-e;--editor;EDITOR;Specify a specific editor to open the file with."
}

function todo_parse_edit() {
    while test $# -gt 0; do
        local key="$1"
        case "$key" in
        -h | --help)
            todo_help_edit
            exit 0
            ;;
        -h*)
            todo_help_edit
            exit 0
            ;;
        -e | --editor)
            if [ $# -lt 2 ]; then
                printf "%bMissing value for the optional argument '%s'%b\n" "$RED" "$key" "$RESET" 1>&2
                exit 1
            fi
            _arg_edit_editor="$2"
            shift
            ;;
        --editor=*)
            _arg_edit_editor="${key##--editor=}"
            ;;
        -e*)
            _arg_edit_editor="${key##-e}"
            ;;
        *)
            todo_help_edit
            printf "%bGot an unexpected argument '%s'%b\n" "$RED" "$key" "$RESET"
            exit 1
            ;;
        esac
        shift
    done
}

function todo_edit() {
    if ! [ -f "$TODO_FILE" ]; then
        local todo_dir="$(dirname "$TODO_FILE")"
        if ! [ -d "$todo_dir" ]; then mkdir -p "$todo_dir"; fi
        touch "$TODO_FILE"
    fi

    "$_arg_edit_editor" "$TODO_FILE"
}

# --- List Command ---

_arg_list_all=false
_arg_list_filter=()

function todo_help_list() {
    help_usage "list" "[FILTER...]"
    help_long "List tasks in the todo lists."
    help_section "Arguments"
    help_columns \
        "FILTER;A filter expression to filter the tasks included in the list."
    help_section "Options"
    help_columns \
        "-h;--help;Show this help message and exit." \
        "-a;--all;Include already completed tasks in the list."
}

function todo_parse_list() {
    while test $# -gt 0; do
        local key="$1"
        case "$key" in
        -h | --help)
            todo_help_list
            exit 0
            ;;
        -h*)
            todo_help_list
            exit 0
            ;;
        -a | --all)
            _arg_list_all=true
            ;;
        -a*)
            _arg_list_all=true
            _next="${key##-a}"
            if [ -n "$_next" ] && [ "$_next" != "$key" ]; then
                shift
                set -- "-a" "-${_next}" "$@"
            fi
            ;;
        -*)
            todo_help_list
            printf "%bGot an unexpected argument '%s'%b\n" "$RED" "$key" "$RESET"
            exit 1
            ;;
        *)
            _arg_list_filter+=("$key")
            ;;
        esac
        shift
    done
}

function todo_list() {
    if [ "$_arg_list_all" == false ]; then
        tasks="$(read_tasks "$TODO_FILE" "^ *[0-9]+[[:space:]][^x]" "${_arg_list_filter[@]}")"
    else
        tasks="$(read_tasks "$TODO_FILE" "${_arg_list_filter[@]}")"
    fi

    echo "$tasks" | awk -F';' '''
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
            printf "\033[1m%s\033[0m;", $1

            if ($2 == "x") {
                printf "\033[90m✖ \033[0m;"
            } else if (match($6, / state:/)) {
                printf "\033[93m● \033[0m;"
            } else {
                printf ";"
            }

            if (match($3, /[A]/)) {
                printf "\033[1m\033[31m%s\033[0m;", $3
            } else if (match($3, /[BC]/)) {
                printf "\033[31m%s\033[0m;", $3
            } else if (match($3, /[DEF]/)) {
                printf "\033[33m%s\033[0m;", $3
            } else if (match($3, /[GHIJ]/)) {
                printf "\033[35m%s\033[0m;", $3
            } else if (match($3, /[KLMNO]/)) {
                printf "\033[34m%s\033[0m;", $3
            } else if (match($3, /[PQRSTU]/)) {
                printf "\033[32m%s\033[0m;", $3
            } else if (match($3, /[V-Z]/)) {
                printf "\033[90m%s\033[0m;", $3
            } else {
                printf ";"
            }

            printf "\033[35m%s\033[0m;\033[35m%s\033[0m;", $4, $5

            n = split($6, words, " ")

            for (i = 0; ++i <= n;) {
                    if (words[i] ~ /^[+].*[A-Za-z0-9_]$/) {
                        printf "\033[34m%s\033[0m ", words[i]
                    } else if (words[i] ~ /^[@].*[A-Za-z0-9_]$/) {
                        printf "\033[33m%s\033[0m ", words[i]
                    } else if (words[i] ~ /^[A-Za-z0-9]+:[^ ]+$/) {
                        printf "\033[36m%s\033[0m ", words[i]
                    } else {
                        printf "%s ", words[i]
                    }
            }

            printf "\n"
        }
    ''' | column -ts';'
}

# --- Metadata Command ---

_arg_metadata_unset=false
_arg_metadata_key=""
_arg_metadata_value=""
_arg_metadata_id=()

# TODO: Implement special handler for the due key to convert the value to a
# datetime.
function todo_help_metadata() {
    help_usage "metadata" "KEY" "[VALUE]" "ID..."
    help_long "Set/Unset a metadata key value pair in a task."
    help_section "Arguments"
    help_columns \
        "KEY;Metadata key to set." \
        "VALUE;Value to set the metadata too. This must not be included if the --unset option is set." \
        "ID;The task ID(s) to update the metadata value of."
    help_section "Options"
    help_columns \
        "-h;--help;Show this help message and exit." \
        "-u;--unset;Unset the metadata value, rather than updating it."
}

function todo_parse_metadata() {
    while test $# -gt 0; do
        local key="$1"
        case "$key" in
        -h | --help)
            todo_help_metadata
            exit 0
            ;;
        -h*)
            todo_help_metadata
            exit 0
            ;;
        -u | --unset)
            _arg_metadata_unset=true
            ;;
        -u*)
            _arg_metadata_unset=true
            _next="${key##-u}"
            if [ -n "$_next" ] && [ "$_next" != "$key" ]; then
                shift
                set -- "-u" "-${_next}" "$@"
            fi
            ;;
        -*)
            todo_help_metadata
            printf "%bGot an unexpected argument '%s'%b\n" "$RED" "$key" "$RESET"
            exit 1
            ;;
        *)
            if [ -z "$_arg_metadata_key" ]; then
                _arg_metadata_key="$key"
            elif [ -z "$_arg_metadata_value" ]; then
                _arg_metadata_value="$key"
            else
                _arg_metadata_id+=("$(validate_int "ID" "$key")") || exit 1
            fi
            ;;
        esac
        shift
    done

    if [ -z "$_arg_metadata_key" ]; then
        printf "%bMissing required argument 'KEY'%b\n" "$RED" "$RESET"
        exit 1
    fi

    if [ "$_arg_metadata_unset" == true ] && [ -n "$_arg_metadata_value" ]; then
        _arg_metadata_id+=("$(validate_int "ID" "$_arg_metadata_value")") || exit 1
    elif [ -z "$_arg_metadata_value" ]; then
        printf "%bMissing required argument 'VALUE'%b\n" "$RED" "$RESET"
        exit 1
    fi

    if [ ${#_arg_metadata_id[@]} -eq 0 ]; then
        printf "%bMissing required argument 'ID'%b\n" "$RED" "$RESET"
        exit 1
    fi
}

function todo_metadata() {
    for id in "${_arg_metadata_id[@]}"; do
        local task="$($_sed "${id}q;d" "$TODO_FILE")"
        if [ -z "$task" ]; then
            printf "%bNo task exists with the id '%d', it will be skipped%b\n" "$YELLOW" "$id" "$RESET" 1>&2
            continue
        fi

        if [ "$_arg_metadata_unset" == false ]; then
            if [[ "$task" = *$_arg_metadata_key:* ]]; then
                task="$($_sed -nE "s/^(.*)( $_arg_metadata_key:[^ ]+)(.*)/\1 $_arg_metadata_key:$_arg_metadata_value\3/p" <<<"$task")"
            else
                task="$task $_arg_metadata_key:$_arg_metadata_value"
            fi
        else
            if [[ "$task" = *$_arg_metadata_key:* ]]; then
                task="$($_sed -nE "s/^(.*)( $_arg_metadata_key:[^ ]+)(.*)/\1\3/p" <<<"$task")"
            fi
        fi

        $_sed -i "${id} s/^.*$/$task/" "$TODO_FILE"

        echo "Updated task metadata: $(highlight_task "$task")"
    done
}

# --- Move Command ---

_arg_move_id=()
_arg_move_destination=""
_arg_move_force=false
_arg_move_all=false
_arg_move_open=false
_arg_move_done=false

function todo_help_move() {
    help_usage "move" "DESTINATION" "[ID...]"
    help_long "Move tasks form the current list to another."
    help_section "Arguments"
    help_columns \
        "DESTINATION;The destination list to move the tasks to" \
        "ID;The task ID(s) to be moved."
    help_section "Options"
    help_columns \
        "-h;--help;Show this help message and exit." \
        "-f;--force;Move the tasks without waiting for user confirmation." \
        "-a;--all;Move all tasks in the current list." \
        "-o;--open;Move all open tasks in the current list." \
        "-d;--done;Move all completed tasks in the current list."
}

function todo_parse_move() {
    while test $# -gt 0; do
        local key="$1"
        case "$key" in
        -h | --help)
            todo_help_move
            exit 0
            ;;
        -h*)
            todo_help_move
            exit 0
            ;;
        -f | --force)
            _arg_move_force=true
            ;;
        -f*)
            _arg_move_force=true
            _next="${key##-f}"
            if [ -n "$_next" ] && [ "$_next" != "$key" ]; then
                shift
                set -- "-f" "-${_next}" "$@"
            fi
            ;;
        -a | --all)
            _arg_move_all=true
            ;;
        -a*)
            _arg_move_all=true
            _next="${key##-a}"
            if [ -n "$_next" ] && [ "$_next" != "$key" ]; then
                shift
                set -- "-a" "-${_next}" "$@"
            fi
            ;;
        -o | --open)
            _arg_move_open=true
            ;;
        -o*)
            _arg_move_open=true
            _next="${key##-o}"
            if [ -n "$_next" ] && [ "$_next" != "$key" ]; then
                shift
                set -- "-o" "-${_next}" "$@"
            fi
            ;;
        -d | --done)
            _arg_move_done=true
            ;;
        -d*)
            _arg_move_done=true
            _next="${key##-d}"
            if [ -n "$_next" ] && [ "$_next" != "$key" ]; then
                shift
                set -- "-d" "-${_next}" "$@"
            fi
            ;;
        -*)
            todo_help_move
            printf "%bGot an unexpected argument '%s'%b\n" "$RED" "$key" "$RESET"
            exit 1
            ;;
        *)
            if [ -z "$_arg_move_destination" ]; then
                _arg_move_destination="$key"
            else
                _arg_move_id+=("$(validate_int "ID" "$key")") || exit 1
            fi
            ;;
        esac
        shift
    done

    if [ -z "$_arg_move_destination" ]; then
        printf "%bMissing required argument 'DESTINATION'%b\n" "$RED" "$RESET"
        exit 1
    fi
}

function todo_move_id() {
    IFS=$'\n' sorted=($(sort -r <<<"${_arg_move_id[*]}"))
    unset IFS

    for id in "${sorted[@]}"; do
        local task="$($_sed "${id}q;d" "$TODO_FILE")"
        if [ -z "$task" ]; then
            printf "%bNo task exists with the id '%d', it will be skipped%b\n" "$YELLOW" "$id" "$RESET" 1>&2
            continue
        fi

        if [ "$_arg_move_force" == false ]; then
            REPLY=""
            while ! [[ "$REPLY" =~ ^[YyNn]$ ]]; do
                read -p "Move $(highlight_task "$task")[y/n]? " -n 1 -r
                printf "\n"
                if ! [[ "$REPLY" =~ ^[YyNn]$ ]]; then
                    printf "  %bPlease select either 'Y' or 'N'%b\n" "$RED" "$RESET" 1>&2
                fi
            done
            if [[ "$REPLY" =~ ^[Nn]$ ]]; then
                continue
            fi
        fi

        sed -i "${id}d" "$TODO_FILE"
        echo "$task" >>"$_arg_move_destination"

        echo "Moved the task: $(highlight_task "$task")"
    done
}

function todo_move_grep() {
    tasks="$(grep -E "$1" "$TODO_FILE")"

    local count="$(wc -l <<<"$tasks")"
    count="$(printf "%b%s%b" "$CYAN" "$count" "$RESET")"

    if [ "$_arg_move_force" == false ]; then
        REPLY=""
        while ! [[ "$REPLY" =~ ^[YyNn]$ ]]; do
            read -p "Move $count tasks [y/n]? " -n 1 -r
            printf "\n"
            if ! [[ "$REPLY" =~ ^[YyNn]$ ]]; then
                printf "  %bPlease select either 'Y' or 'N'%b\n" "$RED" "$RESET" 1>&2
            fi
        done
        if [[ "$REPLY" =~ ^[Nn]$ ]]; then
            return
        fi
    fi

    sed -i "/$1/d" "$TODO_FILE"
    echo "$tasks" >>"$_arg_move_destination"
    echo "Moved $count tasks"
}

function todo_move() {
    echo "$_arg_move_destination"

    if ! [ "${_arg_move_destination:0:1}" == "/" ] && ! [ "${_arg_move_destination:0:2}" == "./" ]; then
        _arg_move_destination="$TODO_DATA_DIR/$_arg_move_destination"
    fi

    echo "$_arg_move_destination"

    local dir="$(dirname "$_arg_move_destination")"
    if ! [ -d "$dir" ]; then mkdir -p "$dir"; fi

    todo_move_id

    if [ "$_arg_move_done" == true ]; then
        todo_move_grep "^x "
    fi

    if [ "$_arg_move_open" == true ]; then
        todo_move_grep "^[^x]"
    fi

    if [ "$_arg_move_all" == true ]; then
        todo_move_grep "^."
    fi
}

# --- Priority Command ---

_arg_priority_unset=false
_arg_priority_value=""
_arg_priority_id=()

function todo_help_priority() {
    help_usage "priority" "[PRIORITY]" "ID..."
    help_long "Update or unset the prioritization of a task."
    help_section "Arguments"
    help_columns \
        "PRIORITY;The priority for the task. This must be excluded if the --unset option is passed." \
        "ID;The task ID(s) to update the priority value of."
    help_section "Options"
    help_columns \
        "-h;--help;Show this help message and exit." \
        "-u;--unset;Unset the task priority, rather than updating it."
}

function todo_parse_priority() {
    while test $# -gt 0; do
        local key="$1"
        case "$key" in
        -h | --help)
            todo_help_priority
            exit 0
            ;;
        -h*)
            todo_help_priority
            exit 0
            ;;
        -u | --unset)
            _arg_priority_unset=true
            ;;
        -u*)
            _arg_priority_unset=true
            _next="${key##-u}"
            if [ -n "$_next" ] && [ "$_next" != "$key" ]; then
                shift
                set -- "-u" "-${_next}" "$@"
            fi
            ;;
        -*)
            todo_help_priority
            printf "%bGot an unexpected argument '%s'%b\n" "$RED" "$key" "$RESET"
            exit 1
            ;;
        *)
            if [ -z "$_arg_priority_value" ]; then
                _arg_priority_value="$key"
            else
                _arg_priority_id+=("$(validate_int "ID" "$key")") || exit 1
            fi
            ;;
        esac
        shift
    done

    if [ "$_arg_priority_unset" == true ] && [ -n "$_arg_priority_value" ]; then
        _arg_priority_id+=("$(validate_int "ID" "$_arg_priority_value")") || exit 1
    elif [ -z "$_arg_priority_value" ]; then
        printf "%bMissing required argument 'PRIORITY'%b\n" "$RED" "$RESET"
        exit 1
    else
        _arg_priority_value="$(validate_char "PRIORITY" "$_arg_priority_value")" || exit 1
    fi

    if [ ${#_arg_priority_id[@]} -eq 0 ]; then
        printf "%bMissing required argument 'ID'%b\n" "$RED" "$RESET"
        exit 1
    fi
}

function todo_priority() {
    for id in "${_arg_priority_id[@]}"; do
        local task="$($_sed "${id}q;d" "$TODO_FILE")"
        if [ -z "$task" ]; then
            printf "%bNo task exists with the id '%d', it will be skipped%b\n" "$YELLOW" "$id" "$RESET" 1>&2
            continue
        fi

        if [ "$_arg_priority_unset" == false ]; then
            task="$($_sed -nE "s/^(x )?(\([A-Z]\) )?(.*)/\1($_arg_priority_value) \3/p" <<<"$task")"
        else
            task="$($_sed -nE "s/^(x )?(\([A-Z]\) )?(.*)/\1\3/p" <<<"$task")"
        fi

        $_sed -i "${id} s/^.*$/$task/" "$TODO_FILE"

        echo "Updated task priority: $(highlight_task "$task")"
    done
}

# --- Entrypoint ---

todo_parse_main "$@"
"todo_$_arg_command"
exit $?
