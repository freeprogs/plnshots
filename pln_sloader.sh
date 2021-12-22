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
    local fname_topic="topic.temp"
    local fname_parsed="parsed.temp"
    local fname_converted="converted.temp"
    local fname_report="report.temp"
    local fname_run="run.temp"

    [ -d "$odir" ] || mkdir "$odir"
    loader_load_topic_page "$url" "$odir/$fname_topic" || {
        error "Can't load the topic page from $url."
        return 1
    }
    loader_parse_topic_page "$odir/$fname_topic" "$odir/$fname_parsed" "$odir" || {
        error "Can't parse the topic page."
        return 1
    }
    loader_convert_data "$odir/$fname_parsed" "$odir/$fname_converted" || {
        error "Can't convert the parsed data."
        return 1
    }
    loader_make_report "$odir/$fname_converted" "$odir/$fname_report" || {
        error "Can't make the report file."
        return 1
    }
    loader_make_run "$odir/$fname_converted" "$odir/$fname_run" "$odir" || {
        error "Can't make the run file."
        return 1
    }
    loader_run "$odir/$fname_run" "$odir/$fname_report" || {
        error "Can't run the run file."
        return 1
    }
    loader_clean_all \
        "$odir/$fname_topic" \
        "$odir/$fname_parsed" \
        "$odir/$fname_converted" \
        "$odir/$fname_report" \
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
    local proxy="localhost:9050"

    msg "$(echo $url | reporter_wrap_curl_start)"
    curl -s \
         --preproxy "socks4://$proxy" \
         "$url" \
         -o "$ofname" || return 1
    msg "$(echo $url | reporter_wrap_curl_end)"
    return 0
}

loader_parse_topic_page()
{
    local ifname="$1"
    local ofname="$2"
    local odir="$3"
    local fname_recoded="${ifname}.recoded.temp"
    local fname_t="$odir/ctrees.temp"
    local fname_tfi="$odir/ctrees_fi.temp"
    local fname_tfico="$odir/ctrees_fico.temp"
    local fname_tficora="$odir/ctrees_ficora.temp"

    pagehand_reencode_cp1251_utf8 "$ifname" "$fname_recoded" || {
        error "Can't reencode topic page from cp1251 to utf-8."
        return 1
    }
    topichand_extract_cuttrees "$fname_recoded" "$fname_t" || {
        error "Can't extract cut trees from topic."
        return 1
    }
    topichand_filter_cuttrees "$fname_t" "$fname_tfi" || {
        error "Can't filter extracted cut trees."
        return 1
    }
    topichand_convert_cuttrees "$fname_tfi" "$fname_tfico" || {
        error "Can't convert filtered cut trees."
        return 1
    }
    topichand_convert_cuttrees_to_rawdata "$fname_tfico" "$fname_tficora" || {
        error "Can't convert converted cut trees to raw data."
        return 1
    }
    topichand_convert_rawdata_to_parsedata "$fname_tficora" "$ofname" || {
        error "Can't convert raw data to parsed data."
        return 1
    }
    topichand_clean_all \
        "$fname_recoded" \
        "$fname_t" \
        "$fname_tfi" \
        "$fname_tfico" \
        "$fname_tficora" || {
        error "Can't clean files after building parsed data from topic."
        return 1
    }
    return 0
}

pagehand_reencode_cp1251_utf8()
{
    local ifname="$1"
    local ofname="$2"
    local tfname="${ifname}.reencode_cp1251_utf8.tmp"
    local ienc="cp1251"
    local oenc="utf-8"

    iconv -f "$ienc" -t "$oenc" "$ifname" -o "$tfname" && \
        mv "$tfname" "$ofname" || return 1
    return 0
}

topichand_extract_cuttrees()
{
    local ifname="$1"
    local ofname="$2"
    local tfname="${ifname}.extracted.tmp"

    echo -n >"$tfname"
    if extractor_extract_cuttree_direct "$ifname" "$tfname" && \
       extractor_test_extracted_cuttree "$tfname"; then
        mv "$tfname" "$ofname" || return 1
        return 0
    fi
    echo -n >"$tfname"
    if extractor_extract_cuttree_wrapped "$ifname" "$tfname" && \
       extractor_test_extracted_cuttree "$tfname"; then
        mv "$tfname" "$ofname" || return 1
        return 0
    fi
    error "Can't extract cuttree by the direct method."
    error "Can't extract cuttree by the wrapped method."
    return 1
}

