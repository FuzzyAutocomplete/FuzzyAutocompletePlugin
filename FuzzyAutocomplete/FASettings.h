//
//  FASettings.h
//  FuzzyAutocomplete
//
//  Created by Leszek Slazynski on 28/03/2014.
//  Copyright (c) 2014 United Lines of Code. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * FASettingsPluginEnabledDidChangeNotification;

@interface FASettings : NSObject

/// Gets the singleton. Note that the settings are not loaded automatically.
+ (instancetype) currentSettings;

/// Show the settings window modally.
- (void) showSettingsWindow;

/// Load saved settings from NSUserDefaults.
- (void) loadFromDefaults;

/// Reset to the default values.
- (IBAction) resetDefaults: (id) sender;

/// Is the plugin enabled.
@property (nonatomic, readonly) BOOL pluginEnabled;

/// How many workers should work in parallel.
@property (nonatomic, readonly) NSInteger prefixAnchor;

/// Only show items with score higher than this threshold.
@property (nonatomic, readonly) double minimumScoreThreshold;

/// Sort by score or alphabetically.
@property (nonatomic, readonly) BOOL sortByScore;

/// Filter by score (using threshold).
@property (nonatomic, readonly) BOOL filterByScore;

/// Show scores in completion list view.
@property (nonatomic, readonly) BOOL showScores;

/// NSNumberFormatter format for scores in completion list view.
@property (nonatomic, readonly) NSString * scoreFormat;

/// Should the scoring be done in parallel.
@property (nonatomic, readonly) BOOL parallelScoring;

/// How many workers should work in parallel.
@property (nonatomic, readonly) NSInteger maximumWorkers;

/// Should the inline preview be visible.
@property (nonatomic, readonly) BOOL showInlinePreview;

/// Should the inline preview be visible.
@property (nonatomic, readonly) BOOL hideCursorInNonPrefixPreview;

/// Should the scores be divided by maximum score so that are from [0, 1].
@property (nonatomic, readonly) BOOL normalizeScores;

/// Should the list header be visible.
@property (nonatomic, readonly) BOOL showListHeader;

/// Should the list header contain number of matches.
@property (nonatomic, readonly) BOOL showNumMatches;

/// Should the timing in the list header be visible.
@property (nonatomic, readonly) BOOL showTiming;

// scoring method parameters, see FAItemScoringMethod 
@property (nonatomic, readonly) double matchScorePower;
@property (nonatomic, readonly) double priorityPower;
@property (nonatomic, readonly) double priorityFactorPower;
@property (nonatomic, readonly) double maxPrefixBonus;

/// Should the plugin autocorrect letter case.
@property (nonatomic, readonly) BOOL correctLetterCase;

/// Should the letter case be corrected only if match has highest score.
@property (nonatomic, readonly) BOOL correctLetterCaseBestMatchOnly;

/// Should the plugin autocorrect wordOrder.
@property (nonatomic, readonly) BOOL correctWordOrder;

/// After how many letters should attempt to correct word order.
@property (nonatomic, readonly) NSInteger correctWordOrderAfter;


@end
