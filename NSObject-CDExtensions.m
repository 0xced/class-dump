// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2009 Steve Nygard.

#import "NSObject-CDExtensions.h"

#import <Foundation/Foundation.h>

@implementation NSObject (CDExtensions)

- (void)performSelector:(SEL)aSelector withObjectsFromArray:(NSArray *)anArray;
{
    for (id object in anArray)
        [self performSelector:aSelector withObject:object];
}

@end
