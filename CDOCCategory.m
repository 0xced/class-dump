//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2007  Steve Nygard

#import "CDOCCategory.h"

#import <Foundation/Foundation.h>
#import "CDClassDump.h"
#import "CDOCMethod.h"
#import "CDSymbolReferences.h"
#import "NSArray-Extensions.h"
#import "CDVisitor.h"

@implementation CDOCCategory

- (void)dealloc;
{
    [className release];

    [super dealloc];
}

- (NSString *)className;
{
    return className;
}

- (void)setClassName:(NSString *)newClassName;
{
    if (newClassName == className)
        return;

    [className release];
    className = [newClassName retain];
}

- (void)addToXMLElement:(NSXMLElement *)xmlElement classDump:(CDClassDump *)aClassDump symbolReferences:(CDSymbolReferences *)symbolReferences;
{
    if ([aClassDump shouldMatchRegex] == YES && [aClassDump regexMatchesString:[self sortableName]] == NO)
        return;

    NSXMLElement *categoryElement = [NSXMLElement elementWithName:@"category"];

    [categoryElement addChild:[NSXMLElement elementWithName:@"name" stringValue:name]];
    [categoryElement addChild:[NSXMLElement elementWithName:@"class-name" stringValue:className]];

    if ([protocols count] > 0) {
        NSArray *protocolsArray = [protocols arrayByMappingSelector:@selector(name)];
        unsigned count = [protocolsArray count];
        unsigned index;

        NSMutableArray *adoptedProtocolElements = [NSMutableArray arrayWithCapacity:count];

        for (index = 0; index < count; index++) {
            [adoptedProtocolElements addObject:[NSXMLElement elementWithName:@"name" stringValue:[protocolsArray objectAtIndex:index]]];
        }

        [categoryElement addChild:[NSXMLElement elementWithName:@"adopted-protocols" children:adoptedProtocolElements attributes:nil]];
        [symbolReferences addProtocolNamesFromArray:protocolsArray];
    }

    [self addMethodsToXMLElement:categoryElement classDump:aClassDump symbolReferences:symbolReferences];

    [xmlElement addChild:categoryElement];
}

- (NSString *)sortableName;
{
    return [NSString stringWithFormat:@"%@ (%@)", className, name];
}

- (NSString *)findTag:(CDSymbolReferences *)symbolReferences;
{
    NSMutableString *resultString = [NSMutableString string];

    [resultString appendFormat:@"@interface %@ (%@)", className, name];

    if ([protocols count] > 0)
        [resultString appendFormat:@" <%@>", [[protocols arrayByMappingSelector:@selector(name)] componentsJoinedByString:@", "]];

    return resultString;
}

- (void)recursivelyVisit:(CDVisitor *)aVisitor;
{
    if ([[aVisitor classDump] shouldMatchRegex] == YES && [[aVisitor classDump] regexMatchesString:[self name]] == NO)
        return;

    [aVisitor willVisitCategory:self];
    [self recursivelyVisitMethods:aVisitor];
    [aVisitor didVisitCategory:self];
}

//
// CDTopologicalSort protocol
//

- (NSString *)identifier;
{
    return [self sortableName];
}

- (NSArray *)dependancies;
{
    if (className == nil)
        return [NSArray array];

    return [NSArray arrayWithObject:className];
}

@end