extractor_extract_cuttree_direct()
{
    local ifname="$1"
    local ofname="$2"
    local xpathreq

    xpathreq='..//div[@class="post-user-message"]'\
'/div[@class="sp-wrap"]'

    echo -n >"$ofname"

    cat "$ifname" | python3 -c '
import sys
import lxml.html

doc = lxml.html.fromstring(sys.stdin.read())
print("<html>\n<body>")
nodes = doc.xpath(r"""'"$xpathreq"'""")
for i in nodes:
    print(lxml.html.tostring(i, encoding="unicode", pretty_print=True))
print("</body>\n</html>")
'   >"$ofname" || return 1
    return 0
}

extractor_extract_cuttree_wrapped()
{
    local ifname="$1"
    local ofname="$2"
    local xpathreq

    xpathreq='..//div[@class="post-user-message"]'\
'/div[@class="post-align"]/div[@class="sp-wrap"]'

    echo -n >"$ofname"

    cat "$ifname" | python3 -c '
import sys
import lxml.html

doc = lxml.html.fromstring(sys.stdin.read())
print("<html>\n<body>")
nodes = doc.xpath(r"""'"$xpathreq"'""")
for i in nodes:
    print(lxml.html.tostring(i, encoding="unicode", pretty_print=True))
print("</body>\n</html>")
'   >"$ofname" || return 1
    return 0
}

extractor_test_extracted_cuttree()
{
    local ifname="$1"

    htmlpagehand_is_empty "$ifname" && return 1
    return 0
}

htmlpagehand_is_empty()
{
    local ifname="$1"
    local text

    text=$(echo -e "<html>\n<body>\n</body>\n</html>")
    [ $(cat "$ifname" | wc -l) -eq 4 ] || return 1
    [ "$(cat "$ifname")" = "$text" ] || return 1
    return 0
}

topichand_filter_cuttrees()
{
    local ifname="$1"
    local ofname="$2"
    local tfname_s1="${ifname}.filtered.stage1.tmp"
    local tfname_s2="${ifname}.filtered.stage2.tmp"

    echo -n >"$tfname_s1"
    if selector_filter_cuttrees_varimg "$ifname" "$tfname_s1" && \
       selector_test_filtered_cuttrees "$tfname_s1"; then
        :
    else
        error "Can't filter cut trees by var with image."
        return 1
    fi
    echo -n >"$tfname_s2"
    if selector_filter_cuttrees_sitefpo "$tfname_s1" "$tfname_s2" && \
       selector_test_filtered_cuttrees "$tfname_s2"; then
        :
    else
        error "Can't filter cut trees by the fpo site."
        return 1
    fi
    rm -f "$tfname_s1" || return 1
    mv "$tfname_s2" "$ofname" || return 1
    return 0
}

selector_filter_cuttrees_varimg()
{
    local ifname="$1"
    local ofname="$2"
    local xpathreq1 xpathreq2

    xpathreq1='./body/div'
    xpathreq2='.//var[@class="postImg"]'

    echo -n >"$ofname"

    cat "$ifname" | python3 -c '
import sys
import lxml.html

doc = lxml.html.fromstring(sys.stdin.read())
print("<html>\n<body>")
outer_nodes = doc.xpath(r"""'"$xpathreq1"'""")
for i in outer_nodes:
    inner_nodes = i.xpath(r"""'"$xpathreq2"'""")
    if inner_nodes:
        text = lxml.html.tostring(
            i, encoding="unicode", pretty_print=True)
        print(text)
print("</body>\n</html>")
'   >"$ofname" || return 1
    return 0
}

