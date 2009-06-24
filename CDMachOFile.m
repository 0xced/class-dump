// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2009 Steve Nygard.

#import "CDMachOFile.h"

#include <mach-o/arch.h>
#include <mach-o/loader.h>
#include <mach-o/fat.h>
#include <mach-o/swap.h>

#import "CDDataCursor.h"
#import "CDLCDylib.h"
#import "CDFatFile.h"
#import "CDLoadCommand.h"
#import "CDLCSegment.h"

NSString *CDMagicNumberString(uint32_t magic)
{
    switch (magic) {
      case MH_MAGIC: return @"MH_MAGIC";
      case MH_CIGAM: return @"MH_CIGAM";
      case MH_MAGIC_64: return @"MH_MAGIC_64";
      case MH_CIGAM_64: return @"MH_CIGAM_64";
    }

    return [NSString stringWithFormat:@"0x%08x", magic];
}

static BOOL debug = NO;

@implementation CDMachOFile

- (id)initWithData:(NSData *)someData offset:(NSUInteger)anOffset;
{
    if ([super initWithData:someData offset:anOffset] == nil)
        return nil;

    byteOrder = CDByteOrderLittleEndian;
    loadCommands = [[NSMutableArray alloc] init];
    _flags.uses64BitABI = NO;

    return self;
}

- (void)_readLoadCommands:(CDDataCursor *)cursor count:(uint32_t)count;
{
    uint32_t index;

    for (index = 0; index < count; index++) {
        id loadCommand;

        loadCommand = [CDLoadCommand loadCommandWithDataCursor:cursor machOFile:self];
        if (loadCommand != nil)
            [loadCommands addObject:loadCommand];
        //NSLog(@"loadCommand: %@", loadCommand);
    }
}

- (void)dealloc;
{
    [loadCommands release]; // These all reference data, so release them first...  Should they just retain data themselves?

    [super dealloc];
}

- (CDByteOrder)byteOrder;
{
    return byteOrder;
}

- (NSString *)bestMatchForLocalArch;
{
    // Implement in subclasses
    return nil;
}

- (CDMachOFile *)machOFileWithArchName:(NSString *)name;
{
    const NXArchInfo *archInfo;

    archInfo = NXGetArchInfoFromName([name UTF8String]);
    if (archInfo == NULL)
        return nil;

    if (archInfo->cputype == [self cputype])
        return self;

    return nil;
}

- (uint32_t)magic;
{
    // Implement in subclasses.
    return 0;
}

- (cpu_type_t)cputype;
{
    // Implement in subclasses.
    return 0;
}

- (cpu_subtype_t)cpusubtype;
{
    // Implement in subclasses.
    return 0;
}

- (uint32_t)filetype;
{
    // Implement in subclasses.
    return 0;
}

- (uint32_t)flags;
{
    // Implement in subclasses.
    return 0;
}

- (NSArray *)loadCommands;
{
    return loadCommands;
}

- (NSString *)filetypeDescription;
{
    switch ([self filetype]) {
      case MH_OBJECT: return @"OBJECT";
      case MH_EXECUTE: return @"EXECUTE";
      case MH_FVMLIB: return @"FVMLIB";
      case MH_CORE: return @"CORE";
      case MH_PRELOAD: return @"PRELOAD";
      case MH_DYLIB: return @"DYLIB";
      case MH_DYLINKER: return @"DYLINKER";
      case MH_BUNDLE: return @"BUNDLE";
      case MH_DYLIB_STUB: return @"DYLIB_STUB";
      case MH_DSYM: return @"DSYM";
      default:
          break;
    }

    return nil;
}

