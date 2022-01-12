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

# Print an message to a log file
# log(file, str)
log()
{
    local ofname="$1"
    local message="$2"

    echo "$message" >>"$ofname"
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
    local fname_run_log="run_log.txt"

    [ -d "$odir" ] || mkdir "$odir"
    loader_load_topic_page \
        "$url" \
        "$odir/$fname_topic" || {
        error "Can't load the topic page from $url."
        return 1
    }
    loader_parse_topic_page \
        "$odir/$fname_topic" \
        "$odir/$fname_parsed" \
        "$odir" || {
        error "Can't parse the topic page."
        return 1
    }
    loader_convert_data \
        "$odir/$fname_parsed" \
        "$odir/$fname_converted" || {
        error "Can't convert the parsed data."
        return 1
    }
    loader_make_report \
        "$odir/$fname_converted" \
        "$odir/$fname_report" || {
        error "Can't make the report file."
        return 1
    }
    loader_make_run \
        "$odir/$fname_converted" \
        "$odir/$fname_run" \
        "$odir" || {
        error "Can't make the run file."
        return 1
    }
    loader_run \
        "$odir/$fname_run" \
        "$odir/$fname_report" \
        "$odir/$fname_run_log" \
        "$odir" || {
        error "Can't run the running loadings file."
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
        error "Can't clean temporary files after building parsed data from topic."
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
    if ctrees_extractor_extract_cuttrees_direct "$ifname" "$tfname" && \
       ctrees_extractor_test_extracted_cuttrees "$tfname"; then
        mv "$tfname" "$ofname" || return 1
        return 0
    fi
    echo -n >"$tfname"
    if ctrees_extractor_extract_cuttrees_wrapped "$ifname" "$tfname" && \
       ctrees_extractor_test_extracted_cuttrees "$tfname"; then
        mv "$tfname" "$ofname" || return 1
        return 0
    fi
    error "Can't extract cut tree by the direct method."
    error "Can't extract cut tree by the wrapped method."
    return 1
}

ctrees_extractor_extract_cuttrees_direct()
{
    local ifname="$1"
    local ofname="$2"
    local xpathreq1 xpathreq2

    xpathreq1='..//div[@class="post-user-message"]'
    xpathreq2='./div[@class="sp-wrap"]'

    echo -n >"$ofname"

    cat "$ifname" | python3 -c '
import sys
import lxml.html

doc = lxml.html.fromstring(sys.stdin.read())
print("<html>\n<body>")
outer_nodes = doc.xpath(r"""'"$xpathreq1"'""")
if outer_nodes:
    inner_nodes = outer_nodes[0].xpath(r"""'"$xpathreq2"'""")
    for i in inner_nodes:
        print(lxml.html.tostring(i, encoding="unicode", pretty_print=True))
print("</body>\n</html>")
'   >"$ofname" || return 1
    return 0
}

ctrees_extractor_extract_cuttrees_wrapped()
{
    local ifname="$1"
    local ofname="$2"
    local xpathreq1 xpathreq2

    xpathreq1='..//div[@class="post-user-message"]'
    xpathreq2='./div[@class="post-align"]/div[@class="sp-wrap"]'

    echo -n >"$ofname"

    cat "$ifname" | python3 -c '
import sys
import lxml.html

doc = lxml.html.fromstring(sys.stdin.read())
print("<html>\n<body>")
outer_nodes = doc.xpath(r"""'"$xpathreq1"'""")
if outer_nodes:
    inner_nodes = outer_nodes[0].xpath(r"""'"$xpathreq2"'""")
    for i in inner_nodes:
        print(lxml.html.tostring(i, encoding="unicode", pretty_print=True))
print("</body>\n</html>")
'   >"$ofname" || return 1
    return 0
}

ctrees_extractor_test_extracted_cuttrees()
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
    if ctrees_selector_filter_cuttrees_varimg "$ifname" "$tfname_s1" && \
       ctrees_selector_test_filtered_cuttrees "$tfname_s1"; then
        :
    else
        error "Can't filter cut trees by var with image."
        return 1
    fi
    echo -n >"$tfname_s2"
    if ctrees_selector_filter_cuttrees_sitefpo "$tfname_s1" "$tfname_s2" && \
       ctrees_selector_test_filtered_cuttrees "$tfname_s2"; then
        :
    else
        error "Can't filter cut trees by the fpo site."
        return 1
    fi
    rm -f "$tfname_s1" || return 1
    mv "$tfname_s2" "$ofname" || return 1
    return 0
}

