
plnshots v0.0.1

This script loads screenshots from the first post of a given topic on site
https://pornolab.net

---

This is a __PORN SITE__, so remove children from the screen.

__This project is under construction:__

- It loads only screenshots located on http://fastpic.org

  Usually, there are over three active sites with screenshots.

- It connects to the topic page through the local tor daemon on localhost:9050 .

  You can edit this command in the script to switch off the tor
  connection, but I am going to add the option for tor connection to
  the config file of the program.

- The code is not commented at all.

I made this script in period started at 10 Dec 2021 till 16 Jan 2022. So in the next period I will complete the first version and remove the "under construction" tag.

---

__How to build and install the program__

### Requirements

This program has tested on environment configuration
```
1)
  Linux Fedora 26
  Python 3.6.1
  python3-lxml 3.7.2
  GNU bash 4.4.12
  GNU awk 4.1.4
  GNU sed 4.4
  curl 7.53.1
  GNU Wget 1.19.1
```

### Building

Build the docs and read the README file in _build/docs_.

To build run:

```sh
$ ./configure
$ make
```

### Installation

To install run:

```sh
$ sudo make install
```

To uninstall run:

```sh
$ sudo make uninstall
```

### Run

In general form:

```sh
$ plnshots.sh topic_url output_dir
```

---

__How to run and use it:__

1. Build and install the program

2. Find an interesting topic on the site https://pornolab.net

3. Then run it

``` sh
$ plnshots.sh https://forum_topic_url directory_to_save
```

You will see something like that

```

$ ./plnshots.sh https://pornolab.net/forum/viewtopic.php?t=12345 girls12345
Try `plnshots.sh --help' for more information.
plnshots.sh: Loading https://pornolab.net/forum/viewtopic.php?t=12345 ...
plnshots.sh: Ok https://pornolab.net/forum/viewtopic.php?t=12345 loaded.
plnshots.sh: Found 1 tree with total 48 urls.
plnshots.sh: Tree #1 has 48 urls.
plnshots.sh: Loading girls12345 001_001_Girls_Allie_wmv.jpg ...
plnshots.sh: Loading girls12345 001_002_Girls_Amanda_wmv.jpg ...
plnshots.sh: Loading girls12345 001_003_Girls_Audrey_wmv.jpg ...
...

```

4. Look at images and select interesting by names.

5. Download the torrent file from the topic.

6. Open this torrent file and select according files for load.
