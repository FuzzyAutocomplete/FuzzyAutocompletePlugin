# Fuzzy Autocomplete for Xcode

![Demo](https://raw.github.com/chendo/FuzzyAutocompletePlugin/master/demo.gif)

This is a Xcode 5 plugin that patches the autocomplete filter to work the same way the `Open Quickly` works.

It performs very well, and the fuzzy matching actually uses Xcode's own `IDEOpenQuicklyPattern`, however for performance reasons, **the first letter of the fuzzy match must start with the same letter of the completion you want**.

I wrote a blog post on how I used `dtrace` to figure out what to patch: [Reverse engineering Xcode with dtrace](http://chen.do/blog/2013/10/22/reverse-engineering-xcode-with-dtrace/?utm_source=github&utm_campaign=fuzzyautocomplete)

Like nifty tools like this plugin? Check out [Shortcat](https://shortcatapp.com/?utm_source=github&utm_campaign=fuzzyautocomplete), an app that lets you control your Mac more effectively with your keyboard!

## Features

* Gives Xcode's autocompletion to be able to filter like `Open Quickly` does
* Supports Xcode's learning priority system
* `Tab` now inserts
* Performs well
* Productivity++

## Installation

* Either:
  * Install with [Alcatraz](http://mneorr.github.io/Alcatraz/)
  * Clone and build the project
* Restart Xcode and enjoy!

## Notes

* Only tested with Xcode 5 on 10.9
* Hasn't been tested with other plugins yet

## Changelog

#### 1.3 - 2013/10/23

* Now factors in Xcode's learning priority system (#2)
* `Tab` now accepts selected completion as it doesn't make sense to insert prefix with fuzzy matching

#### 1.2 - 2013/10/22

* Fixes missing file entries when autocompleting paths (#1)

#### 1.1 - 2013/10/21

* Implement partial completion support via `Tab`

#### 1.0 - 2013/10/20

* Initial release

[![githalytics.com alpha](https://cruel-carlota.pagodabox.com/2803367345737409176241eb9cc3f903 "githalytics.com")](http://githalytics.com/chendo/fuzzyautocompleteplugin)
