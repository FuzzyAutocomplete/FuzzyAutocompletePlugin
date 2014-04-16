//
//  FuzzyAutocomplete.m
//  FuzzyAutocomplete
//
//  Created by Jack Chen on 18/10/2013.
//  Copyright (c) 2013 Sproutcube. All rights reserved.
//
//  Extended by Leszek Slazynski.
//  Copyright (c) 2014 United Lines of Code. All rights reserved.
//

#import "FuzzyAutocomplete.h"
#import "FASettings.h"

@implementation FuzzyAutocomplete

+ (void)pluginDidLoad:(NSBundle *)plugin {
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [NSBundle mainBundle].lsl_bundleName;

    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            [self createMenuItem: plugin];
        });
    }
}

+ (void)createMenuItem: (NSBundle *) pluginBundle {
    NSString * name = pluginBundle.lsl_bundleName;
    NSMenuItem * xcodeMenuItem = [[NSApp mainMenu] itemAtIndex: 0];
    NSMenuItem * fuzzyItem = [[NSMenuItem alloc] initWithTitle: name
                                                       action: NULL
                                                keyEquivalent: @""];

    NSString * version = [@"Plugin Version: " stringByAppendingString: pluginBundle.lsl_bundleVersion];
    NSMenuItem * versionItem = [[NSMenuItem alloc] initWithTitle: version
                                                          action: NULL
                                                   keyEquivalent: @""];

    NSMenuItem * settingsItem = [[NSMenuItem alloc] initWithTitle: @"Plugin Settings..."
                                                           action: @selector(showSettingsWindow)
                                                    keyEquivalent: @""];

    settingsItem.target = [FASettings currentSettings];

    fuzzyItem.submenu = [[NSMenu alloc] initWithTitle: name];
    [fuzzyItem.submenu addItem: versionItem];
    [fuzzyItem.submenu addItem: settingsItem];

    NSInteger menuIndex = [xcodeMenuItem.submenu indexOfItemWithTitle: @"Behaviors"];
    if (menuIndex == -1) {
        menuIndex = 3;
    } else {
        ++menuIndex;
    }

    [xcodeMenuItem.submenu insertItem: fuzzyItem atIndex: menuIndex];
}

@end
