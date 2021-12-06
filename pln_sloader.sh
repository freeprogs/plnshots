#!/bin/bash

# This script loads screenshots from the first post of a topic on site
# https://pornolab.net

progname=`basename $0`

# Print an error message to stderr
# error(str)
error()
{
    echo "error: $progname: $1" >&2
}

# Print an message to stdout
# msg(str)
msg()
{
    echo "$progname: $1"
}

# Print program usage to stderr
# usage()
usage()
{
    echo "usage: $progname " >&2
}

main()
{
    case $# in
      0) usage; return 1;;
      1)  "$1" && return 0;;
      2)  "$1" "$2" && return 0;;
      *) error "unknown arglist: "$*""; return 1;;
    esac
}

main "$@" || exit 1

exit 0
