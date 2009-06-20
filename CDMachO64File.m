//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 2009 Steve Nygard.  All rights reserved.

#import "CDMachO64File.h"

#import "CDLoadCommand.h"

@implementation CDMachO64File

- (id)initWithData:(NSData *)_data;
{
    CDDataCursor *cursor;

    if ([super init] == nil)
        return nil;

    cursor = [[CDDataCursor alloc] initWithData:_data];
    header.magic = [cursor readLittleInt32];

    NSLog(@"(testing macho 64) magic: 0x%x", header.magic);
    if (header.magic == MH_MAGIC_64) {
        byteOrder = CDByteOrderLittleEndian;
    } else if (header.magic == MH_CIGAM_64) {
        byteOrder = CDByteOrderBigEndian;
    } else {
        NSLog(@"Not a 64-bit MachO file.");
        [cursor release];
        [self release];
        return nil;
    }

    NSLog(@"byte order: %d", byteOrder);
    [cursor setByteOrder:byteOrder];

    header.cputype = [cursor readInt32];
    header.cpusubtype = [cursor readInt32];
    header.filetype = [cursor readInt32];
    header.ncmds = [cursor readInt32];
    header.sizeofcmds = [cursor readInt32];
    header.flags = [cursor readInt32];
    header.reserved = [cursor readInt32];

    NSLog(@"cpusubtype: 0x%08x", header.cpusubtype);
    NSLog(@"filetype: 0x%08x", header.filetype);
    NSLog(@"ncmds: %u", header.ncmds);
    NSLog(@"sizeofcmds: %u", header.sizeofcmds);
    NSLog(@"flags: 0x%08x", header.flags);
    NSLog(@"reserved: 0x%08x", header.reserved);

    [self _readLoadCommands:cursor count:header.ncmds];

    return self;
}

- (uint32_t)magic;
{
    return header.magic;
}

- (cpu_type_t)cputype;
{
    return header.cputype;
}

- (cpu_subtype_t)cpusubtype;
{
    return header.cpusubtype;
}

- (uint32_t)filetype;
{
    return header.filetype;
}

- (uint32_t)flags;
{
    return header.flags;
}

- (NSString *)bestMatchForLocalArch;
{
    return CDNameForCPUType(header.cputype, header.cpusubtype);
}

- (NSString *)description;
{
    return [NSString stringWithFormat:@"magic: 0x%08x, cputype: %d, cpusubtype: %d, filetype: %d, ncmds: %d, sizeofcmds: %d, flags: 0x%x, uses64BitABI? %d",
                     header.magic, header.cputype, header.cpusubtype, header.filetype, [loadCommands count], 0, header.flags, _flags.uses64BitABI];
}

@end
