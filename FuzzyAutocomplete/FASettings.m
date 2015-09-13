//
//  FASettings.m
//  FuzzyAutocomplete
//
//  Created by Leszek Slazynski on 28/03/2014.
//  Copyright (c) 2014 United Lines of Code. All rights reserved.
//

#import "FuzzyAutocomplete.h"
#import "FASettings.h"
#import "FATheme.h"

NSString * FASettingsPluginEnabledDidChangeNotification = @"io.github.FuzzyAutocomplete.PluginEnabledDidChange";

// increment to show settings screen to the user
static const NSUInteger kSettingsVersion = 4;

@interface FASettings () <NSWindowDelegate>

@end

@implementation FASettings

+ (instancetype) currentSettings {
    static FASettings * settings;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        settings = [FASettings new];
    });
    return settings;
}

#pragma mark - settings window

- (void) showSettingsWindow {
    [[NSUserDefaults standardUserDefaults] setObject: @(kSettingsVersion) forKey: kSettingsVersionKey];
    [self loadFromDefaults];
    NSBundle * bundle = [NSBundle bundleForClass: [self class]];
    NSArray * objects;
    NSWindow * window = nil;
    @try {
        [bundle loadNibNamed: @"FASettingsWindow" owner: self topLevelObjects: &objects];
        for (id object in objects) {
            if ([object isKindOfClass: [NSWindow class]]) {
                window = object;
                break;
            }
        }
    }
    @catch (NSException *exception) {
        RLog(@"Exception while opening Settings Window: %@", exception);
    }
    
    if (window) {
        window.minSize = window.frame.size;
        window.maxSize = window.frame.size;
        NSString * title = bundle.lsl_bundleNameWithVersion;
        NSTextField * label = (NSTextField *) [window.contentView viewWithTag: 42];
        NSMutableAttributedString * attributed = [[NSMutableAttributedString alloc] initWithString: title];
        FATheme * theme = [FATheme cuurrentTheme];
        [attributed addAttributes: theme.listTextAttributesForMatchedRanges range: NSMakeRange(0, 1)];
        [attributed addAttributes: theme.listTextAttributesForMatchedRanges range: NSMakeRange(5, 1)];
        [attributed addAttributes: theme.previewTextAttributesForNotMatchedRanges range: NSMakeRange(18, title.length-18)];
        NSMutableParagraphStyle * style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        style.alignment = NSCenterTextAlignment;
        [attributed addAttribute: NSParagraphStyleAttributeName value: style range: NSMakeRange(0, attributed.length)];
        label.attributedStringValue = attributed;

        BOOL enabled = self.pluginEnabled;

        [NSApp runModalForWindow: window];

        if (self.pluginEnabled != enabled) {
            [[NSNotificationCenter defaultCenter] postNotificationName: FASettingsPluginEnabledDidChangeNotification object: self];
        }

        [[NSUserDefaults standardUserDefaults] synchronize];
    } else {
        NSString * reportIssueURL = [bundle objectForInfoDictionaryKey: @"FAReportIssueURL"];
        if (reportIssueURL) {
            NSAlert * alert = [NSAlert alertWithMessageText: [NSString stringWithFormat: @"Failed to open %@ settings.", bundle.lsl_bundleName]
                                              defaultButton: @"OK"
                                            alternateButton: @"Report an Issue"
                                                otherButton: nil
                                  informativeTextWithFormat: @"This might happen when updating the plugin to a newer version. To completely load the new plugin Xcode restart is required.\n\nIf the issue persists after a restart please report an issue."];
            if ([alert runModal] == NSAlertAlternateReturn) {
                [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: reportIssueURL]];
            }
        }
    }
}

- (void) windowWillClose: (NSNotification *) notification {
    NSWindow * window = notification.object;
    [window makeFirstResponder: window.contentView];
    [NSApp stopModal];
}

#pragma mark - defaults

static const BOOL kDefaultPluginEnabled = YES;

static const double kDefaultMinimumScoreThreshold = 0.01;
static const NSInteger kDefaultPrefixAnchor = 0;
static const BOOL kDefaultSortByScore = YES;
static const BOOL kDefaultFilterByScore = YES;
static const BOOL kDefaultShowScores = NO;
static const BOOL kDefaultShowInlinePreview = YES;
static const BOOL kDefaultHideCursorInNonPrefixPreview = NO;
static const BOOL kDefaultShowListHeader = YES;
static const BOOL kDefaultShowNumMatches = NO;
static const BOOL kDefaultNormalizeScores = NO;
static const BOOL kDefaultShowTiming = NO;
static NSString * const kDefaultScoreFormat = @"* #0.00";

