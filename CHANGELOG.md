## Changelog

#### 2.0.0 - 2014/04/16
**A major update introducing many fixes and improvements, including:**

* Visual feedback in Completion List and Inline Preview
* Settings Window, settings now don't require Xcode restart
* Option to sort items by match score
* Option to hide items based on threshold
* Option to hide Inline Preview, which now works correctly
* Option to show a List Header with query and number of matches
* Option to show item scores in the List
* Improved score formula, added option to tweak parameters
* Previously hidden items can now re-appear if their score rises
* `Tab` now inserts an useful prefix based on whole fuzzy match
* The results should no longer depend on the speed of typing
* Got rid of order dependent "shortest match" selection mechanism
* Performance++
* UX++
* ...

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
