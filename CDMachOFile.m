#import "CDMachOFile.h"

#import <Foundation/Foundation.h>
#include <mach-o/loader.h>

#import "CDLoadCommand.h"
#import "CDSegmentCommand.h"

@implementation CDMachOFile

- (id)initWithFilename:(NSString *)filename;
{
    if ([super init] == nil)
        return nil;

    data = [[NSData alloc] initWithContentsOfMappedFile:filename];
    header = [data bytes];
    if (header->magic == MH_MAGIC)
        NSLog(@"MH_MAGIC");
    else {
        if (header->magic == MH_CIGAM)
            NSLog(@"MH_CIGAM");
        else
            NSLog(@"Not a Mach-O file.");

        [self release];
        return nil;
    }

    loadCommands = [[self _processLoadCommands] retain];

    return self;
}

- (void)dealloc;
{
    [loadCommands release]; // These all reference data, so release them first...  Should they just retain data themselves?
    [data release];

    [super dealloc];
}

- (NSArray *)_processLoadCommands;
{
    NSMutableArray *cmds;
    int count, index;
    const void *ptr;

    cmds = [NSMutableArray array];

    ptr = header + 1;
    count = header->ncmds;
    for (index = 0; index < count; index++) {
        CDLoadCommand *loadCommand;

        loadCommand = [CDLoadCommand loadCommandWithPointer:ptr machOFile:self];
        [cmds addObject:loadCommand];
        NSLog(@"%2d: %@", index, loadCommand);
        ptr += [loadCommand cmdsize];
    }

    return [NSArray arrayWithArray:cmds];;
}

- (NSArray *)loadCommands;
{
    return loadCommands;
}

- (unsigned long)filetype;
{
    return header->filetype;
}

- (unsigned long)flags;
{
    return header->flags;
}

- (NSString *)flagDescription;
{
    NSMutableArray *setFlags;
    unsigned long flags;

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

    return [setFlags componentsJoinedByString:@" "];
}

- (NSString *)description;
{
    return [NSString stringWithFormat:@"magic: 0x%08x, cputype: %d, cpusubtype: %d, filetype: %d, ncmds: %d, sizeofcmds: %d, flags: 0x%x",
                     header->magic, header->cputype, header->cpusubtype, header->filetype, header->ncmds, header->sizeofcmds, header->flags];
}

- (CDSegmentCommand *)segmentWithName:(NSString *)segmentName;
{
    int count, index;

    count = [loadCommands count];
    for (index = 0; index < count; index++) {
        id loadCommand;

        loadCommand = [loadCommands objectAtIndex:index];
        //NSLog(@"%2d: [loadCommand commandName]: '%@' vs. segmentName: '%@'", index, [loadCommand name], segmentName);
        if ([loadCommand isKindOfClass:[CDSegmentCommand class]] == YES && [[loadCommand name] isEqual:segmentName] == YES) {
            return loadCommand;
        }
    }

    return nil;
}

- (CDSegmentCommand *)segmentContainingAddress:(unsigned long)vmaddr;
{
    int count, index;

    count = [loadCommands count];
    for (index = 0; index < count; index++) {
        id loadCommand;

        loadCommand = [loadCommands objectAtIndex:index];
        if ([loadCommand isKindOfClass:[CDSegmentCommand class]] == YES && [loadCommand containsAddress:vmaddr] == YES) {
            return loadCommand;
        }
    }

    return nil;
}

- (void)foo;
{
    NSLog(@"busted");
}

- (const void *)pointerFromVMAddr:(unsigned long)vmaddr;
{
    CDSegmentCommand *segment;
    const void *ptr;

    segment = [self segmentContainingAddress:vmaddr];
    if (segment == NULL) {
        [self foo];
        NSLog(@"pointerFromVMAddr:, vmaddr: %p, segment: %@", vmaddr, segment);
    }
#if 0
    NSLog(@"vmaddr: %p, [data bytes]: %p, [segment fileoff]: %d, [segment segmentOffsetForVMAddr:vmaddr]: %d",
          vmaddr, [data bytes], [segment fileoff], [segment segmentOffsetForVMAddr:vmaddr]);
#endif
    ptr = [data bytes] + (vmaddr - [segment vmaddr] + [segment fileoff]);
    //ptr = [data bytes] + [segment fileoff] + [segment segmentOffsetForVMAddr:vmaddr];
    return ptr;
}

- (NSString *)stringFromVMAddr:(unsigned long)vmaddr;
{
    const void *ptr;

    ptr = [self pointerFromVMAddr:vmaddr];

    return [[[NSString alloc] initWithBytes:ptr length:strlen(ptr) encoding:NSASCIIStringEncoding] autorelease];
}

- (const void *)bytes;
{
    return [data bytes];
}

@end