selector_filter_cuttrees_sitefpo()
{
    local ifname="$1"
    local ofname="$2"
    local xpathreq1 xpathreq2

    xpathreq1='./body/div'
    xpathreq2='.//var[contains(@title, "fastpic.org")]'

    echo -n >"$ofname"

    cat "$ifname" | python3 -c '
import sys
import lxml.html

doc = lxml.html.fromstring(sys.stdin.read())
print("<html>\n<body>")
outer_nodes = doc.xpath(r"""'"$xpathreq1"'""")
for i in outer_nodes:
    inner_nodes = i.xpath(r"""'"$xpathreq2"'""")
    if inner_nodes:
        text = lxml.html.tostring(
            i, encoding="unicode", pretty_print=True)
        print(text)
print("</body>\n</html>")
'   >"$ofname" || return 1
    return 0
}

selector_test_filtered_cuttrees()
{
    local ifname="$1"

    htmlpagehand_is_empty "$ifname" && return 1
    return 0
}

topichand_convert_cuttrees()
{
    local ifname="$1"
    local ofname="$2"
    local xpathreq1 xpathreq2
    local urlname_default urltext_default

    xpathreq1='./body/div'
    xpathreq2='.//div/a/var[@class="postImg"]'

    echo -n >"$ofname"
    cat "$ifname" | python3 -c '
import sys
import lxml.html

doc = lxml.html.fromstring(sys.stdin.read())
print("<html>\n<body>")
outer_nodes = doc.xpath(r"""'"$xpathreq1"'""")
for i in outer_nodes:
    inner_nodes = i.xpath(r"""'"$xpathreq2"'""")
    for j in inner_nodes:
        vara = j.getparent()
        vara.addprevious(j)
        vara.text = "var"
    text = lxml.html.tostring(i, encoding="unicode", pretty_print=True)
    print(text)
print("</body>\n</html>")
'   >"$ofname"

    mv "$ofname" "$ifname"

    xpathreq1='./body/div'
    xpathreq2='./div/var[@class="postImg"]'
    urlname_default="screenshot"
    urltext_default="description"

    echo -n >"$ofname"
    cat "$ifname" | python3 -c '
import sys
import lxml.html

doc = lxml.html.fromstring(sys.stdin.read())
print("<html>\n<body>")
outer_nodes = doc.xpath(r"""'"$xpathreq1"'""")
for i in outer_nodes:
    inner_nodes = i.xpath(r"""'"$xpathreq2"'""")
    if inner_nodes:
        new_item = lxml.html.Element("div")
        new_item.attrib["class"] = "sp-wrap"
        new_item.text = "\n"
        new_item_sub1 = lxml.etree.SubElement(new_item, "div")
        new_item_sub1.attrib["class"] = "sp-body"
        new_item_sub1.attrib["title"] = i[0].attrib["title"]
        new_item_sub1.text = "\n"
        new_item_sub1_sub1 = lxml.etree.SubElement(new_item_sub1, "h3")
        new_item_sub1_sub1.attrib["class"] = "sp-title"
        new_item_sub1_sub1.text = i[0][0].text
        for item in inner_nodes:
            new_item_w = lxml.html.Element("div")
            new_item_w.attrib["class"] = "sp-wrap"
            new_item_w.text = "\n"
            new_item_w_sub1 = lxml.etree.SubElement(new_item_w, "div")
            new_item_w_sub1.attrib["class"] = "sp-body"
            new_item_w_sub1.attrib["title"] = "'"$urlname_default"'"
            new_item_w_sub1.text = "\n"
            new_item_w_sub1_sub1 = lxml.etree.SubElement(new_item_w_sub1, "h3")
            new_item_w_sub1_sub1.attrib["class"] = "sp-title"
            new_item_w_sub1_sub1.text = "'"$urlname_default"'"
            new_item_w_sub1_sub2 = lxml.etree.SubElement(new_item_w_sub1, "span")
            new_item_w_sub1_sub2.attrib["class"] = "post-b"
            new_item_w_sub1_sub2.text = "'"$urltext_default"'"
            new_item_w_sub1.append(item)
            new_item_sub1.append(new_item_w)
        text = lxml.html.tostring(new_item, encoding="unicode", pretty_print=True)
        print(text)
    else:
        text = lxml.html.tostring(i, encoding="unicode", pretty_print=True)
        print(text)
print("</body>\n</html>")
'   >"$ofname"

    mv "$ofname" "$ifname"

    xpathreq1='./body/div'
    xpathreq2='./div/div//div/div/var[@class="postImg"]/../..'

    echo -n >"$ofname"
    cat "$ifname" | python3 -c '
import sys
import lxml.html

doc = lxml.html.fromstring(sys.stdin.read())
print("<html>\n<body>")
outer_nodes = doc.xpath(r"""'"$xpathreq1"'""")
for i in outer_nodes:
    inner_nodes = i.xpath(r"""'"$xpathreq2"'""")
    if inner_nodes:
        new_item = lxml.html.Element("div")
        new_item.attrib["class"] = "sp-wrap"
        new_item.text = "\n"
        new_item_sub1 = lxml.etree.SubElement(new_item, "div")
        new_item_sub1.attrib["class"] = "sp-body"
        new_item_sub1.attrib["title"] = i[0].attrib["title"]
        new_item_sub1.text = "\n"
        new_item_sub1_sub1 = lxml.etree.SubElement(new_item_sub1, "h3")
        new_item_sub1_sub1.attrib["class"] = "sp-title"
        new_item_sub1_sub1.text = i[0][0].text
        for item in inner_nodes:
            new_item_sub1.append(item)
        text = lxml.html.tostring(new_item, encoding="unicode", pretty_print=True)
        print(text)
    else:
        text = lxml.html.tostring(i, encoding="unicode", pretty_print=True)
        print(text)
print("</body>\n</html>")
'   >"$ofname"

    [ $(wc -l "$ofname" | cut -d' ' -f1) -gt 4 ] && return 0
    return 1
}