ctrees_selector_filter_cuttrees_varimg()
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

ctrees_selector_filter_cuttrees_sitefpo()
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

ctrees_selector_test_filtered_cuttrees()
{
    local ifname="$1"

    htmlpagehand_is_empty "$ifname" && return 1
    return 0
}

topichand_convert_cuttrees()
{
    local ifname="$1"
    local ofname="$2"
    local tfname_s1="${ifname}.converted.stage1.tmp"
    local tfname_s2="${ifname}.converted.stage2.tmp"
    local tfname_s3="${ifname}.converted.stage3.tmp"
    local tfname_s4="${ifname}.converted.stage4.tmp"
    local tfname_s5="${ifname}.converted.stage5.tmp"

    echo -n >"$tfname_s1"
    if ctrees_converter_convert_remove_post_align "$ifname" "$tfname_s1" && \
       ctrees_converter_test_converted_cuttrees "$tfname_s1"; then
        :
    else
        error "Can't convert cut trees to the removed post alignment."
        return 1
    fi
    echo -n >"$tfname_s2"
    if ctrees_converter_convert_ahref_to_var "$tfname_s1" "$tfname_s2" && \
       ctrees_converter_test_converted_cuttrees "$tfname_s2"; then
        :
    else
        error "Can't convert cut trees from var in tag a to var."
        return 1
    fi
    echo -n >"$tfname_s3"
    if ctrees_converter_convert_deep0_to_deep1 "$tfname_s2" "$tfname_s3" && \
       ctrees_converter_test_converted_cuttrees "$tfname_s3"; then
        :
    else
        error "Can't convert cut trees from deep 0 to deep 1."
        return 1
    fi
    echo -n >"$tfname_s4"
    if ctrees_converter_convert_wrap_deep_vars "$tfname_s3" "$tfname_s4" && \
       ctrees_converter_test_converted_cuttrees "$tfname_s4"; then
        :
    else
        error "Can't convert cut trees from deep vars to wrapped deep vars."
        return 1
    fi
    echo -n >"$tfname_s5"
    if ctrees_converter_convert_deepn_to_deep1 "$tfname_s4" "$tfname_s5" && \
       ctrees_converter_test_converted_cuttrees "$tfname_s5"; then
        :
    else
        error "Can't convert cut trees from deep N to deep 1."
        return 1
    fi
    rm -f "$tfname_s1" || return 1
    rm -f "$tfname_s2" || return 1
    rm -f "$tfname_s3" || return 1
    rm -f "$tfname_s4" || return 1
    mv "$tfname_s5" "$ofname" || return 1
    return 0
}

ctrees_converter_convert_remove_post_align()
{
    local ifname="$1"
    local ofname="$2"
    local xpathreq1 xpathreq2

    xpathreq1='./body/div'
    xpathreq2='.//div[@class="post-align"]'

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
        for k in j:
            j.addprevious(k)
        j.getparent().remove(j)
    text = lxml.html.tostring(i, encoding="unicode", pretty_print=True)
    print(text)
print("</body>\n</html>")
'   >"$ofname" || return 1
    return 0
}

ctrees_converter_convert_ahref_to_var()
{
    local ifname="$1"
    local ofname="$2"
    local xpathreq1 xpathreq2

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
'   >"$ofname" || return 1
    return 0
}

