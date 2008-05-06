//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2007  Steve Nygard

#import "CDFatFile.h"

#include <mach-o/arch.h>
#include <mach-o/swap.h>
#import <Foundation/Foundation.h>
#import "CDFatArch.h"
#import "CDMachOFile.h"

// The fat_header and fat_arch structures are stored in big endian-byte order.
// TODO (2005-07-27): For Intel, we'll need to swap those structs.

@implementation CDFatFile

- (id)initWithData:(NSData *)someData;
{
    if ([super init] == nil)
        return nil;

    return self;
}

- (id)initWithFilename:(NSString *)aFilename;
{
    BOOL shouldSwapBytes;

    if ([super init] == nil)
        return nil;

    shouldSwapBytes = NO;

    data = [[NSData alloc] initWithContentsOfMappedFile:aFilename];
    if (data == nil) {
        NSLog(@"Couldn't read file: %@", aFilename);
        [self release];
        return nil;
    }

    header = *(struct fat_header *)[data bytes];
    if (header.magic == FAT_CIGAM) {
        shouldSwapBytes = YES;
        swap_fat_header(&header, CD_THIS_BYTE_ORDER);
    }

    if (header.magic != FAT_MAGIC) {
        [self release];
        return nil;
    }

    arches = [[NSMutableArray alloc] init];
    [self _processFatArchesWithPointer:[data bytes] + sizeof(struct fat_header) swapBytes:shouldSwapBytes];

    return self;
}

- (void)dealloc;
{
    [data release];
    [arches release];

    [super dealloc];
}

- (void)_processFatArchesWithPointer:(const void *)ptr swapBytes:(BOOL)shouldSwapBytes;
{
    unsigned int count, index;

    count = [self fatCount];
    for (index = 0; index < count; index++) {
        CDFatArch *fatArch;

        fatArch = [[CDFatArch alloc] initWithPointer:ptr swapBytes:shouldSwapBytes];
        [arches addObject:fatArch];
        [fatArch release];
        ptr += sizeof(struct fat_arch);
    }
}

- (unsigned int)fatCount;
{
    return header.nfat_arch;
}

- (CDFatArch *)fatArchWithName:(NSString *)archName;
{
    if (archName == nil) {
        CDFatArch *fatArch;

        fatArch = [self localArchitecture];
        if (fatArch == nil && [arches count] > 0)
            fatArch = [arches objectAtIndex:0];

        return fatArch;
    }

    return [self _fatArchWithName:archName];
}

- (CDFatArch *)_fatArchWithName:(NSString *)archName;
{
    unsigned int count, index;

    count = [arches count];
    for (index = 0; index < count; index++) {
        CDFatArch *fatArch;

        fatArch = [arches objectAtIndex:index];
        if ([[fatArch archName] isEqual:archName])
            return fatArch;
    }

    return nil;
}

- (CDFatArch *)localArchitecture;
{
    const NXArchInfo *archInfo;

    archInfo = NXGetLocalArchInfo();
    if (archInfo == NULL) {
        NSLog(@"Couldn't get local architecture");
        return nil;
    }

    //NSLog(@"Local arch: %d, %s (%s)", archInfo->cputype, archInfo->description, archInfo->name);

    // TODO (2007-11-04): Hmm.  Search first for exact match, then fall back to main cputype.
    return [self _fatArchWithName:CDNameForCPUType(archInfo->cputype, archInfo->cpusubtype)];
}

- (NSString *)description;
{
    return [NSString stringWithFormat:@"[%p] CDFatFile with %u arches", self, [self fatCount]];
#if 0
    return [NSString stringWithFormat:@"magic: 0x%08x, cputype: %d, cpusubtype: %d, filetype: %d, ncmds: %d, sizeofcmds: %d, flags: 0x%x",
                     header.magic, header.cputype, header.cpusubtype, header.filetype, header.ncmds, header.sizeofcmds, header.flags];
#endif
}

- (NSArray *)archNames;
{
    NSMutableArray *archNames;
    unsigned int count, index;

    archNames = [NSMutableArray array];
    count = [arches count];
    for (index = 0; index < count; index++)
        [archNames addObject:[[arches objectAtIndex:index] archName]];

    return archNames;
}

@end