topichand_convert_cuttrees_to_rawdata()
{
    local ifname="$1"
    local ofname="$2"
    local xpathreq1 xpathreq2

    xpathreq1='./body/div'
    xpathreq2='.//div/var[@class="postImg"]'

    echo -n >"$ofname"
    cat "$ifname" | python3 -c '
import sys
import lxml.html

doc = lxml.html.fromstring(sys.stdin.read())
outer_nodes = doc.xpath(r"""'"$xpathreq1"'""")
for i in outer_nodes:
    outer_name = i[0].attrib["title"]
    outer_otext = "\n{}".format(outer_name)
    print(outer_otext)
    inner_nodes = i.xpath(r"""'"$xpathreq2"'""")
    for j in inner_nodes:
        inner_name = j.getparent().attrib["title"]
        inner_url = j.attrib["title"]
        inner_otext = "{} {}".format(inner_url, inner_name)
        print(inner_otext)
'   >"$ofname"

    [ -n "$(cat $ofname)" ] && return 0
    return 1
}

topichand_convert_rawdata_to_parsedata()
{
    local ifname="$1"
    local ofname="$2"

    cat "$ifname" | awk '
{
    if(state == 0) {
        if(/^$/)
            state = 1
    } else if (state == 1) {
        nblock++
        state = 2
    } else if (state == 2) {
        nurl++
        if(/^$/) {
            nurl = 0
            state = 1
        } else {
            url = $1
            urlname = ""
            for (i = 2; i <= NF; i++) {
                urlname = urlname $i (i < NF ? " " : "")
            }
            print nblock, nurl, url, urlname
        }
    }
}
'   >"$ofname"
    [ -n "$(cat $ofname)" ] && return 0
    return 1
}

topichand_clean_all()
{
    local fname_recoded="$1"
    local fname_t="$2"
    local fname_tfi="$3"
    local fname_tfico="$4"
    local fname_tficora="$5"

    rm -f "$fname_recoded" \
       "$fname_t" \
       "$fname_tfi" \
       "$fname_tfico" \
       "$fname_tficora" || return 1
    return 0
}

