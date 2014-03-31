# Fuzzy Autocomplete for Xcode

![Demo](https://raw.github.com/chendo/FuzzyAutocompletePlugin/master/demo.gif)

This is a Xcode 5 plugin that patches the autocomplete filter to work the same way the `Open Quickly` works.

It performs very well, and the fuzzy matching actually uses Xcode's own `IDEOpenQuicklyPattern`.

I wrote a blog post on how I used `dtrace` to figure out what to patch: [Reverse engineering Xcode with dtrace](http://chen.do/blog/2013/10/22/reverse-engineering-xcode-with-dtrace/?utm_source=github&utm_campaign=fuzzyautocomplete)

Like nifty tools like this plugin? Check out [Shortcat](https://shortcatapp.com/?utm_source=github&utm_campaign=fuzzyautocomplete), an app that lets you control your Mac more effectively with your keyboard!

## Features

* Gives Xcode's autocompletion to be able to filter like `Open Quickly` does
* Supports Xcode 5.0, 5.0.1, 5.0.2 and 5.1
* Supports Xcode's learning and context-aware priority system
* `Tab` now inserts completion rathen than inserting prefix
* Compatible with [KSImageNamed](https://github.com/ksuther/KSImageNamed-Xcode) (be sure to grab the newest version)
* Uses Grand Central Dispatch to parallelise matching
* Productivity++

## Installation

* Either:
  * Install with [Alcatraz](http://alcatraz.io)
  * Clone and build the project
* Restart Xcode and enjoy!

## Options

Changing options require restarting Xcode. All options off by default.

* Shortest match being top priority: `defaults write com.apple.dt.Xcode FuzzyAutocompletePrioritizeShortestMatch -bool yes`
  * This makes it so you can always type more to match what you want without having to go through the list. Off by default as it ruins Xcode's built-in priority system.
* Insert useful prefix when pressing `Tab`: `defaults write com.apple.dt.Xcode FuzzyAutocompleteInsertUsefulPrefix -bool yes`
  * Enables Xcode's old behaviour where pressing `Tab` inserts the common prefix of the your selected match (denoted by the underlined text). Off as it can return weird top results due to Xcode's fuzzy matching algorithm. Only works when the search prefix shares the prefix with the top match.
* Prefix Anchor: `defaults write com.apple.dt.Xcode FuzzyAutocompletePrefixAnchor -integer [x]`, where `x` is the number of characters you want to anchor.
  * This will require the completion items to match the first "x" letters you type ("x" being the integer you set). Note: this only "kicks in" *after* you've typed in more than one character.  So even if you set the Prefix Anchor to `1`, the completion results won't be filtered to the prefix until you type the second character. 
  * This option if off by default. If the option has been set, you can turn the option off by setting the option's integer value to `0`.

## Notes

* Only tested with Xcode 5.0 and 5.1 on 10.9
* Hasn't been tested with other plugins (other than `KSImageNamed`)

## Changelog

#### 1.7 - 2014/03/23

* Adds inserting useful prefix with `Tab` as an option.

#### 1.6 - 2014/03/22

* No longer prioritises shortest match by default. Can be re-enabled with `defaults write com.apple.dt.Xcode FuzzyAutocompletePrioritizeShortestMatch -bool yes` and restarting Xcode.

#### 1.5 - 2013/11/05

* Shortest match will always be selected

#### 1.4 - 2013/10/26

* Remove requirement to start fuzzy match with first letter of desired match
* Improve performance by parallelising work

#### 1.3.1 - 2013/10/24

* Decrease the weighting of Xcode's priority factor from `1.0` to `0.2`
* Prepare for [KSImageNamed](https://github.com/ksuther/KSImageNamed-Xcode) compatibility when [KSImageNamed#31](https://github.com/ksuther/KSImageNamed-Xcode/pull/31) gets merged.

#### 1.3 - 2013/10/23

* Now factors in Xcode's learning priority system - [#2](https://github.com/chendo/FuzzyAutocompletePlugin/issues/2)
* `Tab` now accepts selected completion as it doesn't make sense to insert prefix with fuzzy matching

#### 1.2 - 2013/10/22

* Fixes missing file entries when autocompleting paths - [#1](https://github.com/chendo/FuzzyAutocompletePlugin/issues/1)

#### 1.1 - 2013/10/21

* Implement partial completion support via `Tab`

#### 1.0 - 2013/10/20

* Initial release

[![githalytics.com alpha](https://cruel-carlota.pagodabox.com/2803367345737409176241eb9cc3f903 "githalytics.com")](http://githalytics.com/chendo/fuzzyautocompleteplugin)