ctrees_converter_convert_deep0_to_deep1()
{
    local ifname="$1"
    local ofname="$2"
    local xpathreq1 xpathreq2 xpathreq3
    local urlname_default urltext_default

    xpathreq1='./body/div'
    xpathreq2='./div/var[@class="postImg"]'
    xpathreq3='./div/div/div/var[@class="postImg"]/../..'
    urlname_default="screenshot"
    urltext_default="description"

    echo -n >"$ofname"

    cat "$ifname" | python3 -c '
import sys
import lxml.html
import lxml.etree

def create_new_ctree_from_source(source_node):
    node_div = lxml.html.Element("div")
    node_div.attrib["class"] = "sp-wrap"
    node_div.text = "\n"
    node_div_div = lxml.etree.SubElement(node_div, "div")
    node_div_div.attrib["class"] = "sp-body"
    node_div_div.attrib["title"] = source_node[0].attrib["title"]
    node_div_div.text = "\n"
    node_div_div_h3 = lxml.etree.SubElement(node_div_div, "h3")
    node_div_div_h3.attrib["class"] = "sp-title"
    node_div_div_h3.text = source_node[0][0].text
    out = node_div
    return out

def create_new_ctree_wrapped(urlname, urltext):
    node_div = lxml.html.Element("div")
    node_div.attrib["class"] = "sp-wrap"
    node_div.text = "\n"
    node_div_div = lxml.etree.SubElement(node_div, "div")
    node_div_div.attrib["class"] = "sp-body"
    node_div_div.attrib["title"] = urlname
    node_div_div.text = "\n"
    node_div_div_h3 = lxml.etree.SubElement(node_div_div, "h3")
    node_div_div_h3.attrib["class"] = "sp-title"
    node_div_div_h3.text = urlname
    node_div_div_span = lxml.etree.SubElement(node_div_div, "span")
    node_div_div_span.attrib["class"] = "post-b"
    node_div_div_span.text = urltext
    out = node_div
    return out

def wrap_vars_in_ctree(ctree_node, xpathreq_var, xpathreq_div,
                       urlname, urltext):
    nodes_var = ctree_node.xpath(xpathreq_var)
    nodes_div = ctree_node.xpath(xpathreq_div)
    if nodes_var:
        new_item = create_new_ctree_from_source(ctree_node)
        for item in nodes_var:
            new_item_w = create_new_ctree_wrapped(
                urlname, urltext)
            new_item_w[0].append(item)
            new_item[0].append(new_item_w)
        for item in nodes_div:
            new_item[0].append(item)
        return new_item
    else:
        return ctree_node

def main():
    doc = lxml.html.fromstring(sys.stdin.read())
    print("<html>\n<body>")
    outer_nodes = doc.xpath(r"""'"$xpathreq1"'""")
    for i in outer_nodes:
        wrapped_ctree = wrap_vars_in_ctree(
            i, r"""'"$xpathreq2"'""", r"""'"$xpathreq3"'""",
            "'"$urlname_default"'", "'"$urltext_default"'")
        text = lxml.html.tostring(
            wrapped_ctree, encoding="unicode", pretty_print=True)
        print(text)
    print("</body>\n</html>")

main()
'   >"$ofname" || return 1
    return 0
}

ctrees_converter_convert_wrap_deep_vars()
{
    local ifname="$1"
    local ofname="$2"
    local xpathreq1 xpathreq2 xpathreq3
    local urlname_default urltext_default

    xpathreq1='./body/div'
    xpathreq2='./div/var[@class="postImg"]'
    xpathreq3='./div/div/div/var[@class="postImg"]/../..'
    urlname_default="screenshot"
    urltext_default="description"

    echo -n >"$ofname"

    cat "$ifname" | python3 -c '
import sys
import lxml.html
import lxml.etree

def create_new_ctree_from_source(source_node):
    node_div = lxml.html.Element("div")
    node_div.attrib["class"] = "sp-wrap"
    node_div.text = "\n"
    node_div_div = lxml.etree.SubElement(node_div, "div")
    node_div_div.attrib["class"] = "sp-body"
    node_div_div.attrib["title"] = source_node[0].attrib["title"]
    node_div_div.text = "\n"
    node_div_div_h3 = lxml.etree.SubElement(node_div_div, "h3")
    node_div_div_h3.attrib["class"] = "sp-title"
    node_div_div_h3.text = source_node[0][0].text
    out = node_div
    return out

def create_new_ctree_wrapped(urlname, urltext):
    node_div = lxml.html.Element("div")
    node_div.attrib["class"] = "sp-wrap"
    node_div.text = "\n"
    node_div_div = lxml.etree.SubElement(node_div, "div")
    node_div_div.attrib["class"] = "sp-body"
    node_div_div.attrib["title"] = urlname
    node_div_div.text = "\n"
    node_div_div_h3 = lxml.etree.SubElement(node_div_div, "h3")
    node_div_div_h3.attrib["class"] = "sp-title"
    node_div_div_h3.text = urlname
    node_div_div_span = lxml.etree.SubElement(node_div_div, "span")
    node_div_div_span.attrib["class"] = "post-b"
    node_div_div_span.text = urltext
    out = node_div
    return out

def wrap_vars_in_ctree(ctree_node, xpathreq_var, xpathreq_div,
                       urlname, urltext):
    nodes_var = ctree_node.xpath(xpathreq_var)
    nodes_div = ctree_node.xpath(xpathreq_div)
    if nodes_div:
        new_item = create_new_ctree_from_source(ctree_node)
        for item in nodes_var:
            new_item_w = create_new_ctree_wrapped(
                urlname, urltext)
            new_item_w[0].append(item)
            new_item[0].append(new_item_w)
        for item in nodes_div:
            wrapped_div = wrap_vars_in_ctree(
                item, xpathreq_var, xpathreq_div,
                urlname, urltext)
            new_item[0].append(wrapped_div)
        return new_item
    else:
        return ctree_node

def main():
    doc = lxml.html.fromstring(sys.stdin.read())
    print("<html>\n<body>")
    outer_nodes = doc.xpath(r"""'"$xpathreq1"'""")
    for i in outer_nodes:
        wrapped_ctree = wrap_vars_in_ctree(
            i, r"""'"$xpathreq2"'""", r"""'"$xpathreq3"'""",
            "'"$urlname_default"'", "'"$urltext_default"'")
        text = lxml.html.tostring(
            wrapped_ctree, encoding="unicode", pretty_print=True)
        print(text)
    print("</body>\n</html>")

main()
'   >"$ofname" || return 1
    return 0
}

