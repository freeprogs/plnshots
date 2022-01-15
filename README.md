
plnshots v0.0.1

This script loads screenshots from the first post of a topic on site
https://pornolab.net

This is a __PORN SITE__, so remove children from the screen.

__This project is under construction:__

- It loads only screenshots located on http://fastpic.org

  Usually, there are over three active sites with screenshots.

- It connects to the topic page through the local tor daemon on localhost:9050 .

- The code is not commented at all.

I made this script in period started at 10 Dec 2021 till 16 Jan 2022. So in the next period I will complete the first version and remove the "under construction" tag.

__How to run and use it:__

1. You just copy the script plnshots.sh to a directory.

2. Find an interesting topic on the site https://pornolab.net

3. Then run it

``` sh
$ ./plnshots.sh https://forum_topic_url directory_to_save
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
