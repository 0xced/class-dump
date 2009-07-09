// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2009 Steve Nygard.

#import "CDTextClassDumpVisitor.h"

#include <mach-o/arch.h>

#import "NSArray-Extensions.h"
#import "CDClassDump.h"
#import "CDObjectiveC1Processor.h"
#import "CDMachOFile.h"
#import "CDOCProtocol.h"
#import "CDLCDylib.h"
#import "CDOCClass.h"
#import "CDOCCategory.h"
#import "CDSymbolReferences.h"
#import "CDOCMethod.h"
#import "CDOCProperty.h"
#import "CDTypeFormatter.h"

static BOOL debug = NO;

@implementation CDTextClassDumpVisitor

- (id)init;
{
    if ([super init] == nil)
        return nil;

    resultString = [[NSMutableString alloc] init];
    symbolReferences = [[CDSymbolReferences alloc] init];

    return self;
}

- (void)dealloc;
{
    [resultString release];
    [symbolReferences release];

    [super dealloc];
}

- (void)writeResultToStandardOutput;
{
    NSData *data;

    data = [resultString dataUsingEncoding:NSUTF8StringEncoding];
    [(NSFileHandle *)[NSFileHandle fileHandleWithStandardOutput] writeData:data];
}

- (void)willVisitClass:(CDOCClass *)aClass;
{
    NSArray *protocols;

    [resultString appendFormat:@"@interface %@", [aClass name]];
    if ([aClass superClassName] != nil)
        [resultString appendFormat:@" : %@", [aClass superClassName]];

    protocols = [aClass protocols];
    if ([protocols count] > 0) {
        [resultString appendFormat:@" <%@>", [[protocols arrayByMappingSelector:@selector(name)] componentsJoinedByString:@", "]];
        [symbolReferences addProtocolNamesFromArray:[protocols arrayByMappingSelector:@selector(name)]];
    }

    [resultString appendString:@"\n"];
}

- (void)didVisitClass:(CDOCClass *)aClass;
{
    if ([aClass hasMethods])
        [resultString appendString:@"\n"];

    [resultString appendString:@"@end\n\n"];
}

- (void)willVisitIvarsOfClass:(CDOCClass *)aClass;
{
    [resultString appendString:@"{\n"];
}

- (void)didVisitIvarsOfClass:(CDOCClass *)aClass;
{
    [resultString appendString:@"}\n\n"];
}

- (void)willVisitCategory:(CDOCCategory *)aCategory;
{
    NSArray *protocols;

    [resultString appendFormat:@"@interface %@ (%@)", [aCategory className], [aCategory name]];

    protocols = [aCategory protocols];
    if ([protocols count] > 0) {
        [resultString appendFormat:@" <%@>", [[protocols arrayByMappingSelector:@selector(name)] componentsJoinedByString:@", "]];
        [symbolReferences addProtocolNamesFromArray:[protocols arrayByMappingSelector:@selector(name)]];
    }

    [resultString appendString:@"\n"];
}

- (void)didVisitCategory:(CDOCCategory *)aCategory;
{
    [resultString appendString:@"@end\n\n"];
}

- (void)willVisitProtocol:(CDOCProtocol *)aProtocol;
{
    NSArray *protocols;

    [resultString appendFormat:@"@protocol %@", [aProtocol name]];

    protocols = [aProtocol protocols];
    if ([protocols count] > 0) {
        [resultString appendFormat:@" <%@>", [[protocols arrayByMappingSelector:@selector(name)] componentsJoinedByString:@", "]];
        [symbolReferences addProtocolNamesFromArray:[protocols arrayByMappingSelector:@selector(name)]];
    }

    [resultString appendString:@"\n"];
}

- (void)willVisitOptionalMethods;
{
    [resultString appendString:@"\n@optional\n"];
}

- (void)didVisitProtocol:(CDOCProtocol *)aProtocol;
{
    [resultString appendString:@"@end\n\n"];
}

- (void)visitClassMethod:(CDOCMethod *)aMethod;
{
    [resultString appendString:@"+ "];
    [aMethod appendToString:resultString classDump:classDump symbolReferences:symbolReferences];
    [resultString appendString:@"\n"];
}

