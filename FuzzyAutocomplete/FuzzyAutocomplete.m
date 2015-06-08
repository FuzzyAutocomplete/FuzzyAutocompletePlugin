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

#import <objc/runtime.h>

#import "FuzzyAutocomplete.h"
#import "FASettings.h"
#import "FAMatchPattern.h"

#import "DVTTextCompletionSession+FuzzyAutocomplete.h"
#import "DVTTextCompletionListWindowController+FuzzyAutocomplete.h"
#import "DVTTextCompletionInlinePreviewController+FuzzyAutocomplete.h"

@implementation FuzzyAutocomplete

+ (void)pluginDidLoad:(NSBundle *)plugin {
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [NSBundle mainBundle].lsl_bundleName;

    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            [self swapClasses];
            [self createMenuItem];
            [[NSNotificationCenter defaultCenter] addObserver: self
                                                     selector: @selector(applicationDidFinishLaunching:)
                                                         name: NSApplicationDidFinishLaunchingNotification
                                                       object: nil];
            [[NSNotificationCenter defaultCenter] addObserver: self
                                                     selector: @selector(menuDidChange:)
                                                         name: NSMenuDidChangeItemNotification
                                                       object: nil];
            
            // when installing through Alcatraz the application has already launched
            if ([NSApplication sharedApplication].currentEvent) {
                [self applicationDidFinishLaunching: nil];
            }
            
        });
    }
}

+ (void) swapClasses {
    Class class = NSClassFromString(@"DVTOpenQuicklyPattern");
    if (!class) {
        class = NSClassFromString(@"IDEOpenQuicklyPattern");
    }
    if (class) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        class_setSuperclass([FAMatchPattern class], class);
#pragma clang diagnostic pop
    }
}

+ (void) pluginEnabledOrDisabled: (NSNotification *) notification {
    if (notification.object == [FASettings currentSettings]) {
        [self swizzleMethods];
    }
}

+ (void) applicationDidFinishLaunching: (NSNotification *) notification {
    [[NSNotificationCenter defaultCenter] removeObserver: self name: NSApplicationDidFinishLaunchingNotification object: nil];
    [[FASettings currentSettings] loadFromDefaults];
    if ([FASettings currentSettings].pluginEnabled) {
        [self swizzleMethods];
    }
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(pluginEnabledOrDisabled:)
                                                 name: FASettingsPluginEnabledDidChangeNotification
                                               object: nil];
}

+ (void) menuDidChange: (NSNotification *) notification {
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: NSMenuDidChangeItemNotification
                                                  object: nil];

    [self createMenuItem];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(menuDidChange:)
                                                 name: NSMenuDidChangeItemNotification
                                               object: nil];
}

+ (void)createMenuItem {
    NSBundle * pluginBundle = [NSBundle bundleForClass: self];
    NSString * name = pluginBundle.lsl_bundleName;
    NSMenuItem * editorMenuItem = [[NSApp mainMenu] itemWithTitle: @"Editor"];

    if (editorMenuItem && ![editorMenuItem.submenu itemWithTitle: name]) {
        
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

        NSInteger menuIndex = [editorMenuItem.submenu indexOfItemWithTitle: @"Show Completions"];
        if (menuIndex == -1) {
            [editorMenuItem.submenu addItem: [NSMenuItem separatorItem]];
            [editorMenuItem.submenu addItem: fuzzyItem];
        } else {
            [editorMenuItem.submenu insertItem: fuzzyItem atIndex: menuIndex];
        }
    }
}

+ (void) swizzleMethods {
    [DVTTextCompletionSession fa_swizzleMethods];
    [DVTTextCompletionListWindowController fa_swizzleMethods];
    [DVTTextCompletionInlinePreviewController fa_swizzleMethods];
}

@end
