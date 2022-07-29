#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
TODO_VERSION="0.2.0"
TODO_DIR="${TODO_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/todo}"
TODO_STATES="${TODO_STATES:-backlog=0,todo=1,design=2,doing=2,review=3,testing=3,deploying=4,done=4}"

# }}}
# --- Colors --- {{{

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
fi

# }}}
# --- GNU Linux Utilities --- {{{

CUT="cut"
if cut --version &>/dev/null; then
  CUT="cut"
elif command -v gcut &>/dev/null; then
  CUT="gcut"
else
  printf "%bGNU %bcut%b is required for %s" "$RED" "$CYAN" "$RED" "$0" >&2
  exit 1
fi

SED="sed"
if sed --version &>/dev/null; then
  SED="sed"
elif command -v gsed &>/dev/null; then
  SED="gsed"
else
  printf "%bGNU %bsed%b is required for %s" "$RED" "$CYAN" "$RED" "$0" >&2
  exit 1
fi

COLUMN="column"
if column --version &>/dev/null; then
  COLUMN="column"
else
  printf "%butil-linux %bcolumn%b is required for %s" "$RED" "$CYAN" "$RED" "$0" >&2
  exit 1
fi

DATE="date"
if date --version &>/dev/null; then
  DATE="date"
elif command -v gdate &>/dev/null; then
  DATE="gdate"
else
  printf "%bGNU %bdate%b is required for %s" "$RED" "$CYAN" "$RED" "$0" >&2
  exit 1
fi

FMT="fmt"
if fmt --version &>/dev/null; then
  FMT="fmt"
elif command -v gfmt &>/dev/null; then
  FMT="gfmt"
else
  printf "%bGNU %bfmt%b is required for %s" "$RED" "$CYAN" "$RED" "$0" >&2
  exit 1
fi

# }}}
# --- Task Formatting --- {{{

CMAP=("${BOLD}${RED}" "${RED}" "${YELLOW}" "${MAGENTA}" "${BLUE}" "${CYAN}" "${GREEN}" "${BLACK}")
STATE_CMAP=("${BLUE}" "${CYAN}" "${RED}" "${YELLOW}" "${GREEN}")
DONE_COLOR="${BLACK}"

DATE_COLOR="${MAGENTA}"
PROJECT_COLOR="${BLUE}"
TAG_COLOR="${YELLOW}"
KVP_COLOR="${CYAN}"

function cmap() {
  local val="$1"
  local max="$2"
  shift 2
  local len="$#"
  local idx="$(((val * len) / max + 1))"

  if [ "$idx" -gt "$len" ]; then
    idx="$((len))"
  fi

  printf "%b" "${!idx}"
}

function color_pri() {
  if [ -z "$1" ]; then return 0; fi
  local ord="$(printf "%d" "'$1")"
  cmap "$((ord - 65))" "8" "${CMAP[@]}"
}

function color_urg() {
  local val="${1::1}"
  cmap "$((10 - val))" "10" "${CMAP[@]}"
}