static const double kDefaultMatchScorePower = 2.0;
static const double kDefaultPriorityPower = 0.5;
static const double kDefaultPriorityFactorPower = 0.5;
static const double kDefaultMaxPrefixBonus = 0.5;

// experimental

static const BOOL kDefaultCorrectLetterCase = NO;
static const BOOL kDefaultCorrectLetterCaseBestMatchOnly = NO;
static const BOOL kDefaultCorrectWordOrder = NO;
static const NSInteger kDefaultCorrectWordOrderAfter = 2;

- (IBAction)resetDefaults:(id)sender {
    self.pluginEnabled = kDefaultPluginEnabled;

    self.minimumScoreThreshold = kDefaultMinimumScoreThreshold;
    self.filterByScore = kDefaultFilterByScore;
    self.sortByScore = kDefaultSortByScore;
    self.showScores = kDefaultShowScores;
    self.scoreFormat = kDefaultScoreFormat;
    self.normalizeScores = kDefaultNormalizeScores;
    self.showListHeader = kDefaultShowListHeader;
    self.showNumMatches = kDefaultShowNumMatches;
    self.showInlinePreview = kDefaultShowInlinePreview;
    self.hideCursorInNonPrefixPreview = kDefaultHideCursorInNonPrefixPreview;
    self.showTiming = kDefaultShowTiming;
    self.prefixAnchor = kDefaultPrefixAnchor;

    self.matchScorePower = kDefaultMatchScorePower;
    self.priorityPower = kDefaultPriorityPower;
    self.priorityFactorPower = kDefaultPriorityFactorPower;
    self.maxPrefixBonus = kDefaultMaxPrefixBonus;

    self.correctLetterCase = kDefaultCorrectLetterCase;
    self.correctLetterCaseBestMatchOnly = kDefaultCorrectLetterCaseBestMatchOnly;
    self.correctWordOrder = kDefaultCorrectWordOrder;
    self.correctWordOrderAfter = kDefaultCorrectWordOrderAfter;

    NSUInteger processors = [[NSProcessInfo processInfo] activeProcessorCount];
    self.parallelScoring = processors > 1;
    self.maximumWorkers = processors;
}

