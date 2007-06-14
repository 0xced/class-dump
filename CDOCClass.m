//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2007  Steve Nygard

#import "CDOCClass.h"

#import <Foundation/Foundation.h>
#import "NSArray-Extensions.h"
#import "CDClassDump.h"
#import "CDOCIvar.h"
#import "CDOCMethod.h"
#import "CDSymbolReferences.h"
#import "CDType.h"
#import "CDTypeParser.h"
#import "CDVisitor.h"

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

- (void)addToXMLElement:(NSXMLElement *)xmlElement classDump:(CDClassDump *)aClassDump symbolReferences:(CDSymbolReferences *)symbolReferences;
{
    int count, index;
    NSXMLElement *classElement;

    if ([aClassDump shouldMatchRegex] == YES && [aClassDump regexMatchesString:[self name]] == NO)
        return;

    classElement = [NSXMLElement elementWithName:@"class"];
    [classElement addChild:[NSXMLElement elementWithName:@"name" stringValue:name]];

    if (superClassName != nil)
        [classElement addChild:[NSXMLElement elementWithName:@"superclass" stringValue:superClassName]];

    if ([protocols count] > 0) {
        NSArray *protocolsArray = [protocols arrayByMappingSelector:@selector(name)];
        count = [protocolsArray count];

        NSMutableArray *adoptedProtocolElements = [NSMutableArray arrayWithCapacity:count];

        for (index = 0; index < count; index++) {
            [adoptedProtocolElements addObject:[NSXMLElement elementWithName:@"name" stringValue:[protocolsArray objectAtIndex:index]]];
        }

        [classElement addChild:[NSXMLElement elementWithName:@"adopted-protocols" children:adoptedProtocolElements attributes:nil]];
        [symbolReferences addProtocolNamesFromArray:protocolsArray];
    }

    count = [ivars count];
    if (count > 0) {
        for (index = 0; index < count; index++)
            [[ivars objectAtIndex:index] addToXMLElement:classElement classDump:aClassDump symbolReferences:symbolReferences];
    }

    [self addMethodsToXMLElement:classElement classDump:aClassDump symbolReferences:symbolReferences];
    [xmlElement addChild:classElement];
}

- (void)registerStructuresWithObject:(id <CDStructureRegistration>)anObject phase:(int)phase;
{
    int count, index;
    CDTypeParser *parser;

    [super registerStructuresWithObject:anObject phase:phase];

    count = [ivars count];
    for (index = 0; index < count; index++) {
        CDType *aType;
        NSError *error;

        parser = [[CDTypeParser alloc] initWithType:[(CDOCIvar *)[ivars objectAtIndex:index] type]];
        aType = [parser parseType:&error];
        [aType phase:phase registerStructuresWithObject:anObject usedInMethod:NO];
        [parser release];
    }
}

- (NSString *)findTag:(CDSymbolReferences *)symbolReferences;
{
    NSMutableString *resultString = [NSMutableString string];

    [resultString appendFormat:@"@interface %@", name];
    if (superClassName != nil)
        [resultString appendFormat:@" : %@", superClassName];

    if ([protocols count] > 0)
        [resultString appendFormat:@" <%@>", [[protocols arrayByMappingSelector:@selector(name)] componentsJoinedByString:@", "]];

    return resultString;
}

- (void)recursivelyVisit:(CDVisitor *)aVisitor;
{
    unsigned int count, index;

    if ([[aVisitor classDump] shouldMatchRegex] == YES && [[aVisitor classDump] regexMatchesString:[self name]] == NO)
        return;

    [aVisitor willVisitClass:self];

    [aVisitor willVisitIvarsOfClass:self];
    count = [ivars count];
    if (count > 0) {
        for (index = 0; index < count; index++) {
            [aVisitor visitIvar:[ivars objectAtIndex:index]];
        }
    }
    [aVisitor didVisitIvarsOfClass:self];

    [self recursivelyVisitMethods:aVisitor];
    [aVisitor didVisitClass:self];
}

//
// CDTopologicalSort protocol
//

- (NSString *)identifier;
{
    return [self name];
}

- (NSArray *)dependancies;
{
    if (superClassName == nil)
        return [NSArray array];

    return [NSArray arrayWithObject:superClassName];
}

@end
