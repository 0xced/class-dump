// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 2009 Steve Nygard.  All rights reserved.

#import "CDObjectiveCProcessor.h"

@class CDOCClass, CDOCCategory, CDOCProtocol;

@interface CDObjectiveC2Processor : CDObjectiveCProcessor
{
}

- (id)initWithMachOFile:(CDMachOFile *)aMachOFile;

- (NSString *)externalClassNameForAddress:(uint64_t)address;

- (void)process;

- (void)loadProtocols;
- (CDOCProtocol *)protocolAtAddress:(uint64_t)address;

- (void)loadClasses;
- (void)loadCategories;

- (CDOCCategory *)loadCategoryAtAddress:(uint64_t)address;

- (CDOCClass *)loadClassAtAddress:(uint64_t)address;
- (NSArray *)loadPropertiesAtAddress:(uint64_t)address;
- (CDOCClass *)loadMetaClassAtAddress:(uint64_t)address;

- (NSArray *)loadMethodsAtAddress:(uint64_t)address;
- (NSArray *)loadIvarsAtAddress:(uint64_t)address;

- (NSArray *)uniquedProtocolListAtAddress:(uint64_t)address;

@end