ctrees_converter_convert_deepn_to_deep1()
{
    local ifname="$1"
    local ofname="$2"
    local xpathreq1 xpathreq2

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
'   >"$ofname" || return 1
    return 0
}

ctrees_converter_test_converted_cuttrees()
{
    local ifname="$1"

    htmlpagehand_is_empty "$ifname" && return 1
    return 0
}

topichand_convert_cuttrees_to_rawdata()
{
    local ifname="$1"
    local ofname="$2"
    local tfname_s1="${ifname}.convertedrawdata.stage1.tmp"

    echo -n >"$tfname_s1"
    if ctrees_converter_convert_cuttrees_to_rawdata "$ifname" "$tfname_s1" && \
       ctrees_converter_test_converted_rawdata "$tfname_s1"; then
        :
    else
        error "Can't convert cut trees to raw data."
        return 1
    fi
    mv "$tfname_s1" "$ofname" || return 1
    return 0
}

ctrees_converter_convert_cuttrees_to_rawdata()
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
'   >"$ofname" || return 1
    return 0
}

ctrees_converter_test_converted_rawdata()
{
    local ifname="$1"

    rawdatahand_has_one_record "$ifname" || return 1
    return 0
}

rawdatahand_has_one_record()
{
    local ifname="$1"

    awk '
NR == 1 && !/^$/ {
    f_exit = 1
    exit 1
}
NR == 2 && !/./ {
    f_exit = 1
    exit 1
}
NR == 3 && (!/^https?:\/\// || NF < 2) {
    f_exit = 1
    exit 1
}
END {
    if (f_exit) {
        exit
    } else {
        exit (NR >= 3) ? 0 : 1
    }
}
' "$ifname" || return 1
    return 0
}

topichand_convert_rawdata_to_parsedata()
{
    local ifname="$1"
    local ofname="$2"
    local tfname_s1="${ifname}.convertedparsedata.stage1.tmp"

    echo -n >"$tfname_s1"
    if rawdata_converter_convert_rawdata_to_parsedata "$ifname" "$tfname_s1" && \
       rawdata_converter_test_converted_parsedata "$tfname_s1"; then
        :
    else
        error "Can't convert raw data to parse data."
        return 1
    fi
    mv "$tfname_s1" "$ofname" || return 1
    return 0
}

rawdata_converter_convert_rawdata_to_parsedata()
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
'   >"$ofname" || return 1
    return 0
}

rawdata_converter_test_converted_parsedata()
{
    local ifname="$1"

    parsedatahand_has_one_record "$ifname" || return 1
    return 0
}

parsedatahand_has_one_record()
{
    local ifname="$1"

    awk '
NR == 1 {
    if ($1 == "1" && $2 == "1" && $3 ~ /^https?:\/\// && $4 ~ /./) {
        exit 0
    } else {
        exit 1
    }
}
END {
    if (NR == 0) {
        exit 1
    }
}
' "$ifname" || return 1
    return 0
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
    local ofname_log="$3"
    local odir="$4"
    local tfname_result="runresult.tmp"
    local tfname_reload="runreload.tmp"

    lowloader_load_run_list \
        "$ifname_run" \
        "$ifname_report" \
        "$ofname_log" \
        "$odir/$tfname_result" || {
        error "Can't load files from run list."
        return 1
    }
    if lowloader_make_reload_list \
           "$odir/$tfname_result" \
           "$odir/$tfname_reload"; then
        lowloader_load_reload_list \
            "$odir/$tfname_reload" \
            "$ofname_log" || {
            error "Can't reload files from reload list."
            return 1
        }
    fi
    lowloader_clean_all \
        "$odir/$tfname_result" \
        "$odir/$tfname_reload" || {
        error "Can't clean temporary files after loading."
        return 1
    }
    return 0
}

