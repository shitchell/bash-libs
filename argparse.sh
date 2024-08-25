## WIP
#
# This module provides functions for parsing command line arguments.
# Inspired heavily by the argparse module in the Python standard library:
# https://docs.python.org/3/library/argparse.html
#
# Common options:
#   -h/--help <help text>   Help text to display for the option
#   -r/--required           Show an exception if this option/argument is not provided
#   -d/--default <value>    Default value for the option/argument
#   -n/--nargs <*|+|?|N>    Number of arguments for the argument
#                             * - zero or more arguments
#                             + - one or more arguments
#                             ? - zero or one argument
#                             N - exactly N arguments
#
# Arguments are divided into three categories:
#   - Flags
#     Arguments that start with a dash (-) or double dash (--) and accept no
#     parameters. Their presence indicates a boolean value.
#   - Parameters
#     Arguments that start with a dash (-) or double dash (--) and accept a
#     parameter. They can be optional or required.
#   - Positional
#     Arguments that do not start with a dash (-) or double dash (--). Their
#     order is important, and they can be optional or required.
#
# Functions:
#   add_flag <short_name/long_name> [options]
#   add_positional <name> [options]
#   add_parameter <short_name/long_name> [options]
#   add_argument_group <name> <description>
#   set_usage <usage text>
#   set_epilog <epilog text>
#   set_help <help text>
#   set_prog_name <program name>
#   parse_args <argv>
#
# Extended usage:
#   `add_subcommand`:
#   This function is used to add a subcommand to the parser. It takes the name
#   of the subcommand as the first argument and an optional help text as the
#   second argument. Subsequent calls to `add_flag`, `add_positional`, and
#   `add_parameter` can optionally specify the subcommand to which they belong.
#
#     usage:
#       add_subcommand <name> [-h|--help <text>]
#
#     examples:
#       add_subcommand "list"
#       => {prog} list
#       add_subcommand "install" --help "Install a package"
#       => {prog} install
#
#   `add_flag`:
#   This function is used to add a flag to the parser. It takes the short
#   name and long name of the option as the first argument. The option can be
#   required or optional, and can store a value in a variable. The option can
#   also have a default value and a help text. Every call to this function will
#   create two options: a positive option (e.g. --verbose) and a negative option
#   (e.g. --no-verbose). If a variable name is not specified by `--store`, the
#   option's long name with dashes replaced by underscores will be used (e.g.:
#   --verbose -> verbose).
#
#     usage:
#       add_flag <short_name/long_name> [-r|--required] [-d|--default <value>]
#                  [-s|--store <var_name>] [-C|--subcommand <name>]
#                  [-h|--help <text>]
#
#     examples:
#       add_flag "-v/--verbose" --default false --help "verbose output"
#       => {prog} -v, {prog} --verbose
#       => {prog} --no-v, {prog} --no-verbose
#
#       add_flag "--force" --help "force the operation"
#       => {prog} --force, {prog} --no-force
#
#       add_flag "-a/--all" --subcommand "list" --store "list_all" \
#           --help "list all items"
#       => {prog} list -a, {prog} list --all
#       => {prog} list --no-a, {prog} list --no-all
#
#   `add_parameter`:
#
#
#     usage:
#       add_parameter <short_name/long_name> [-r|--required]
#                     [-d|--default <value>] [-s|--store <var_name>]
#                     [-C|--subcommand <name>] [-f|--flag] [-n|--nargs <+|*|int>] [-c|--choices <value1,value2,...>] [--type <type>] [-c/--subcommand <name>] [--help <text>]
#   add_positional <name> [--type <type>] [-n|--nargs <+|*|int>] [-d|--default <value>] [-c|--choices <value1,value2,...>] [-F|--follows <separator>] [-r|--required] [--help <text>]
#   parse_args <argv>
#
# Types:
#   int - integer
#   float - floating point number
#   bool - boolean ("true", "false", 0, 1)
#   string - string
#   file - file
#   dir - directory
#   path - path (file or directory)
#
# Type specific options:
#   int|float:
#     --negative-only - only allow negative values
#     --positive-only - only allow positive values
#     --min <value> - minimum value
#     --max <value> - maximum value
#   file|dir|path:
#     --exists - only allow existing files or directories
#     --no-exists - only allow non-existing files or directories
#     --readable - only allow readable files or directories
#     --writable - only allow writable files or directories
#     --executable - only allow executable files or directories
#
# Example:
#   source argparse.sh
#   add_option "-f" "--force" --default false \
#     --help "Force the operation"
#   add_option "-v" "--verbose" --default false --store verbosity \
#     --help "Verbose output"
#   add_option "-q" "--quiet" --default true --store verbosity \
#     --help "Quiet output"
#   add_argument "-f" "--file" --type array --store filepaths \
#     --help "File to operate on"
#   add_positional "filepaths" --type filepath --store command --follows "--" --default "" \
#     --help "Filepaths to operate on"

