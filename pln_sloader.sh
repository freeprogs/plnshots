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
    local odir="$2"
    local fname_topic=topic.temp
    local fname_parsed=parsed.temp
    local fname_converted=converted.temp
    local fname_run=run.temp

    [ -d "$odir" ] || mkdir "$odir"
    loader_load_topic_page "$url" "$odir/$fname_topic" || {
        error "Can't load the topic page from $url."
        return 1
    }
    loader_parse_topic_page "$odir/$fname_topic" "$odir/$fname_parsed" || {
        error "Can't parse the topic page."
        return 1
    }
    loader_convert_data "$odir/$fname_parsed" "$odir/$fname_converted" || {
        error "Can't convert the parsed data."
        return 1
    }
    loader_make_run "$odir/$fname_converted" "$odir/$fname_run" "$odir" || {
        error "Can't make the run file."
        return 1
    }
    loader_run "$odir/$fname_run" || {
        error "Can't run the run file."
        return 1
    }
    loader_clean_all \
        "$odir/$fname_topic" \
        "$odir/$fname_parsed" \
        "$odir/$fname_converted" \
        "$odir/$fname_run" || {
        error "Can't clean temporary files."
        return 1
    }
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
    local fields field1 field2 field3 field4

    [ -e "$ofname" ] && rm -f "$ofname"
    cat "$ifname" | while read line; do
        fields=($line)
        field1=${fields[0]}
        field2=${fields[1]}
        field3=$(echo "${fields[2]}" | converter_convert_url)
        field4=$(echo "${fields[3]}" | converter_convert_name)
        echo "$field1 $field2 $field3 $field4" >>"$ofname"
    done || return 1
    return 0
}

converter_convert_url()
{
    cat
}

converter_convert_name()
{
    sed 's/$/_nameconverted/'
}

loader_make_run()
{
    local ifname="$1"
    local ofname="$2"
    local odir="$3"

    awk -v odir="$odir" '
{
    printf "echo wget -c %s %s/%03d_%03d_%s\n",
        $3, odir, $1, $2, $4
}
    ' "$ifname" >"$ofname" || return 1
    return 0
}

loader_run()
{
    local ifname="$1"

    source "$ifname" || return 1
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
        load_screenshots "$1" "." || return 1
        msg "Files loaded from $1 to the current directory."
        ;;
      2)
        usage
        load_screenshots "$1" "$2" || return 1
        msg "Files loaded from $1 to directory $2."
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