- (NSString *)flagDescription;
{
    NSMutableArray *setFlags;
    uint32_t flags;

    setFlags = [NSMutableArray array];
    flags = [self flags];
    if (flags & MH_NOUNDEFS)
        [setFlags addObject:@"NOUNDEFS"];
    if (flags & MH_INCRLINK)
        [setFlags addObject:@"INCRLINK"];
    if (flags & MH_DYLDLINK)
        [setFlags addObject:@"DYLDLINK"];
    if (flags & MH_BINDATLOAD)
        [setFlags addObject:@"BINDATLOAD"];
    if (flags & MH_PREBOUND)
        [setFlags addObject:@"PREBOUND"];
    if (flags & MH_SPLIT_SEGS)
        [setFlags addObject:@"SPLIT_SEGS"];
    if (flags & MH_LAZY_INIT)
        [setFlags addObject:@"LAZY_INIT"];
    if (flags & MH_TWOLEVEL)
        [setFlags addObject:@"TWOLEVEL"];
    if (flags & MH_FORCE_FLAT)
        [setFlags addObject:@"FORCE_FLAT"];
    if (flags & MH_NOMULTIDEFS)
        [setFlags addObject:@"NOMULTIDEFS"];
    if (flags & MH_NOFIXPREBINDING)
        [setFlags addObject:@"NOFIXPREBINDING"];
    if (flags & MH_PREBINDABLE)
        [setFlags addObject:@"PREBINDABLE"];
    if (flags & MH_ALLMODSBOUND)
        [setFlags addObject:@"ALLMODSBOUND"];
    if (flags & MH_SUBSECTIONS_VIA_SYMBOLS)
        [setFlags addObject:@"SUBSECTIONS_VIA_SYMBOLS"];
    if (flags & MH_CANONICAL)
        [setFlags addObject:@"CANONICAL"];
    if (flags & MH_WEAK_DEFINES)
        [setFlags addObject:@"WEAK_DEFINES"];
    if (flags & MH_BINDS_TO_WEAK)
        [setFlags addObject:@"BINDS_TO_WEAK"];
    if (flags & MH_ALLOW_STACK_EXECUTION)
        [setFlags addObject:@"ALLOW_STACK_EXECUTION"];
#if 1
    // 10.5 only, but I'm still using the 10.4 sdk.
    if (flags & MH_ROOT_SAFE)
        [setFlags addObject:@"ROOT_SAFE"];
    if (flags & MH_SETUID_SAFE)
        [setFlags addObject:@"SETUID_SAFE"];
    if (flags & MH_NO_REEXPORTED_DYLIBS)
        [setFlags addObject:@"NO_REEXPORTED_DYLIBS"];
    if (flags & MH_PIE)
        [setFlags addObject:@"PIE"];
#endif

    return [setFlags componentsJoinedByString:@" "];
}

- (CDLCDylib *)dylibIdentifier;
{
    for (CDLoadCommand *loadCommand in loadCommands) {
        if ([loadCommand cmd] == LC_ID_DYLIB)
            return (CDLCDylib *)loadCommand;
    }

    return nil;
}

- (CDLCSegment *)segmentWithName:(NSString *)segmentName;
{
    for (id loadCommand in loadCommands) {
        if ([loadCommand isKindOfClass:[CDLCSegment class]] == YES && [[loadCommand name] isEqual:segmentName] == YES) {
            return loadCommand;
        }
    }

    return nil;
}

- (CDLCSegment *)segmentContainingAddress:(uint32_t)address;
{
    for (id loadCommand in loadCommands) {
        if ([loadCommand isKindOfClass:[CDLCSegment class]] == YES && [loadCommand containsAddress:address] == YES) {
            return loadCommand;
        }
    }

    return nil;
}

- (void)showWarning:(NSString *)aWarning;
{
    NSLog(@"Warning: %@", aWarning);
}

- (NSString *)stringAtAddress:(uint32_t)address;
{
    CDLCSegment *segment;

    NSUInteger anOffset;
    const void *ptr;

    if (address == 0)
        return nil;

    segment = [self segmentContainingAddress:address];
    if (segment == nil) {
        NSLog(@"Error: Cannot find offset for address 0x%08x in dataOffsetForAddress:", address);
        exit(5);
        return nil;
    }

    if ([segment isProtected]) {
        NSData *d2;
        NSUInteger d2Offset;

        d2 = [segment decryptedData];
        d2Offset = [segment segmentOffsetForAddress:address];
        if (d2Offset == 0)
            return nil;

        ptr = [d2 bytes] + d2Offset;
        return [[[NSString alloc] initWithBytes:ptr length:strlen(ptr) encoding:NSASCIIStringEncoding] autorelease];
    }

    anOffset = [self dataOffsetForAddress:address];
    if (anOffset == 0)
        return nil;

    ptr = [data bytes] + anOffset;

    return [[[NSString alloc] initWithBytes:ptr length:strlen(ptr) encoding:NSASCIIStringEncoding] autorelease];
}

- (const void *)machODataBytes;
{
    return [data bytes] + offset;
}

- (NSUInteger)dataOffsetForAddress:(uint32_t)address;
{
    return [self dataOffsetForAddress:address segmentName:nil];
}