- (void)visitInstanceMethod:(CDOCMethod *)aMethod;
{
    [resultString appendString:@"- "];
    [aMethod appendToString:resultString classDump:classDump symbolReferences:symbolReferences];
    [resultString appendString:@"\n"];
}

- (void)visitIvar:(CDOCIvar *)anIvar;
{
    [anIvar appendToString:resultString classDump:classDump symbolReferences:symbolReferences];
    [resultString appendString:@"\n"];
}

- (void)_visitProperty:(CDOCProperty *)aProperty parsedType:(CDType *)parsedType attributes:(NSArray *)attrs;
{
    NSMutableArray *alist, *unknownAttrs;
    NSString *backingVar = nil;
    NSString *formattedString;

    alist = [[NSMutableArray alloc] init];
    unknownAttrs = [[NSMutableArray alloc] init];

    for (NSString *attr in attrs) {
        if ([attr hasPrefix:@"T"]) {
            if (debug) NSLog(@"Warning: Property attribute 'T' should occur only occur at the beginning");
        } else if ([attr hasPrefix:@"R"]) {
            [alist addObject:@"readonly"];
        } else if ([attr hasPrefix:@"C"]) {
            [alist addObject:@"copy"];
        } else if ([attr hasPrefix:@"&"]) {
            [alist addObject:@"retain"];
        } else if ([attr hasPrefix:@"G"]) {
            [alist addObject:[NSString stringWithFormat:@"getter=%@", [attr substringFromIndex:1]]];
        } else if ([attr hasPrefix:@"S"]) {
            [alist addObject:[NSString stringWithFormat:@"setter=%@", [attr substringFromIndex:1]]];
        } else if ([attr hasPrefix:@"V"]) {
            backingVar = [attr substringFromIndex:1];
        } else {
            if (debug) NSLog(@"Warning: Unknown property attribute %@", attr);
            [unknownAttrs addObject:attr];
        }
    }

    if ([alist count] > 0) {
        [resultString appendFormat:@"@property(%@) ", [alist componentsJoinedByString:@", "]];
    } else {
        [resultString appendString:@"@property "];
    }

    formattedString = [[classDump propertyTypeFormatter] formatVariable:[aProperty name] parsedType:parsedType symbolReferences:symbolReferences];
    [resultString appendFormat:@"%@;", formattedString];

    if (backingVar != nil) {
        if ([backingVar isEqualToString:[aProperty name]]) {
            [resultString appendFormat:@" // @synthesize %@;", [aProperty name]];
        } else {
            [resultString appendFormat:@" // @synthesize %@=%@;", [aProperty name], backingVar];
        }

        //[resultString appendFormat:@"   %@", aProperty];
    } else {
        //[resultString appendFormat:@" // %@", aProperty];
    }

    [resultString appendString:@"\n"];
    if ([unknownAttrs count] > 0) {
        // TODO (2009-07-09): Move the parsing into CDOCProperty, and then skip the type part for obnoxiously long types
        [resultString appendFormat:@"// Preceeding property had unknown attributes: %@\n", [unknownAttrs componentsJoinedByString:@","]];
        [resultString appendFormat:@"// Original attribute string: %@\n\n", [aProperty attributeString]];
    }

    [alist release];
    [unknownAttrs release];
}

- (void)visitProperty:(CDOCProperty *)aProperty;
{
    CDType *parsedType;

    parsedType = [aProperty type];
    if (parsedType == nil) {
        if ([[aProperty attributeString] hasPrefix:@"T"]) {
            [resultString appendFormat:@"// Error parsing type for property %@:\n", [aProperty name]];
            [resultString appendFormat:@"// Property attributes: %@\n\n", [aProperty attributeString]];
        } else {
            [resultString appendFormat:@"// Error: Property attributes should begin with the type ('T') attribute, property name: %@\n", [aProperty name]];
            [resultString appendFormat:@"// Property attributes: %@\n\n", [aProperty attributeString]];
        }
    } else {
        [self _visitProperty:aProperty parsedType:parsedType attributes:[aProperty attributes]];
    }
}

- (void)didVisitPropertiesOfClass:(CDOCClass *)aClass;
{
    if ([[aClass properties] count] > 0)
        [resultString appendString:@"\n"];
}

@end
