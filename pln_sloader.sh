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
    echo "Try \`$progname --help' for more information." >&2
}

# Print program help info to stderr
# help_info()
help_info()
{
    echo "usage: $progname url [ outdir=. ]" >&2
}

load_screenshots()
{
    local url="$1"
    local odir
    local fname_topic=topic.temp
    local fname_parsed=parsed.temp
    local fname_converted=converted.temp
    local fname_run=run.temp

    if [ -z "$2" ]; then
        odir="."
    else
        odir="$2"
        [ -d "$odir" ] || mkdir "$odir"
    fi
    loader_load_topic_page "$url" "$odir/$fname_topic"
    loader_parse_topic_page "$odir/$fname_topic" "$odir/$fname_parsed"
    loader_convert_data "$odir/$fname_parsed" "$odir/$fname_converted"
    loader_make_run "$odir/$fname_converted" "$odir/$fname_run"
    loader_run "$odir/$fname_run"
    loader_clean_all \
        "$odir/$fname_topic" \
        "$odir/$fname_parsed" \
        "$odir/$fname_converted" \
        "$odir/$fname_run"
    return 0
}

loader_load_topic_page()
{
    local url="$1"
    local ofname="$2"

    echo "loader_load_topic_page $url $ofname"
    cp topic.temp.template $ofname
    return 0
}

loader_parse_topic_page()
{
    local ifname="$1"
    local ofname="$2"

    echo "loader_parse_topic_page $ifname $ofname"
    cp parsed.temp.template $ofname
    return 0
}

loader_convert_data()
{
    local ifname="$1"
    local ofname="$2"

    echo "loader_convert_data $ifname $ofname"
    cp converted.temp.template $ofname
    return 0
}

loader_make_run()
{
    local ifname="$1"
    local ofname="$2"

    echo "loader_make_run $ifname $ofname"
    cp run.temp.template $ofname
    return 0
}

loader_run()
{
    local ifname="$1"

    echo "loader_run $ifname"
    echo "Loaded files"
    return 0
}

loader_clean_all()
{
    local fname_topic="$1"
    local fname_parsed="$2"
    local fname_converted="$3"
    local fname_run="$4"

    echo "loader_clean_all $fname_topic $fname_parsed $fname_converted $fname_run"
    echo "Removed temporary files"
    return 0
}

main()
{
    case $# in
      0)
        usage
        return 1
        ;;
      1)
        [ "$1" = "--help" ] && {
            help_info
            return 1
        }
        usage
        load_screenshots "$1" || return 1
        ;;
      2)
        usage
        load_screenshots "$1" "$2" || return 1
        ;;
      *)
        error "unknown arglist: \"$*\""
        return 1
        ;;
    esac
    return 0
}

main "$@" || exit 1

exit 0