loader_convert_data()
{
    local ifname="$1"
    local ofname="$2"
    local fields field1 field2 field3 field4

    [ -e "$ofname" ] && rm -f "$ofname"
    cat "$ifname" | while read line; do
        fields=()
        fields[0]=$(echo "$line" | linehand_getfield "1")
        fields[1]=$(echo "$line" | linehand_getfield "2")
        fields[2]=$(echo "$line" | linehand_getfield "3")
        fields[3]=$(echo "$line" | linehand_getfield "4")
        field1=${fields[0]}
        field2=${fields[1]}
        field3=$(echo "${fields[2]}" | converter_convert_url)
        field4=$(echo "${fields[3]}" | converter_convert_name)
        echo "$field1 $field2 $field3 $field4" >>"$ofname"
    done || return 1
    return 0
}

linehand_getfield()
{
    local fieldnum="$1"
    local text="$(cat)"
    local out

    if [ "$fieldnum" = "1" ]; then
        out=$(echo "$text" | awk '{print $1}')
    elif [ "$fieldnum" = "2" ]; then
        out=$(echo "$text" | awk '{print $2}')
    elif [ "$fieldnum" = "3" ]; then
        out=$(echo "$text" | awk '{print $3}')
    elif [ "$fieldnum" = "4" ]; then
        out=$(echo "$text" | awk '
{
    for (i = 4; i <= NF; i++) {
        out = out $i (i < NF ? " " : "")
    }
    print out
}
        ')
    else
        out=""
    fi
    echo -n "$out"
}

converter_convert_url()
{
    local url="$(cat)"
    local urltype
    local UT_FPO=0 UT_UNDEF=1
    local out

    urltype=`urlhand_detect_type "$url"`
    case $urltype in
      $UT_FPO)
        out=`echo $url | urlhand_translate_fpo`;;
      $UT_UNDEF)
        out="$url";;
      *) error "Unknown url type: \"$urltype\"";;
    esac
    echo -n "$out"
}

urlhand_detect_type()
{
    local url="$1"
    local UT_FPO=0 UT_UNDEF=1
    local urlcore

    urlcore=`echo "$url" | urlhand_get_url_core`
    if echo "$urlcore" | grep -q '[/.]fastpic.org$'; then
        echo "$UT_FPO"
    else
        echo "$UT_UNDEF"
    fi
}

urlhand_get_url_core()
{
    sed 's%^https\?://\([^/]*\)/.*$%\1%'
}

urlhand_translate_fpo()
{
    local url="$(cat)"
    local urltype
    local UT_FPO_BIG=0 \
          UT_FPO_VIEW=1 \
          UT_FPO_THUMB=2 \
          UT_UNDEF=3
    local out

    urltype=`fpositehand_detect_url_type "$url"`
    case $urltype in
      $UT_FPO_BIG)
        out="$url";;
      $UT_FPO_VIEW)
        out=`echo $url | fpositehand_translate_view_to_big`;;
      $UT_FPO_THUMB)
        out=`echo $url | fpositehand_translate_thumb_to_big`;;
      $UT_UNDEF)
        out="$url";;
      *) error "Unknown fastpic.org url type: \"$urltype\"";;
    esac
    echo -n "$out"
}

fpositehand_detect_url_type()
{
    local url="$1"
    local UT_FPO_BIG=0 \
          UT_FPO_VIEW=1 \
          UT_FPO_THUMB=2 \
          UT_UNDEF=3

    if echo "$url" | grep -q 'fastpic\.org/big/'; then
        echo "$UT_FPO_BIG"
    elif echo "$url" | grep -q 'fastpic\.org/view/'; then
        echo "$UT_FPO_VIEW"
    elif echo "$url" | grep -q 'fastpic\.org/thumb/'; then
        echo "$UT_FPO_THUMB"
    else
        echo "$UT_UNDEF"
    fi
}

fpositehand_translate_view_to_big()
{
    sed '
/^https\?:\/\/fastpic\.org\/view\// {
    s%^\([^:]*://\)\(fastpic\.org/view/\)\([^/]*\)/%\1i\3.\2%
    s%/view/%/big/%
    s%^\(.*/\)\([^/]*\)\(..\)\(\.jpg\.html\)$%\1\3/\2\3\4%
    s%\.html$%%
}
    '
}

