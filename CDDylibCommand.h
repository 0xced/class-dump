//
// $Id: CDDylibCommand.h,v 1.4 2004/01/06 02:39:25 nygard Exp $
//

//  This file is part of class-dump, a utility for examining the
//  Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004  Steve Nygard

#import "CDLoadCommand.h"
#include <mach-o/loader.h>

@interface CDDylibCommand : CDLoadCommand
{
    const struct dylib_command *dylibCommand;
    NSString *name;
}

- (id)initWithPointer:(const void *)ptr machOFile:(CDMachOFile *)aMachOFile;
- (void)dealloc;

- (NSString *)name;
- (unsigned long)timestamp;
- (unsigned long)currentVersion;
- (unsigned long)compatibilityVersion;

- (NSString *)formattedCurrentVersion;
- (NSString *)formattedCompatibilityVersion;

//- (NSString *)extraDescription;

@end
