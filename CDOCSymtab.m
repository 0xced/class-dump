//
// $Id: CDOCSymtab.m,v 1.7 2004/01/06 01:51:55 nygard Exp $
//

//  This file is part of class-dump, a utility for exmaing the
//  Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004  Steve Nygard

#import "CDOCSymtab.h"

#import <Foundation/Foundation.h>

@implementation CDOCSymtab

- (id)init;
{
    if ([super init] == nil)
        return nil;

    classes = nil;
    categories = nil;

    return self;
}

- (void)dealloc;
{
    [classes release];
    [categories release];

    [super dealloc];
}

- (NSArray *)classes;
{
    return classes;
}

- (void)setClasses:(NSArray *)newClasses;
{
    if (newClasses == classes)
        return;

    [classes release];
    classes = [newClasses retain];
}

- (NSArray *)categories;
{
    return categories;
}

- (void)setCategories:(NSArray *)newCategories;
{
    if (newCategories == categories)
        return;

    [categories release];
    categories = [newCategories retain];
}

- (NSString *)description;
{
    return [NSString stringWithFormat:@"[%@] classes: %@, categories: %@", NSStringFromClass([self class]), classes, categories];
}

- (void)appendToString:(NSMutableString *)resultString classDump:(CDClassDump2 *)aClassDump;
{
    int count, index;

    count = [classes count];
    for (index = 0; index < count; index++)
        [[classes objectAtIndex:index] appendToString:resultString classDump:aClassDump];

    // TODO: And categories.

    count = [categories count];
    for (index = 0; index < count; index++)
        [[categories objectAtIndex:index] appendToString:resultString classDump:aClassDump];
}

@end
