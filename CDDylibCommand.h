// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2007  Steve Nygard

#import "CDLoadCommand.h"
#include <mach-o/loader.h>

@interface CDDylibCommand : CDLoadCommand
{
    struct dylib_command dylibCommand;
    NSString *name;
}

- (id)initWithDataCursor:(CDDataCursor *)cursor machOFile:(CDMachOFile *)aMachOFile;
- (void)dealloc;

- (uint32_t)cmd;
- (uint32_t)cmdsize;

- (NSString *)name;
- (uint32_t)timestamp;
- (uint32_t)currentVersion;
- (uint32_t)compatibilityVersion;

- (NSString *)formattedCurrentVersion;
- (NSString *)formattedCompatibilityVersion;

//- (NSString *)extraDescription;

@end
