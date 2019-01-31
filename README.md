<h1 align="center"><img src="misc/AppIcon/AppIcon0128.png" width="128" height="128" alt="MyHappyList" title="MyHappyList"></h1>

[![](https://img.shields.io/github/release/ReFreezed/MyHappyList.svg)](https://github.com/ReFreezed/MyHappyList/releases/latest)

**<big>MyHappyList</big>** - a very simple [AniDB](https://anidb.net/) *MyList* manager for Windows.

[Forum thread](https://anidb.net/thread83307)

- [Features](#features)
- [Download](#download)
- [How to Update](#how-to-update)
- [Translations](#translations)
- [Issues](#issues)



## Features
- Add files to *MyList*.
- Mark files as watched.
- Calculate [ed2k hashes](https://wiki.anidb.info/w/Ed2k-hash).

And that's about it! If you're looking for something different,
have a look at [alternative software](https://anidb.net/perl-bin/animedb.pl?show=software).



## Download
See the [latest release](https://github.com/ReFreezed/MyHappyList/releases/latest) page.
No installation required - just unzip anywhere and run **MyHappyList.exe** !



## How to Update
Either update the program through `File` > `Update Program`,
or manually download the latest version and simply replace the old program folder with the new one.

### Updating from 1.0.x to 1.1 or Later
Move the `cache` and `local` folders from the old program folder to the new one to preserve settings etc.
These folders will automatically be moved to your
[`%APPDATA%`](https://en.wikipedia.org/wiki/Special_folder#File_system_directories)
folder next time you run MyHappyList, so you only ever have to do this once.



## Translations
MyHappyList currently supports English and Swedish.

If you want to help translating the program into your language you can make a copy of
[languages/en-US.txt](languages/en-US.txt) and edit the lines.
When you're done you can [submit a pull request](https://github.com/ReFreezed/MyHappyList/compare) or
send me the file in a [PM on AniDB](https://anidb.net/perl-bin/animedb.pl?show=msg&do.new=1&msg.to=ReFreezed)
and the translation will be in the next release.



## Issues

### Program does not start and there's no error message
There may be issues if there are special characters in the path to the program.
Try placing the program folder in `C:\Program Files`.

### Other issue
You can report the issue on [GitHub](https://github.com/ReFreezed/MyHappyList/issues)
or in the [forum thread](https://anidb.net/thread83307).