function fmt_state() {
  if [ "$1" == "x" ]; then
    printf "%bX%b" "${BOLD}${BLACK}" "${RESET}"
  elif [ -n "$2" ] && grep -q "${2,,}=[0-9]" <<<"$TODO_STATES"; then
    local state="$(grep -oP "${2,,}=[0-9]" <<<"$TODO_STATES")"
    printf "%b %b" "$(cmap "${state##*;}" 4 "${STATE_CMAP[@]}")" "${RESET}"
  fi
}

function fmt_urgency() {
  # printf "%02d" "$1" | sed -e 's/.$/.&/;t' -e 's/.$/.0&/'
  printf "%b%s%b" "$(cmap "$((100 - $1))" 100 "${CMAP[@]}")" "$(printf "%02d" "$1" | sed -e 's/.$/.&/;t' -e 's/.$/.0&/')" "${RESET}"
}

function fmt_description() {
  local strip="$2"
  local result=""
  read -ra words <<<"$1"
  for word in "${words[@]}"; do
    if [ "${word:0:1}" == "+" ]; then
      result="$result${PROJECT_COLOR}${word}${RESET} "
    elif [ "${word:0:1}" == "@" ]; then
      result="$result${TAG_COLOR}${word}${RESET} "
    elif [[ "$word" = *:* ]]; then
      if ! [[ " $strip " = *" ${word%%:*} "* ]]; then
        result="$result${KVP_COLOR}${word}${RESET} "
      fi
    else
      result="$result$word "
    fi
  done
  printf "%b" "${result% }"
}

function fmt_task() {
  local task="$1"
  local result=""
  if [[ "$1" =~ ^(.)?\;([A-Z])?\;([^\;]*)?\;([^\;]*)\;(.*) ]]; then
    local state="${BASH_REMATCH[1]}"
    local pri="${BASH_REMATCH[2]}"
    local done="${BASH_REMATCH[3]}"
    local created="${BASH_REMATCH[4]}"
    local description="${BASH_REMATCH[5]}"

    if [ -n "$state" ]; then
      result="${DONE_COLOR}$state "
      if [ -n "$pri" ]; then result="$result$(pri) "; fi

      result="$result$done $created $description"
    else
      if [ -n "$pri" ]; then
        result="$(color_pri "$pri")($pri)${RESET} "
      fi
      result="$result${DATE_COLOR}$created${RESET} $(fmt_description "$description")"
    fi
  fi

  printf "%b\n" "$result"
}

# }}}
# --- Task Utilities --- {{{

function write_task() {
  local result=""
  if [[ "$1" =~ ^(.)?\;([A-Z])?\;([^\;]*)\;([^\;]*)\;(.*) ]]; then
    local state="${BASH_REMATCH[1]}"
    local pri="${BASH_REMATCH[2]}"
    local done="${BASH_REMATCH[3]}"
    local created="${BASH_REMATCH[4]}"
    local description="${BASH_REMATCH[5]}"

    if [ -n "$state" ]; then result="$state "; fi
    if [ -n "$pri" ]; then result="$result($pri) "; fi
    if [ -n "$done" ]; then result="$result$done "; fi
    result="$result$created $description"
  fi

  printf "%s\n" "$result"
}

function read_task() {
  if [[ "$1" =~ ^(x )?(\([A-Z]\) )?([0-9]{4}-[0-9]{2}-[0-9]{2})\ ([0-9]{4}-[0-9]{2}-[0-9]{2} )?(.*)$ ]]; then
    local state="${BASH_REMATCH[1]}"
    local pri="${BASH_REMATCH[2]}"
    local done="${BASH_REMATCH[3]}"
    local created="${BASH_REMATCH[4]}"
    local description="${BASH_REMATCH[5]}"

    if [ -z "$created" ]; then
      created="$done"
      done=""
    fi

    printf "%s;%s;%s;%s;%s" "${state% }" "${pri:1:1}" "${done% }" "${created% }" "$description"
  else
    printf "%bFailed to parse task '%s'%b\n" "$YELLOW" "$1" "$RESET" >&2
  fi
}

function find_task() {
  local task="$("$SED" "${id}q;d" "$TODO_DIR/todo.txt")"
  if [ -n "$task" ]; then
    echo "$id:$TODO_DIR/todo.txt:$(read_task "$task")"
    return 0
  elif [ -f "$TODO_DIR/done.txt" ]; then
    local count="$(wc -l <"$TODO_DIR/todo.txt")"
    local cid="$((id - count))"
    task="$("$SED" "${cid}q;d" "$TODO_DIR/done.txt")"
    if [ -n "$task" ]; then
      echo "$cid:$TODO_DIR/done.txt:$(read_task "$task")"
      return 0
    fi
  fi

  printf "%bNo tasks with id '%d', it will be skipped %b\n" "$YELLOW" "$id" "$RESET" >&2
}

function get_tasks() {
  local filter="$1"
  local done="$2"
  local open="${3:-true}"

  raw_list=""
  if [ -f "$TODO_DIR/todo.txt" ] && [ "$open" == true ]; then
    if [ -n "$filter" ]; then
      raw_list="$raw_list\n$(grep -E "$filter" "$TODO_DIR/todo.txt")"
    else
      raw_list="$raw_list\n$(cat "$TODO_DIR/todo.txt")"
    fi
  fi

  if [ -f "$TODO_DIR/done.txt" ] && [ "$done" == true ]; then
    if [ -n "$filter" ]; then
      raw_list="$raw_list\n$(grep -E "$filter" "$TODO_DIR/done.txt")"
    else
      raw_list="$raw_list\n$(cat "$TODO_DIR/done.txt")"
    fi
  fi

  tasks=""
  idx=1
  while IFS= read -r line; do
    if [ -z "$line" ]; then continue; fi
    tasks="$tasks$idx;$(read_task "$line")\n"
    idx=$((idx + 1))
  done < <(printf "%b\n" "$raw_list")

  printf "%b" "$tasks"
}

function split_task() {
  if [[ "$1" =~ ^(.)?\;([A-Z])?\;([^\;]*)?\;([^\;]*)\;(.*) ]]; then
    eval "state=\"${BASH_REMATCH[1]}\""
    eval "pri=\"${BASH_REMATCH[2]}\""
    eval "done=\"${BASH_REMATCH[3]}\""
    eval "created=\"${BASH_REMATCH[4]}\""
    eval "description=\"${BASH_REMATCH[5]}\""
  fi
}

function get_kvp() {
  local res="$(grep -oP "$1:[^ ]+" <<<"${2##*;}")"
  if [ -n "$res" ]; then
    echo "${res#*:}"
  fi
}

function calc_urgency() {
  local urg=0
  local now="$(date +%s)"
  if [[ "$1" =~ ^(.)?\;([A-Z])?\;([^\;]*)?\;([^\;]*)\;(.*) ]]; then
    local state="${BASH_REMATCH[1]}"
    local pri="${BASH_REMATCH[2]}"
    local done="${BASH_REMATCH[3]}"
    local created="${BASH_REMATCH[4]}"
    local description="${BASH_REMATCH[5]}"
    created="$("$DATE" --date "$created" +%s)"

    if [ -n "$pri" ]; then
      local ord="$(printf "%d" "'$pri")"
      urg=$((urg + (3 * (90 - ord))))
    fi

    local due="$(get_kvp "due" "$1")"
    if [ -n "$due" ] && [ -z "$state" ]; then
      due="$("$DATE" --date "$due" +%s)"
      urg=$((urg + ((25 * (now - created) / (due - created)))))
    fi

    if [ -z "$state" ]; then
      urg=$((urg + ((now - created) / 86400)))
    fi

  fi

  echo "$urg"
}

# }}}
# --- User Prompts --- {{{

function pmt_confirm() {
  read -p "$1 [y/n]? " -n 1 -r
  printf "\n"
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    return 0
  else
    return 1
  fi
}

# }}}
# --- Argument Validators --- {{{

function pchar() {
  if ! grep -q '^[a-zA-Z]$' <<<"$1"; then
    printf "%bThe value of argument '%s' is '%s', which is not a valid character.%b\n" "$YELLOW" "$2" "$1" "$RESET" >&2
    exit 1
  fi
  tr '[:lower:]' '[:upper:]' <<<"$1"
}

function pint() {
  if ! grep -q '^[1-9][0-9]*$' <<<"$1"; then
    printf "%bThe value of argument '%s' is '%s', which is not a valid integer.%b\n" "$YELLOW" "$2" "$1" "$RESET" >&2
    exit 1
  fi
  echo "$1"
}

function pdate() {
  if ! "$DATE" --date "$1" &>/dev/null; then
    printf "%bThe value of argument '%s' is '%s', which is not a valid date.%b\n" "$YELLOW" "$2" "$1" "$RESET" >&2
    exit 1
  fi
  "$DATE" --date "$1" +%Y-%m-%d
}

# }}}
# --- Argparse Utilities --- {{{

function husage() {
  local cmd="$1"
  shift
  if [ -z "$cmd" ]; then
    printf "%bUsage:%b %s [OPTIONS] %s\n" "$YELLOW" "$RESET" "$0" "$*"
  else
    printf "%bUsage:%b %s %s [OPTIONS] %s\n" "$YELLOW" "$RESET" "$0" "$cmd" "$*"
  fi
}

function hlong() {
  printf "\n%s\n" "$(echo "  $1" | "$FMT")"
}

function hsection() {
  printf "\n%b%s:%b\n" "$YELLOW" "$1" "$RESET"
}

function harguments() {
  local lkey=0
  for row in "$@"; do
    local key="${row%%;*}"
    if [ ${#key} -gt $lkey ]; then
      lkey=${#key}
    fi
  done

  for row in "$@"; do
    local key="${row%%;*}"
    local msg="${row##*;}"
    local lmsg="${#msg}"
    msg="$(printf "%*s" "$((lkey + 4 + lmsg))" "$msg" | "$FMT")"
    printf "  %b%-*s%b  %s\n" "$GREEN" "$lkey" "$key" "$RESET" "${msg#"${msg%%[![:space:]]*}"}"
  done
}

function hoptions() {
  local lflag=0
  local lval=0
  for row in "$@"; do
    row="${row#*;}"
    local flag="${row%%;*}"
    row="${row#*;}"
    local val="${row%%;*}"
    if [ ${#flag} -gt $lflag ]; then
      lflag=${#flag}
    fi
    if [ ${#val} -gt $lval ]; then
      lval=${#val}
    fi
  done

  for row in "$@"; do
    local short="${row%%;*}"
    row="${row#*;}"
    local long="${row%%;*}"
    row="${row#*;}"
    local val="${row%%;*}"
    local msg="${row#*;}"
    local lmsg="${#msg}"
    local sep="  "
    if [ -n "$short" ] && [ -n "$long" ]; then sep=", "; fi
    msg="$(printf "%*s" "$((lflag + lval + 10 + lmsg))" "$msg" | "$FMT")"
    printf "  %b%2s%s%-*s  %-*s%b  %s\n" "$GREEN" "$short" "$sep" "$lflag" "$long" "$lval" "$val" "$RESET" "${msg#"${msg%%[![:space:]]*}"}"
  done
}

# }}}
# --- Main Function --- {{{

_arg_command="list"

function todo_version() {
  printf "%s v%s\n" "$0" "$TODO_VERSION"
}

function todo_help() {
  COMMANDS=()
  if [ -d "$SCRIPT_DIR/todo" ]; then
    for file in "$SCRIPT_DIR"/todo/*.sh; do
      if [ "$file" = "$SCRIPT_DIR/todo/*.sh" ]; then continue; fi
      local cmd="$(basename "${file%.sh}")"
      source "$file"
      COMMANDS+=("$cmd;$("todo_short_${cmd}")")
    done
  fi

  husage "" "COMMAND..."
  hlong "A personal todo list task manager, for tracking, organizing, and prioritizing tasks."
  hsection "Options"
  hoptions \
    "-h;--help;;Show this help message and exit." \
    ";--version;;Show the version information and exit."
  hsection "Commands"
  harguments \
    "add;Add a new task to the task list." \
    "delete;Prementently delete a task." \
    "done;Mark and open task as completed." \
    "edit;Open the todo list in a text editor." \
    "list;List the tasks in the todo list." \
    "pri;Update the prioritization of a task."

  if [ "${#COMMANDS[@]}" -ne 0 ]; then
    hsection "Extensions"
    harguments "${COMMANDS[@]}"
  fi
}

function todo_parse() {
  while test $# -gt 0; do
    local key="$1"
    case "$key" in
    -h | --help)
      todo_help
      exit 0
      ;;
    -h*)
      todo_help
      exit 0
      ;;
    --version)
      todo_version
      exit 0
      ;;
    add | new)
      _arg_command="add"
      shift
      todo_parse_add "$@"
      break
      ;;
    rm | del | delete)
      _arg_command="delete"
      shift
      todo_parse_delete "$@"
      break
      ;;
    ls | list)
      _arg_command="list"
      shift
      todo_parse_list "$@"
      break
      ;;
    *)
      if [ -f "$SCRIPT_DIR/todo/$key.sh" ]; then
        _arg_command="$key"
        source "$SCRIPT_DIR/todo/$key.sh"
        shift
        "todo_parse_$key" "$@"
        break
      fi
      todo_help
      printf "%bGot an unexpected argument '%s'%b\n" "$RED" "$key" "$RESET"
      exit 1
      ;;
    esac
    shift
  done
}

# }}}
# --- Add Command --- {{{

_arg_add_due=""
_arg_add_pri=""
_arg_add_tag=()
_arg_add_project=()
_arg_add_description=()

function todo_help_add() {
  husage "add" "DESCRIPTION..."
  hlong "Add a new task to the current task list."
  hsection "Arguments"
  harguments \
    "DESCRIPTION;The description for the new task. This can include tags, projects, or key/value pairs."
  hsection "Options"
  hoptions \
    "-h;--help;;Show this help message and exit." \
    "-p;--pri;CHARACTER;The priority for the new task." \
    "-t;--tag;STRING;Set a tag for the new task." \
    "-P;--project;STRING;Set a project for the new task." \
    "-d;--due;DATE;The due date to set for the new task." \
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
    -d | --due)
      if [ $# -lt 2 ]; then
        printf "%bMissing value for the optional argument '%s'%b\n" "$YELLOW" "$key" "$RESET"
        exit 1
      fi
      _arg_add_due="$(pdate "$2" "due")" || exit 1
      shift
      ;;
    --due=*)
      _arg_add_due="$(pdate "${key##--due=}" "due")" || exit 1
      ;;
    -d*)
      _arg_add_due="$(pdate "${key##-d}" "due")" || exit 1
      ;;
    -p | --pri)
      if [ $# -lt 2 ]; then
        printf "%bMissing value for the optional argument '%s'%b\n" "$YELLOW" "$key" "$RESET"
        exit 1
      fi
      _arg_add_pri="$(pchar "$2" "pri")" || exit 1
      shift
      ;;
    --pri=*)
      _arg_add_pri="$(pchar "${key##--pri=}" "pri")" || exit 1
      ;;
    -p*)
      _arg_add_pri="$(pchar "${key##-p}" "pri")" || exit 1
      ;;
    -t | --tag)
      if [ $# -lt 2 ]; then
        printf "%bMissing value for the optional argument '%s'%b\n" "$YELLOW" "$key" "$RESET"
        exit 1
      fi
      _arg_add_tag+=("$2")
      shift
      ;;
    --tag=*)
      _arg_add_tag+=("${key##--tag=}")
      ;;
    -t*)
      _arg_add_tag+=("${key##-t}")
      ;;
    -P | --project)
      if [ $# -lt 2 ]; then
        printf "%bMissing value for the optional argument '%s'%b\n" "$YELLOW" "$key" "$RESET"
        exit 1
      fi
      _arg_add_project+=("$2")
      shift
      ;;
    --project=*)
      _arg_add_project+=("${key##--project=}")
      ;;
    -P*)
      _arg_add_project+=("${key##-P}")
      ;;
    --*=*)
      key="${key#--}"
      _arg_add_description+=("${key%%=*}:${key##*=}")
      ;;
    --*)
      if [ $# -lt 2 ]; then
        printf "%bMissing value for the optional argument '%s'%b\n" "$YELLOW" "$key" "$RESET"
        exit 1
      fi
      _arg_add_description+=("${key#--}:${2}")
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
  local task=";$(date +%Y-%m-%d);"
  for word in "${_arg_add_description[@]}"; do
    if [ "${word::4}" == "due:" ]; then
      task="${task}due:$(pdate "${word:4}" "due") "
    else
      task="$task$word "
    fi
  done
  task="${task% }"

  if [ -n "$_arg_add_pri" ]; then
    task=";$_arg_add_pri;$task"
  else
    task=";;$task"
  fi

  for tag in "${_arg_add_tag[@]}"; do task="$task @$tag"; done
  for proj in "${_arg_add_project[@]}"; do task="$task +$proj"; done
  if [ -n "$_arg_add_due" ]; then
    task="$task due:$_arg_add_due"
  fi

  if ! [ -d "$TODO_DIR" ]; then
    mkdir -p "$TODO_DIR"
  fi

  echo "$task"

  write_task "$task" >>"$TODO_DIR/todo.txt"
  echo "Created new task: $(fmt_task "$task")"
}

# }}}
# --- Delete Command --- {{{

_arg_delete_force=false
_arg_delete_id=()

function todo_help_delete() {
  husage "delete" "ID..."
  hlong "Permenently delete a task."
  hsection "Arguments"
  harguments \
    "ID;The IDs of the tasks to be deleted"
  hsection "Options"
  hoptions \
    "-h;--help;;Show this help message and exit." \
    "-f;--force;;Delete the tasks without user confirmation."
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
      _arg_delete_id+=("$(pint "$key" "ID")")
      ;;
    esac
    shift
  done

  if [ ${#_arg_delete_id[@]} -eq 0 ]; then
    todo_help_delete
    printf "%bMissing required argument 'ID'%b\n" "$RED" "$RESET"
    exit 1
  fi
}

function todo_delete() {
  IFS=$'\n' read -r -a sorted <<<"$(sort -r <<<"${_arg_delete_id[*]}")"

  for id in "${sorted[@]}"; do
    match="$(find_task "$id")"
    if [ -z "$match" ]; then continue; fi

    local id="${match%%:*}"
    match="${match#*:}"
    local path="${match%%:*}"
    local task="${match#*:}"

    if [ "$_arg_delete_force" == true ] || pmt_confirm "Are you sure you want to delete: $(fmt_task "$task")"; then
      "$SED" -i "${id}d" "${path}"
      echo "Deleted task: $(fmt_task "$task")"
    fi

  done
}

# }}}
# --- List Command --- {{{

_arg_list_all=false
_arg_list_filter=()

function todo_help_list() {
  husage "list" "FILTER..."
  hlong "List tasks in the todo lists."
  hsection "Arguments"
  harguments \
    "FILTER;A filter expression to filter the tasks included in the list."
  hsection "Options"
  hoptions \
    "-h;--help;;Show this help message and exit." \
    "-a;--all;;Include already completed tasks in the list."
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
  local tasks="$(get_tasks "${_arg_list_filter[*]}" "$_arg_list_all")"

  table=""
  while IFS= read -r task; do
    local id="${task%%;*}"
    task="${task#*;}"
    split_task "$task"
    table="$table${id};\
$(fmt_state "$state" "$(get_kvp "state" "$task")");\
$(color_pri "$pri")$pri${RESET};\
${DATE_COLOR}$done${RESET};\
${DATE_COLOR}$created${RESET};\
${KVP_COLOR}$(get_kvp "due" "$task")${RESET};\
$(fmt_description "$description" "due state");\
$(calc_urgency "$task")\n"
  done < <(printf "%b\n" "$tasks")

  sorted="$(echo -en "$table" | sort -bnrk 8 -t ';')"
  table=""

  while IFS= read -r task; do
    local urg="${task##*;}"
    task="${task%;*}"
    table="$table$task;$(fmt_urgency "$urg")\n"
  done < <(printf "%b\n" "$sorted")

  local headers="${BOLD}Id${RESET},\
${BOLD}S${RESET},\
${BOLD}Pri${RESET},\
${BOLD}Done${RESET},\
${BOLD}Created${RESET},\
${BOLD}Due${RESET},\
${BOLD}Description${RESET},\
${BOLD}Urg${RESET}"

  echo -en "$table" | "$COLUMN" -ts';' -N "$(printf "%b" "$headers")"
}

# }}}

todo_parse "$@"
"todo_$_arg_command"
exit $?
