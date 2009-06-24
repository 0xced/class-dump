// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2009 Steve Nygard.

#import "CDLoadCommand.h"
#include <mach-o/loader.h>

@class CDSection;

@interface CDLCSegment : CDLoadCommand
{
    NSString *name;
    NSMutableArray *sections;

    NSMutableData *decryptedData;
}

- (id)initWithDataCursor:(CDDataCursor *)cursor machOFile:(CDMachOFile *)aMachOFile;
- (void)dealloc;

- (NSString *)name;
- (void)setName:(NSString *)newName;

- (NSArray *)sections;

- (NSUInteger)fileoff;
- (NSUInteger)filesize;
- (uint32_t)flags;
- (BOOL)isProtected;

- (NSString *)flagDescription;
- (NSString *)extraDescription;

- (BOOL)containsAddress:(NSUInteger)address;
- (CDSection *)sectionContainingAddress:(NSUInteger)address;
- (CDSection *)sectionWithName:(NSString *)aName;
- (NSUInteger)fileOffsetForAddress:(NSUInteger)address;
- (NSUInteger)segmentOffsetForAddress:(NSUInteger)address;

- (void)appendToString:(NSMutableString *)resultString verbose:(BOOL)isVerbose;

- (void)writeSectionData;

- (NSData *)decryptedData;

@end
