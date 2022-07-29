# TODO.sh

A local todo list manager for organizing and prioritizing tasks.

## File Format

todo.sh makes use of the format specified by [todo.txt](https://github.com/todotxt/todo.txt). This file format is a plain text format which makes it easy for users to read and edit even without todo.sh installed.

Each task is written on a single line, the format of these lines in the file are:
```
[x] [(A-Z)] [COMPLETED_DATE] CREATED_DATE TASK_DESCRIPTION...
```
Where the optional `x` at the begining of the line denotes the task as being completed. The optional `(A-Z)` denotes the prioritization of the task, where `A` indicates a task with the highest priority. In all views the tasks with a higher priority _always_ display first. If the task has been completed then the date the task was completed is required next, in the format `YYYY-MM-DD`. Then the next value is the creation date of the task, also in the format `YYYY-MM-DD`. The rest of the line after the creation date is the description of the task.

The description of the task can include some additional attributes for the task. A word starting with `@` are considered context tags for the task. Words starting with `+` will be considered project tags for the task. Finally arbitrary extra data is possible using key/value pairs with the format `key:value`. These additional attributes can appear anywhere in the task description.

Putting those together here are some example tasks:

```
x (A) 2022-01-01 2021-01-01 some description for the @task for +todo.sh due:2023-01-01
```

### Special Keys

Some key value pairs are specially recognized by todo.sh, and allow todo.sh to do additional processing and formatting on the tasks with these keys.

- **due**: This value is required to be a date with the format `YYYY-MM-DD` and is
  used to specify the due date for the task.
- **state**: This value is able to specify the state of the task beyond just open and completed. By using this value todo.sh can organize the tasks in a kanban board.
