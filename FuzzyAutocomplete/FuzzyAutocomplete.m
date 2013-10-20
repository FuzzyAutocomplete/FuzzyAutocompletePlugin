//
//  FuzzyAutocomplete.m
//  FuzzyAutocomplete
//
//  Created by Jack Chen on 18/10/2013.
//  Copyright (c) 2013 chendo interactive. All rights reserved.
//

#import "FuzzyAutocomplete.h"

@implementation FuzzyAutocomplete

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    ALog(@"Plugin loaded");
    [self sharedPlugin];
}

+ (instancetype)sharedPlugin
{
    static FuzzyAutocomplete *plugin;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        plugin = [[self alloc] init];
    });
    return plugin;
}

- (instancetype)init
{
    if (self = [super init]) {
//        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationListener:) name:nil object:nil];
    }
    return self;
}

- (void)dealloc
{
 
}

- (void)notificationListener:(NSNotification *)notification {
	// let's filter all the "normal" NSxxx events so that we only
	// really see the Xcode specific events.
    if ([[notification name] rangeOfString:@"NS"].location != NSNotFound)
        return;
    if ([[notification name] rangeOfString:@"_NS"].location != NSNotFound)
        return;

    NSLog(@"  Notification: %@", [notification name]);
    
}

@end