lowloader_load_run_list()
{
    local ifname_run="$1"
    local ifname_report="$2"
    local ofname_log="$3"
    local ofname_result="$4"
    local line
    local resultline
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

    echo -n >"$ofname_result"

    cat "$ifname_run" | while read line; do
        msg "$(echo "$line" | reporter_wrap_wget_start)"
        if eval "$line"; then
            resultline="$(echo "$line" | resulthand_wrap_command_to_result)"
            echo "$resultline" >>"$ofname_result"
        else
            msg "$(echo "$line" | reporter_wrap_wget_broken_url)"
            log "$ofname_log" "$(echo "$line" | logger_wrap_broken_url)"
        fi
    done || return 1
    return 0
}

resulthand_wrap_command_to_result()
{
    awk '
{
    if ($1 == "wget" && $4 ~ /^https?:\/\/[^/]+\.fastpic\.org\//) {
        site = "fpo"
    }
    else {
        site = "unknown"
    }
    split($6, arr, "/")
    print "loaded", site, arr[1], arr[2], $4
}
'
}

lowloader_make_reload_list()
{
    local ifname_result="$1"
    local ofname_reload="$2"
    local line
    local result_status
    local result_site
    local result_file
    local result_dir
    local result_url
    local reload_file
    local reload_dir
    local reload_url

    echo -n >"$ofname_reload"

    cat "$ifname_result" | while read line; do
        result_status=$(echo "$line" | resultlinehand_getfield "1")
        result_site=$(echo "$line" | resultlinehand_getfield "2")
        result_dir=$(echo "$line" | resultlinehand_getfield "3")
        result_file=$(echo "$line" | resultlinehand_getfield "4")
        result_url=$(echo "$line" | resultlinehand_getfield "5")
        [ "$result_status" = "loaded" ] && {
            [ "$result_site" = "fpo" ] && {
                sitefpo_file_needs_reload "$result_dir/$result_file" && {
                    reload_file="$(sitefpo_make_reload_file "$result_file")"
                    reload_dir="$(sitefpo_make_reload_dir "$result_dir")"
                    reload_url="$(sitefpo_make_reload_url "$result_url")"
                    reloadline="$(echo "$reload_file $reload_dir $reload_url" | \
                        sitefpo_wrap_to_reloadline)"
                    echo "$reloadline" >>"$ofname_reload"
                }
            }
        }
    done || return 1
    return 0
}

sitefpo_file_needs_reload()
{
    local ifname="$1"

    return 0
}

sitefpo_make_reload_file()
{
    local fname="$1"
    local out

    out="$(echo "$fname" | sed 's/\.jpg$/_reloaded&/')"
    echo "$out"
}

sitefpo_make_reload_dir()
{
    local dname="$1"
    local out

    out="$dname"
    echo "$out"
}

sitefpo_make_reload_url()
{
    local url="$1"
    local out

    out="try_$url"
    echo "$out"
}

sitefpo_wrap_to_reloadline()
{
    awk '{ printf "echo wget -q -c \"%s\" -O %s/%s\n", $3, $2, $1; }'
}

resultlinehand_getfield()
{
    local field_number="$1"

    awk -v n="$field_number" '{ print $n; }'
}

lowloader_load_reload_list()
{
    local ifname_reload="$1"
    local ofname_log="$2"

    echo "lowloader_load_reload_list() $ifname_reload $ofname_log"
    return 0
}

lowloader_clean_all()
{
    local fname_result="$1"
    local fname_reload="$2"

    rm -f "$fname_result" \
       "$fname_reload" || return 1
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

reporter_wrap_wget_broken_url()
{
    local maxfname=40

    awk -v maxfname="$maxfname" '
{
    dirfile = $NF
    split(dirfile, arr, "/")
    file = arr[2]
    if (length(file) > maxfname) {
        file = substr(arr[2], 1, maxfname - 2) ".."
    }
    print "Unable to load", file
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

logger_wrap_broken_url()
{
    awk '{ print "Found broken [" $NF "] at [" $(NF-2) "]"; }'
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