- (NSUInteger)dataOffsetForAddress:(uint32_t)address segmentName:(NSString *)aSegmentName;
{
    CDLCSegment *segment;

    if (address == 0)
        return 0;

    segment = [self segmentContainingAddress:address];
    if (segment == nil) {
        NSLog(@"Error: Cannot find offset for address 0x%08x in dataOffsetForAddress:", address);
        exit(5);
        return 0;
    }

    if (aSegmentName != nil && [[segment name] isEqual:aSegmentName] == NO) {
        // This can happen with the symtab in a module.  In one case, the symtab is in __DATA, __bss, in the zero filled area.
        // i.e. section offset is 0.
        if (debug) NSLog(@"Note: Couldn't find address in specified segment (%08x, %@)", address, aSegmentName);
        //NSLog(@"\tsegment was: %@", segment);
        //exit(5);
        return 0;
    }

    if ([segment isProtected]) {
        NSLog(@"Error: Segment is protected.");
        exit(5);
    }

#if 0
    NSLog(@"---------->");
    NSLog(@"segment is: %@", segment);
    NSLog(@"address: 0x%08x", address);
    NSLog(@"CDFile offset:    0x%08x", offset);
    NSLog(@"file off for address: 0x%08x", [segment fileOffsetForAddress:address]);
    NSLog(@"data offset:      0x%08x", offset + [segment fileOffsetForAddress:address]);
    NSLog(@"<----------");
#endif
    return offset + [segment fileOffsetForAddress:address];
}

- (const void *)bytes;
{
    return [data bytes];
}

- (const void *)bytesAtOffset:(NSUInteger)anOffset;
{
    return [data bytes] + anOffset;
}

- (NSString *)importBaseName;
{
    if ([self filetype] == MH_DYLIB) {
        NSString *str;

        str = [filename lastPathComponent];
        if ([str hasPrefix:@"lib"] == YES)
            str = [[[str substringFromIndex:3] componentsSeparatedByString:@"."] objectAtIndex:0];

        return str;
    }

    return nil;
}

- (BOOL)hasProtectedSegments;
{
    for (CDLoadCommand *loadCommand in loadCommands) {
        if ([loadCommand isKindOfClass:[CDLCSegment class]] && [(CDLCSegment *)loadCommand isProtected])
            return YES;
    }

    return NO;
}

- (NSString *)loadCommandString:(BOOL)isVerbose;
{
    NSMutableString *resultString;
    unsigned int count, index;

    resultString = [NSMutableString string];
    count = [loadCommands count];
    for (index = 0; index < count; index++) {
        CDLoadCommand *loadCommand;

        [resultString appendFormat:@"Load command %u\n", index];
        loadCommand = [loadCommands objectAtIndex:index];
        [loadCommand appendToString:resultString verbose:isVerbose];
        [resultString appendString:@"\n"];
    }

    return resultString;
}

- (NSString *)headerString:(BOOL)isVerbose;
{
    NSMutableString *resultString;

    resultString = [NSMutableString string];
    [resultString appendString:@"Mach header\n"];
    [resultString appendString:@"      magic cputype cpusubtype   filetype ncmds sizeofcmds      flags\n"];
    // Grr, %11@ doesn't work.
    if (isVerbose)
        [resultString appendFormat:@"%11@ %7@ %10u   %8@ %5u %10u %@\n",
                      CDMagicNumberString([self magic]), [self archName], [self cpusubtype],
                      [self filetypeDescription], [loadCommands count], 0, [self flagDescription]];
    else
        [resultString appendFormat:@" 0x%08x %7u %10u   %8u %5u %10u 0x%08x\n",
                      [self magic], [self cputype], [self cpusubtype], [self filetype], [loadCommands count], 0, [self flags]];
    [resultString appendString:@"\n"];

    return resultString;
}

// Must not return nil.
- (NSString *)archName;
{
    return CDNameForCPUType([self cputype], [self cpusubtype]);
}

- (NSString *)description;
{
    return [NSString stringWithFormat:@"<%@:%p> magic: 0x%08x, cputype: %d, cpusubtype: %d, filetype: %d, ncmds: %d, sizeofcmds: %d, flags: 0x%x, uses64BitABI? %d, filename: %@, data: %p, offset: %p",
                     NSStringFromClass([self class]), self,
                     [self magic], [self cputype], [self cpusubtype], [self filetype], [loadCommands count], 0, [self flags], _flags.uses64BitABI,
                     filename, data, offset];
}

@end
