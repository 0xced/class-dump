//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2007  Steve Nygard

#import "CDSection.h"

#include <mach-o/swap.h>
#import <Foundation/Foundation.h>
#import "CDFatFile.h"
#import "CDMachOFile.h"
#import "CDSegmentCommand.h"

@implementation CDSection

// Just to resolve multiple different definitions...
- (id)initWithDataCursor:(CDDataCursor *)cursor segment:(CDSegmentCommand *)aSegment;
{
    char buf[17];

    if ([super init] == nil)
        return nil;

    nonretainedSegment = aSegment;

    [cursor readBytesOfLength:16 intoBuffer:section.sectname];
    [cursor readBytesOfLength:16 intoBuffer:section.segname];
    section.addr = [cursor readInt32];
    section.size = [cursor readInt32];
    section.offset = [cursor readInt32];
    section.align = [cursor readInt32];
    section.reloff = [cursor readInt32];
    section.nreloc = [cursor readInt32];
    section.flags = [cursor readInt32];
    section.reserved1 = [cursor readInt32];
    section.reserved2 = [cursor readInt32];

    // These aren't guaranteed to be null terminated.  Witness __cstring_object in __OBJC segment

    memcpy(buf, section.segname, 16);
    buf[16] = 0;
    segmentName = [[NSString alloc] initWithBytes:buf length:strlen(buf) encoding:NSASCIIStringEncoding];

    memcpy(buf, section.sectname, 16);
    buf[16] = 0;
    sectionName = [[NSString alloc] initWithBytes:buf length:strlen(buf) encoding:NSASCIIStringEncoding];

    //NSLog(@"segmentName: '%@', sectionName: '%@'", segmentName, sectionName);

    return self;
}

- (void)dealloc;
{
    [segmentName release];
    [sectionName release];

    [super dealloc];
}

- (CDSegmentCommand *)segment;
{
    return nonretainedSegment;
}

- (CDMachOFile *)machOFile;
{
    return [[self segment] machOFile];
}

- (NSString *)segmentName;
{
    return segmentName;
}

- (NSString *)sectionName;
{
    return sectionName;
}

- (unsigned long)addr;
{
    return section.addr;
}

- (unsigned long)size;
{
    return section.size;
}

- (unsigned long)offset;
{
    return section.offset;
}

- (const void *)dataPointer;
{
    return [[self machOFile] bytes] + [self offset];
}

- (NSString *)description;
{
    return [NSString stringWithFormat:@"addr: 0x%08x, offset: %8d, size: %8d [0x%8x], segment; '%@', section: '%@'",
                     [self addr], [self offset], [self size], [self size], segmentName, sectionName];
}

- (BOOL)containsAddress:(unsigned long)vmaddr;
{
    // TODO (2003-12-06): And what happens when the filesize of the segment is less than the vmsize?
    return (vmaddr >= [self addr]) && (vmaddr < [self addr] + [self size]);
}

- (unsigned long)segmentOffsetForVMAddr:(unsigned long)vmaddr;
{
    return vmaddr - [self addr];
}

@end