- (void) loadFromDefaults {
    NSUInteger processors = [[NSProcessInfo processInfo] activeProcessorCount];
    BOOL kDefaultParallelScoring = processors > 1;
    NSInteger kDefaultMaximumWorkers = processors;

    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    NSNumber * number;

#define loadNumber(name, Name) \
    number = [defaults objectForKey: k ## Name ## Key]; \
    [self setValue: number ?: @(kDefault ## Name) forKey: @#name]

    loadNumber(pluginEnabled, PluginEnabled);

    loadNumber(minimumScoreThreshold, MinimumScoreThreshold);
    loadNumber(sortByScore, SortByScore);
    loadNumber(filterByScore, FilterByScore);
    loadNumber(showScores, ShowScores);
    loadNumber(parallelScoring, ParallelScoring);
    loadNumber(maximumWorkers, MaximumWorkers);
    loadNumber(normalizeScores, NormalizeScores);
    loadNumber(showInlinePreview, ShowInlinePreview);
    loadNumber(hideCursorInNonPrefixPreview, HideCursorInNonPrefixPreview);
    loadNumber(showListHeader, ShowListHeader);
    loadNumber(showNumMatches, ShowNumMatches);
    loadNumber(showTiming, ShowTiming);
    loadNumber(prefixAnchor, PrefixAnchor);

    loadNumber(matchScorePower, MatchScorePower);
    loadNumber(priorityPower, PriorityPower);
    loadNumber(priorityFactorPower, PriorityFactorPower);
    loadNumber(maxPrefixBonus, MaxPrefixBonus);

    loadNumber(correctLetterCase, CorrectLetterCase);
    loadNumber(correctLetterCaseBestMatchOnly, CorrectLetterCaseBestMatchOnly);
    loadNumber(correctWordOrder, CorrectWordOrder);
    loadNumber(correctWordOrderAfter, CorrectWordOrderAfter);

#undef loadNumber

    self.scoreFormat = [defaults stringForKey: kScoreFormatKey] ?: kDefaultScoreFormat;

    number = [defaults objectForKey: kSettingsVersionKey];

    if (!number || [number unsignedIntegerValue] < kSettingsVersion) {
        [self migrateSettingsFromVersion: [number unsignedIntegerValue]];
        NSString * pluginName = [NSBundle bundleForClass: self.class].lsl_bundleName;
        [defaults setObject: @(kSettingsVersion) forKey: kSettingsVersionKey];
        NSAlert * alert = [NSAlert alertWithMessageText: [NSString stringWithFormat: @"New settings for %@.", pluginName]
                                          defaultButton: @"View"
                                        alternateButton: @"Skip"
                                            otherButton: nil
                              informativeTextWithFormat: @"New settings are available for %@ plugin. Do you want to review them now?\n\nYou can always access the settings later from the Menu:\nEditor > %@ > Plugin Settings...", pluginName, pluginName];
        if ([alert runModal] == NSAlertDefaultReturn) {
            [self showSettingsWindow];
        }
    }

    [[NSUserDefaults standardUserDefaults] synchronize];

}

# pragma mark - migrate

- (void) migrateSettingsFromVersion:(NSUInteger)version {
    switch (version) {
        case 0: // just break, dont migrate for 0
            break;
        case 1: // dont break, fall through to higher cases
        case 2:
        case 3:
            self.showListHeader = YES;
    }
}

# pragma mark - boilerplate

// use macros to avoid some copy-paste errors

#define SETTINGS_KEY(Name) \
static NSString * const k ## Name ## Key = @"FuzzyAutocomplete"#Name

#define SETTINGS_SETTER(name, Name, type, function) SETTINGS_KEY(Name); \
- (void) set ## Name: (type) name { \
[[NSUserDefaults standardUserDefaults] setObject: function(name) forKey: k ## Name ## Key]; \
_ ## name = name; \
}

#define STRING_SETTINGS_SETTER(name, Name) SETTINGS_SETTER(name, Name, NSString *, (NSString *))
#define NUMBER_SETTINGS_SETTER(name, Name, type) SETTINGS_SETTER(name, Name, type, @)
#define DOUBLE_SETTINGS_SETTER(name, Name) NUMBER_SETTINGS_SETTER(name, Name, double)
#define BOOL_SETTINGS_SETTER(name, Name) NUMBER_SETTINGS_SETTER(name, Name, BOOL)
#define INTEGER_SETTINGS_SETTER(name, Name) NUMBER_SETTINGS_SETTER(name, Name, NSInteger)

SETTINGS_KEY(SettingsVersion);

BOOL_SETTINGS_SETTER(pluginEnabled, PluginEnabled)

BOOL_SETTINGS_SETTER(showScores, ShowScores)
BOOL_SETTINGS_SETTER(filterByScore, FilterByScore)
BOOL_SETTINGS_SETTER(sortByScore, SortByScore)
BOOL_SETTINGS_SETTER(parallelScoring, ParallelScoring)
BOOL_SETTINGS_SETTER(normalizeScores, NormalizeScores)
BOOL_SETTINGS_SETTER(showInlinePreview, ShowInlinePreview)
BOOL_SETTINGS_SETTER(hideCursorInNonPrefixPreview, HideCursorInNonPrefixPreview)
BOOL_SETTINGS_SETTER(showListHeader, ShowListHeader)
BOOL_SETTINGS_SETTER(showNumMatches, ShowNumMatches)
BOOL_SETTINGS_SETTER(showTiming, ShowTiming)
BOOL_SETTINGS_SETTER(correctLetterCase, CorrectLetterCase);
BOOL_SETTINGS_SETTER(correctLetterCaseBestMatchOnly, CorrectLetterCaseBestMatchOnly);
BOOL_SETTINGS_SETTER(correctWordOrder, CorrectWordOrder);

INTEGER_SETTINGS_SETTER(maximumWorkers, MaximumWorkers)
INTEGER_SETTINGS_SETTER(prefixAnchor, PrefixAnchor)
INTEGER_SETTINGS_SETTER(correctWordOrderAfter, CorrectWordOrderAfter);

DOUBLE_SETTINGS_SETTER(minimumScoreThreshold, MinimumScoreThreshold)
DOUBLE_SETTINGS_SETTER(matchScorePower, MatchScorePower)
DOUBLE_SETTINGS_SETTER(priorityPower, PriorityPower)
DOUBLE_SETTINGS_SETTER(priorityFactorPower, PriorityFactorPower)
DOUBLE_SETTINGS_SETTER(maxPrefixBonus, MaxPrefixBonus)

STRING_SETTINGS_SETTER(scoreFormat, ScoreFormat)

@end
