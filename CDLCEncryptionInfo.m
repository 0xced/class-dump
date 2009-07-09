// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2009 Steve Nygard.

#import "CDLCEncryptionInfo.h"

#import "CDDataCursor.h"

@implementation CDLCEncryptionInfo

- (id)initWithDataCursor:(CDDataCursor *)cursor machOFile:(CDMachOFile *)aMachOFile;
{
    if ([super initWithDataCursor:cursor machOFile:aMachOFile] == nil)
        return nil;

    NSLog(@"CDLCEncryptionInfo");

    encryptionInfoCommand.cmd = [cursor readInt32];
    encryptionInfoCommand.cmdsize = [cursor readInt32];

    encryptionInfoCommand.cryptoff = [cursor readInt32];
    encryptionInfoCommand.cryptsize = [cursor readInt32];
    encryptionInfoCommand.cryptid = [cursor readInt32];

    return self;
}

- (uint32_t)cmd;
{
    return encryptionInfoCommand.cmd;
}

- (uint32_t)cmdsize;
{
    return encryptionInfoCommand.cmdsize;
}

@end
