//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 2007 Steve Nygard.  All rights reserved.

#import "CDClassDumpVisitor.h"

#include <mach-o/arch.h>

#import "NSArray-Extensions.h"
#import "CDClassDump.h"
#import "CDObjCSegmentProcessor.h"
#import "CDMachOFile.h"
#import "CDOCProtocol.h"
#import "CDDylibCommand.h"
#import "CDOCClass.h"
#import "CDOCCategory.h"
#import "CDSymbolReferences.h"

@implementation CDClassDumpVisitor

- (void)willBeginVisiting;
{
    [super willBeginVisiting];

    [classDump appendHeaderToString:resultString];

    if ([classDump containsObjectiveCSegments]) {
        [classDump appendStructuresToString:resultString symbolReferences:nil];
        //[resultString appendString:@"// [structures go here]\n"];
    } else {
        [resultString appendString:@"This file does not contain any Objective-C runtime information.\n"];
    }
}

- (void)didEndVisiting;
{
    [super didEndVisiting];

    [self writeResultToStandardOutput];
}

- (void)visitObjectiveCSegment:(CDObjCSegmentProcessor *)anObjCSegment;
{
    CDMachOFile *machOFile;
    const NXArchInfo *archInfo;

    machOFile = [anObjCSegment machOFile];

    [resultString appendString:@"/*\n"];
    [resultString appendFormat:@" * File: %@\n", [machOFile filename]];

    archInfo = NXGetArchInfoFromCpuType([machOFile cpuType], [machOFile cpuSubtype]);
    if (archInfo != NULL)
        [resultString appendFormat:@" * Arch: %s (%s)\n", archInfo->description, archInfo->name];

    if ([machOFile filetype] == MH_DYLIB) {
        CDDylibCommand *identifier;

        identifier = [machOFile dylibIdentifier];
        if (identifier != nil)
            [resultString appendFormat:@" *       Current version: %@, Compatibility version: %@\n",
                          [identifier formattedCurrentVersion], [identifier formattedCompatibilityVersion]];
    }

    if ([machOFile hasProtectedSegments])
        [resultString appendString:@" *       (This file has protected segments -- Objective-C information may be missing.)\n"];
    [resultString appendString:@" */\n\n"];
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

- (void)didVisitProtocol:(CDOCProtocol *)aProtocol;
{
    [resultString appendString:@"@end\n\n"];
}

@end