fpositehand_translate_thumb_to_big()
{
    sed '
/^https\?:\/\/i[^./]*\.fastpic\.org\/thumb\// {
    s%/thumb/%/big/%
    s%jpeg$%jpg%
}
    '
}

converter_convert_name()
{
    sed '
s/[^[:alnum:]]/_/g
s/___*/_/g
'
}

loader_make_report()
{
    local ifname="$1"
    local ofname="$2"

    cat "$ifname" | awk '
{
    arr[$1]++
}
END {
    print "n", length(arr)
    for (i in arr) {
        print i, arr[i]
        total += arr[i]
    }
    print "t", total
}
'   >"$ofname"
    return 0
}

loader_make_run()
{
    local ifname="$1"
    local ofname="$2"
    local odir="$3"

    awk -v odir="$odir" '
{
    ext = "jpg"
    printf "wget -q -c %s -O %s/%03d_%03d_%s.%s\n",
        $3, odir, $1, $2, $4, ext
}
'   "$ifname" >"$ofname" || return 1
    return 0
}

loader_run()
{
    local ifname_run="$1"
    local ifname_report="$2"
    local line
    local report_numoftrees
    local report_treeurls
    local report_totalurls

    report_numoftrees="$(cat "$ifname_report" | reporthand_get_num_of_trees)"
    report_totalurls="$(cat "$ifname_report" | reporthand_get_total_urls)"
    msg "$(echo "$report_numoftrees $report_totalurls" | reporter_wrap_numoftrees_totalurls)"
    for i in $(seq 1 "$report_numoftrees"); do
        report_treeurls="$(cat "$ifname_report" | reporthand_get_tree_urls $i)"
        msg "$(echo "$i $report_treeurls" | reporter_wrap_treenumber_treeurls)"
    done || return 1
    cat "$ifname_run" | while read line; do
        msg "$(echo "$line" | reporter_wrap_wget_start)"
        eval "$line" || return 1
    done || return 1
    return 0
}

reporthand_get_num_of_trees()
{
    awk '$1 == "n" { print $2; }'
}

reporthand_get_tree_urls()
{
    local tree_number="$1"

    awk -v tn="$tree_number" '$1 == tn { print $2; }'
}

reporthand_get_total_urls()
{
    awk '$1 == "t" { print $2; }'
}

loader_clean_all()
{
    local fname_topic="$1"
    local fname_parsed="$2"
    local fname_converted="$3"
    local fname_report="$4"
    local fname_run="$5"

    rm -f "$fname_topic" \
       "$fname_parsed" \
       "$fname_converted" \
       "$fname_report" \
       "$fname_run" || return 1
    return 0
}

reporter_wrap_curl_start()
{
    local url="$(cat)"

    echo "Loading ${url} ..."
}

reporter_wrap_curl_end()
{
    local url="$(cat)"

    echo "Ok $url loaded."
}

reporter_wrap_wget_start()
{
    local maxdname=15
    local maxfname=40

    awk -v maxdname="$maxdname" \
        -v maxfname="$maxfname" '
{
    dirfile = $NF
    split(dirfile, arr, "/")
    dir = arr[1]
    if (length(dir) > maxdname) {
        dir = substr(arr[1], 1, maxdname - 2) ".."
    }
    file = arr[2]
    if (length(file) > maxfname) {
        file = substr(arr[2], 1, maxfname - 2) ".."
    }
    print "Loading", dir, file " ..."
}
'
}

reporter_wrap_numoftrees_totalurls()
{
    awk '
{
    print "Found",
           $1,
           "tree" ($1 != 1 ? "s" : ""),
           "with total",
           $2,
           "url" ($2 != 1 ? "s" : "") "."
}
'
}

reporter_wrap_treenumber_treeurls()
{
    awk '
{
    print "Tree",
          "#" $1,
          "has",
          $2,
          "url" ($2 != 1 ? "s" : "") "."
}
'
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
        msg "Ok Files have loaded to the current directory."
        ;;
      2)
        usage
        load_screenshots "$1" "$2" || return 1
        msg "Ok Files have loaded to directory $2."
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
