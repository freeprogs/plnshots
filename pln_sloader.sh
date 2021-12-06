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
    echo "usage: $progname url [ outdir=. ]" >&2
}

load_screenshots()
{
    local url="$1"
    local fname_topic=topic.temp
    local fname_parsed=parsed.temp
    local fname_converted=converted.temp
    local fname_run=run.temp

    loader_load_topic_page "$url" "$fname_topic"
    loader_parse_topic_page "$fname_topic" "$fname_parsed"
    loader_convert_data "$fname_parsed" "$fname_converted"
    loader_make_run "$fname_converted" "$fname_run"
    loader_run "$fname_run"
    loader_clean_all \
        "$fname_topic" \
        "$fname_parsed" \
        "$fname_converted" \
        "$fname_run"
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
      0) usage; return 1;;
      1) load_screenshots "$1" && return 0;;
      2) load_screenshots "$1" "$2" && return 0;;
      *) error "unknown arglist: \"$*\""; return 1;;
    esac
    return 1
}

main "$@" || exit 1

exit 0
