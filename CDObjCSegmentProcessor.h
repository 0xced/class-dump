//
// $Id: CDObjCSegmentProcessor.h,v 1.14 2004/02/03 03:54:45 nygard Exp $
//

//  This file is part of class-dump, a utility for examining the
//  Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004  Steve Nygard

#import <Foundation/NSObject.h>
#import "CDStructureRegistrationProtocol.h"

@class NSMutableArray, NSMutableDictionary, NSMutableString, NSString;
@class CDClassDump2, CDMachOFile;

@interface CDObjCSegmentProcessor : NSObject
{
    CDMachOFile *machOFile;
    NSMutableArray *modules;
    NSMutableDictionary *protocolsByName;
}

- (id)initWithMachOFile:(CDMachOFile *)aMachOFile;
- (void)dealloc;

- (void)process;

- (void)appendFormattedString:(NSMutableString *)resultString classDump:(CDClassDump2 *)aClassDump;
- (void)registerStructuresWithObject:(id <CDStructureRegistration>)anObject phase:(int)phase;

- (NSString *)description;

- (void)registerClassesWithObject:(NSMutableDictionary *)aDictionary;
- (void)generateSeparateHeadersClassDump:(CDClassDump2 *)aClassDump;

@end
