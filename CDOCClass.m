//  This file is part of class-dump, a utility for examining the
//  Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004  Steve Nygard

#import "CDOCClass.h"

#import "rcsid.h"
#import <Foundation/Foundation.h>
#import "NSArray-Extensions.h"
#import "CDOCIvar.h"
#import "CDOCMethod.h"
#import "CDType.h"
#import "CDTypeParser.h"

RCS_ID("$Header: /Volumes/Data/tmp/Tools/class-dump/CDOCClass.m,v 1.26 2004/01/20 05:00:23 nygard Exp $");

@implementation CDOCClass

- (void)dealloc;
{
    [superClassName release];
    [ivars release];

    [super dealloc];
}

- (NSString *)superClassName;
{
    return superClassName;
}

- (void)setSuperClassName:(NSString *)newSuperClassName;
{
    if (newSuperClassName == superClassName)
        return;

    [superClassName release];
    superClassName = [newSuperClassName retain];
}

- (NSArray *)ivars;
{
    return ivars;
}

- (void)setIvars:(NSArray *)newIvars;
{
    if (newIvars == ivars)
        return;

    [ivars release];
    ivars = [newIvars retain];
}

- (void)appendToString:(NSMutableString *)resultString classDump:(CDClassDump2 *)aClassDump;
{
    NSArray *sortedMethods;
    int count, index;

    [resultString appendFormat:@"@interface %@", name];
    if (superClassName != nil)
        [resultString appendFormat:@":%@", superClassName]; // Add space later, keep this way for backwards compatability

    if ([protocols count] > 0)
        [resultString appendFormat:@" <%@>", [[protocols arrayByMappingSelector:@selector(name)] componentsJoinedByString:@", "]];

    [resultString appendString:@"\n{\n"];
    count = [ivars count];
    if (count > 0) {
        for (index = 0; index < count; index++) {
            [[ivars objectAtIndex:index] appendToString:resultString classDump:aClassDump];
            [resultString appendString:@"\n"];
        }
    }

    [resultString appendString:@"}\n\n"];

    sortedMethods = [classMethods sortedArrayUsingSelector:@selector(ascendingCompareByName:)];
    count = [sortedMethods count];
    if (count > 0) {
        for (index = 0; index < count; index++) {
            [resultString appendString:@"+ "];
            [[sortedMethods objectAtIndex:index] appendToString:resultString classDump:aClassDump];
            [resultString appendString:@"\n"];
        }
    }

    sortedMethods = [instanceMethods sortedArrayUsingSelector:@selector(ascendingCompareByName:)];
    count = [sortedMethods count];
    if (count > 0) {
        for (index = 0; index < count; index++) {
            [resultString appendString:@"- "];
            [[sortedMethods objectAtIndex:index] appendToString:resultString classDump:aClassDump];
            [resultString appendString:@"\n"];
        }
    }

    if ([classMethods count] > 0 || [instanceMethods count] > 0)
        [resultString appendString:@"\n"];
    [resultString appendString:@"@end\n\n"];
}

- (void)registerStructuresWithObject:(id <CDStructureRegistration>)anObject phase:(int)phase;
{
    int count, index;
    CDTypeParser *parser;

    [super registerStructuresWithObject:anObject phase:phase];

    count = [ivars count];
    for (index = 0; index < count; index++) {
        CDType *aType;

        parser = [[CDTypeParser alloc] initWithType:[(CDOCIvar *)[ivars objectAtIndex:index] type]];
        aType = [parser parseType];
        [aType phase:phase registerStructuresWithObject:anObject usedInMethod:NO];
        [parser release];
    }
}

@end
