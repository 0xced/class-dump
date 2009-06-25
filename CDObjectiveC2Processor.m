//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 2009 Steve Nygard.  All rights reserved.

#import "CDObjectiveC2Processor.h"

#import "CDMachOFile.h"
#import "CDSection.h"
#import "CDLCSegment.h"
#import "CDDataCursor.h"
#import "CDOCClass.h"
#import "CDOCMethod.h"
#import "CDVisitor.h"
#import "CDOCIvar.h"
#import "NSArray-Extensions.h"
#import "CDLCSymbolTable.h"
#import "CDOCCategory.h"
#import "CDClassDump.h"

struct cd_objc2_class {
    uint64_t isa;
    uint64_t superclass;
    uint64_t cache;
    uint64_t vtable;
    uint64_t data; // points to class_ro_t
    uint64_t reserved1;
    uint64_t reserved2;
    uint64_t reserved3;
};

struct cd_objc2_class_ro_t {
    uint32_t flags;
    uint32_t instanceStart;
    uint32_t instanceSize;
    uint32_t reserved;
    uint64_t ivarLayout;
    uint64_t name;
    uint64_t baseMethods;
    uint64_t baseProtocols;
    uint64_t ivars;
    uint64_t weakIvarLayout;
    uint64_t baseProperties;
};

struct cd_objc2_list_header {
    uint32_t entsize;
    uint32_t count;
};

struct cd_objc2_method {
    uint64_t name;
    uint64_t types;
    uint64_t imp;
};

struct cd_objc2_ivar {
    uint64_t offset;
    uint64_t name;
    uint64_t type;
    uint32_t alignment;
    uint32_t size;
};

struct cd_objc2_iamge_info {
    uint32_t version;
    uint32_t flags;
};

@implementation CDObjectiveC2Processor

- (id)initWithMachOFile:(CDMachOFile *)aMachOFile;
{
    if ([super initWithMachOFile:aMachOFile] == nil)
        return nil;

    classes = [[NSMutableArray alloc] init];
    categories = [[NSMutableArray alloc] init];
    classesByAddress = [[NSMutableDictionary alloc] init];

    return self;
}

- (void)dealloc;
{
    [classes release];
    [categories release];
    [classesByAddress release];

    [super dealloc];
}

- (BOOL)hasObjectiveCData;
{
    return [[machOFile segmentWithName:@"__DATA"] sectionWithName:@"__objc_classlist"] != nil;
}

- (void)recursivelyVisit:(CDVisitor *)aVisitor;
{
    NSMutableArray *allClasses;

    allClasses = [[NSMutableArray alloc] init];
    [allClasses addObjectsFromArray:classes];
    [allClasses addObjectsFromArray:categories];

    [aVisitor willVisitObjectiveCProcessor:self];
    [aVisitor visitObjectiveCProcessor:self];

    NSLog(@"classDump = %p", [aVisitor classDump]);
    if ([[aVisitor classDump] shouldSortClassesByInheritance] == YES) {
        NSLog(@"sort= TOPO");
        [allClasses sortTopologically];
    } else if ([[aVisitor classDump] shouldSortClasses] == YES) {
        NSLog(@"sort= ALPHA");
        [allClasses sortUsingSelector:@selector(ascendingCompareByName:)];
    } else {
        NSLog(@"sort= none");
    }

    for (id aClassOrCategory in allClasses)
        [aClassOrCategory recursivelyVisit:aVisitor];

    [aVisitor didVisitObjectiveCProcessor:self];

    [allClasses release];
}

- (void)process;
{
    //[self loadSymbolTables];
    // Load classes first, so we can get a dictionary of classes by address
    [self loadClasses];
#if 0
    for (NSNumber *key in [[classesByAddress allKeys] sortedArrayUsingSelector:@selector(compare:)])
        NSLog(@"%016lx -> %@", [key unsignedIntegerValue], [[classesByAddress objectForKey:key] name]);
#endif
    [self loadCategories];
}

- (void)loadSymbolTables;
{
    for (CDLoadCommand *loadCommand in [machOFile loadCommands]) {
        if ([loadCommand isKindOfClass:[CDLCSymbolTable class]]) {
            [(CDLCSymbolTable *)loadCommand loadSymbols];
        }
    }
}

- (void)loadClasses;
{
    CDLCSegment *segment, *s2;
    NSUInteger dataOffset;
    NSString *str;
    CDSection *section;
    NSData *sectionData;
    CDDataCursor *cursor;

    NSLog(@" > %s", _cmd);


    //NSLog(@"machOFile: %@", machOFile);
    //NSLog(@"load commands: %@", [machOFile loadCommands]);

    segment = [machOFile segmentWithName:@"__DATA"];
    //NSLog(@"data segment offset: %lx", [segment fileoff]);
    //NSLog(@"data segment: %@", segment);
    [segment writeSectionData];

    section = [segment sectionWithName:@"__objc_classlist"];
    //NSLog(@"section: %@", section);

    sectionData = [section data];
    cursor = [[CDDataCursor alloc] initWithData:sectionData];
    while ([cursor isAtEnd] == NO) {
        uint64_t val;
        CDOCClass *aClass;

        val = [cursor readLittleInt64];
        //NSLog(@"----------------------------------------");
        //NSLog(@"val: %16lx", val);

        aClass = [self loadClassAtAddress:val];
        [classes addObject:aClass];
        [classesByAddress setObject:aClass forKey:[NSNumber numberWithUnsignedInteger:val]];
    }
    [cursor release];
#if 0
    s2 = [machOFile segmentContainingAddress:0x2cab60];
    NSLog(@"s2 contains 0x2cab60: %@", s2);

    dataOffset = [machOFile dataOffsetForAddress:0x2cab60];
    NSLog(@"dataOffset: %lx (%lu)", dataOffset, dataOffset);

    str = [machOFile stringAtAddress:0x2cac00];
    NSLog(@"str: %@", str);
#endif

    NSLog(@"<  %s", _cmd);
}

- (void)loadCategories;
{
    CDLCSegment *segment;
    CDSection *section;
    NSUInteger dataOffset;
    NSString *str;
    NSData *sectionData;
    CDDataCursor *cursor;

    segment = [machOFile segmentWithName:@"__DATA"];
    section = [segment sectionWithName:@"__objc_catlist"];
    sectionData = [section data];
    cursor = [[CDDataCursor alloc] initWithData:sectionData];
    while ([cursor isAtEnd] == NO) {
        uint64_t val;
        CDOCCategory *category;

        val = [cursor readLittleInt64];
        //NSLog(@"----------------------------------------");
        //NSLog(@"val: %16lx", val);
        //[machOFile logInfoForAddress:val];
        category = [self loadCategoryAtAddress:val];
        //NSLog(@"loaded category: %@", category);
        if (category != nil)
            [categories addObject:category];
    }
}

- (CDOCCategory *)loadCategoryAtAddress:(uint64_t)address;
{
    CDDataCursor *cursor;
    NSString *str;
    CDOCCategory *category;

    uint64_t v1, v2, v3, v4, v5, v6, v7, v8;

    if (address == 0)
        return nil;

    cursor = [[CDDataCursor alloc] initWithData:[machOFile data]];
    [cursor setByteOrder:[machOFile byteOrder]];
    [cursor setOffset:[machOFile dataOffsetForAddress:address]];
    NSParameterAssert([cursor offset] != 0);

    v1 = [cursor readInt64]; // Category name
    v2 = [cursor readInt64]; // class
    v3 = [cursor readInt64]; // method list
    v4 = [cursor readInt64]; // TODO: One of these should be class methods...
    v5 = [cursor readInt64];
    v6 = [cursor readInt64];
    v7 = [cursor readInt64];
    v8 = [cursor readInt64];
    //NSLog(@"----------------------------------------");
    //[machOFile logInfoForAddress:v1];
    //[machOFile logInfoForAddress:v2];
    //[machOFile logInfoForAddress:v3];

    category = [[[CDOCCategory alloc] init] autorelease];
    str = [machOFile stringAtAddress:v1];
    [category setName:str];
    //NSLog(@"set name to %@", str);

    if ([str isEqualToString:@"NSBasicTranslations"]) {
        NSLog(@"%016lx %016lx %016lx %016lx", v1, v2, v3, v4);
        NSLog(@"%016lx %016lx %016lx %016lx", v5, v6, v7, v8);
    }

    for (CDOCMethod *method in [self loadMethodsAtAddress:v3]) {
        [category addInstanceMethod:method];
    }

    for (CDOCMethod *method in [self loadMethodsAtAddress:v4]) {
        [category addClassMethod:method];
    }

    if (v2 == 0) {
        [category setClassName:@"__EXTERNAL_SYMBOL__"];
    } else {
        CDOCClass *aClass;

        aClass = [classesByAddress objectForKey:[NSNumber numberWithUnsignedInteger:v2]];
        [category setClassName:[aClass name]];
        //NSLog(@"set class name to %@", [aClass name]);
    }

    return category;
}

- (CDOCClass *)loadClassAtAddress:(uint64_t)address;
{
    struct cd_objc2_class objc2Class;
    struct cd_objc2_class_ro_t objc2ClassData;
    CDDataCursor *cursor;
    NSString *str;
    CDOCClass *aClass;

    if (address == 0)
        return nil;

    //NSLog(@"%s, address=%016lx", _cmd, address);

    cursor = [[CDDataCursor alloc] initWithData:[machOFile data]];
    [cursor setByteOrder:[machOFile byteOrder]];
    [cursor setOffset:[machOFile dataOffsetForAddress:address]];
    NSParameterAssert([cursor offset] != 0);

    objc2Class.isa = [cursor readInt64];
    objc2Class.superclass = [cursor readInt64];
    objc2Class.cache = [cursor readInt64];
    objc2Class.vtable = [cursor readInt64];
    objc2Class.data = [cursor readInt64];
    objc2Class.reserved1 = [cursor readInt64];
    objc2Class.reserved2 = [cursor readInt64];
    objc2Class.reserved3 = [cursor readInt64];
    //NSLog(@"%016lx %016lx %016lx %016lx", objc2Class.isa, objc2Class.superclass, objc2Class.cache, objc2Class.vtable);
    //NSLog(@"%016lx %016lx %016lx %016lx", objc2Class.data, objc2Class.reserved1, objc2Class.reserved2, objc2Class.reserved3);

    NSParameterAssert(objc2Class.data != 0);
    [cursor setOffset:[machOFile dataOffsetForAddress:objc2Class.data]];
    objc2ClassData.flags = [cursor readInt32];
    objc2ClassData.instanceStart = [cursor readInt32];
    objc2ClassData.instanceSize = [cursor readInt32];
    objc2ClassData.reserved = [cursor readInt32];

    objc2ClassData.ivarLayout = [cursor readInt64];
    objc2ClassData.name = [cursor readInt64];
    objc2ClassData.baseMethods = [cursor readInt64];
    objc2ClassData.baseProtocols = [cursor readInt64];
    objc2ClassData.ivars = [cursor readInt64];
    objc2ClassData.weakIvarLayout = [cursor readInt64];
    objc2ClassData.baseProperties = [cursor readInt64];

    //NSLog(@"%08x %08x %08x %08x", objc2ClassData.flags, objc2ClassData.instanceStart, objc2ClassData.instanceSize, objc2ClassData.reserved);

    //NSLog(@"%016lx %016lx %016lx %016lx", objc2ClassData.ivarLayout, objc2ClassData.name, objc2ClassData.baseMethods, objc2ClassData.baseProtocols);
    //NSLog(@"%016lx %016lx %016lx %016lx", objc2ClassData.ivars, objc2ClassData.weakIvarLayout, objc2ClassData.baseProperties);
    str = [machOFile stringAtAddress:objc2ClassData.name];
    //NSLog(@"name = %@", str);

    aClass = [[[CDOCClass alloc] init] autorelease];
    [aClass setName:str];

    for (CDOCMethod *method in [self loadMethodsAtAddress:objc2ClassData.baseMethods])
        [aClass addInstanceMethod:method];

    [aClass setIvars:[self loadIvarsAtAddress:objc2ClassData.ivars]];

    [cursor release];

    {
#if 0
        NSLog(@"isa: %016lx, data offset: %lu", objc2Class.isa, [machOFile dataOffsetForAddress:0x2ca960]);
        NSLog(@"***");
        [machOFile logInfoForAddress:address];
        NSLog(@"***");

        [machOFile logInfoForAddress:objc2Class.isa];
        [machOFile logInfoForAddress:objc2Class.superclass];
        [machOFile logInfoForAddress:objc2Class.cache];
        [machOFile logInfoForAddress:objc2Class.vtable];
        [machOFile logInfoForAddress:objc2Class.data];
        [machOFile logInfoForAddress:objc2Class.reserved1];
        [machOFile logInfoForAddress:objc2Class.reserved2];
        [machOFile logInfoForAddress:objc2Class.reserved3];

        [machOFile logInfoForAddress:0x2ca960];
        [machOFile logInfoForAddress:0x2ca9a0];
#endif

        if (objc2Class.superclass == 0) {
            // Not for NSCFArray (NSMutableArray), NSSimpleAttributeDictionaryEnumerator (NSEnumerator), NSSimpleAttributeDictionary (NSDictionary), etc.
            // It turns out NSMutableArray is in /System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation, so...
            // ... it's an undefined symbol, need to look it up.
            // So... need to recursively load frameworks, even if we don't dump them.
            //[aClass setSuperClassName:@"NSObject"];
            //NSLog(@"objc2Class.superclass of %@ is 0", [aClass name]);
            //NSLog(@"Address of objc2Class.superclass should be... %016lx (%u)", address + 8, address + 8);
            //NSLog(@"data offset for address (%016lx): %016lx", address, [machOFile dataOffsetForAddress:address]);
            //[machOFile logInfoForAddress:address];
            //[machOFile logInfoForAddress:address + 8];
            //[machOFile logInfoForAddress:0x11cb2];
            //[machOFile logInfoForAddress:0x11fed];
            //exit(99);
            [aClass setSuperClassName:@"__EXTERNAL_SYMBOL__"];
        } else {
            CDOCClass *sc;

            //NSLog(@"objc2Class.superclass of %@ is not 0", [aClass name]);
            //NSLog(@"Address of objc2Class.superclass should be... %016lx (%u)", address + 8, address + 8);
            //[machOFile logInfoForAddress:0x002cade8];
            //exit(99);
            //NSLog(@"superclass address: %016lx", objc2Class.superclass);
            sc = [self loadClassAtAddress:objc2Class.superclass];
            //NSLog(@"sc: %@", sc);
            //NSLog(@"sc name: %@", [sc name]);
            [aClass setSuperClassName:[sc name]];
        }

        {
            CDOCClass *metaclass;

            metaclass = [self loadMetaClassAtAddress:objc2Class.isa];
            //NSLog(@"metaclass [%016lx]: %@", objc2Class.isa, metaclass);
            //NSLog(@"metaclass name (%@) for class name (%@)", [metaclass name], [aClass name]);
            for (CDOCMethod *method in [metaclass classMethods])
                [aClass addClassMethod:method];
        }
        //exit(99);
    }

    return aClass;
}

// This just gets the name and methods.
- (CDOCClass *)loadMetaClassAtAddress:(uint64_t)address;
{
    struct cd_objc2_class objc2Class;
    struct cd_objc2_class_ro_t objc2ClassData;
    CDDataCursor *cursor;
    NSString *str;
    CDOCClass *aClass;

    if (address == 0)
        return nil;

    cursor = [[CDDataCursor alloc] initWithData:[machOFile data]];
    [cursor setByteOrder:[machOFile byteOrder]];
    [cursor setOffset:[machOFile dataOffsetForAddress:address]];
    NSParameterAssert([cursor offset] != 0);

    objc2Class.isa = [cursor readInt64];
    objc2Class.superclass = [cursor readInt64];
    objc2Class.cache = [cursor readInt64];
    objc2Class.vtable = [cursor readInt64];
    objc2Class.data = [cursor readInt64];
    objc2Class.reserved1 = [cursor readInt64];
    objc2Class.reserved2 = [cursor readInt64];
    objc2Class.reserved3 = [cursor readInt64];
    //NSLog(@"%016lx %016lx %016lx %016lx", objc2Class.isa, objc2Class.superclass, objc2Class.cache, objc2Class.vtable);
    //NSLog(@"%016lx %016lx %016lx %016lx", objc2Class.data, objc2Class.reserved1, objc2Class.reserved2, objc2Class.reserved3);

    NSParameterAssert(objc2Class.data != 0);
    [cursor setOffset:[machOFile dataOffsetForAddress:objc2Class.data]];
    objc2ClassData.flags = [cursor readInt32];
    objc2ClassData.instanceStart = [cursor readInt32];
    objc2ClassData.instanceSize = [cursor readInt32];
    objc2ClassData.reserved = [cursor readInt32];

    objc2ClassData.ivarLayout = [cursor readInt64];
    objc2ClassData.name = [cursor readInt64];
    objc2ClassData.baseMethods = [cursor readInt64];
    objc2ClassData.baseProtocols = [cursor readInt64];
    objc2ClassData.ivars = [cursor readInt64];
    objc2ClassData.weakIvarLayout = [cursor readInt64];
    objc2ClassData.baseProperties = [cursor readInt64];

    //NSLog(@"%08x %08x %08x %08x", objc2ClassData.flags, objc2ClassData.instanceStart, objc2ClassData.instanceSize, objc2ClassData.reserved);

    //NSLog(@"%016lx %016lx %016lx %016lx", objc2ClassData.ivarLayout, objc2ClassData.name, objc2ClassData.baseMethods, objc2ClassData.baseProtocols);
    //NSLog(@"%016lx %016lx %016lx %016lx", objc2ClassData.ivars, objc2ClassData.weakIvarLayout, objc2ClassData.baseProperties);
    str = [machOFile stringAtAddress:objc2ClassData.name];
    //NSLog(@"name = %@", str);

    aClass = [[[CDOCClass alloc] init] autorelease];
    [aClass setName:str];

    for (CDOCMethod *method in [self loadMethodsAtAddress:objc2ClassData.baseMethods])
        [aClass addClassMethod:method];

    NSParameterAssert(objc2ClassData.ivars == 0);
    //[aClass setIvars:[self loadIvarsAtAddress:objc2ClassData.ivars]];

    [cursor release];

    return aClass;
}

- (NSArray *)loadMethodsAtAddress:(uint64_t)address;
{
    NSMutableArray *methods;

    methods = [NSMutableArray array];

    if (address != 0) {
        CDDataCursor *cursor;
        struct cd_objc2_list_header listHeader;
        uint32_t index;

        cursor = [[CDDataCursor alloc] initWithData:[machOFile data]];
        [cursor setByteOrder:[machOFile byteOrder]];
        [cursor setOffset:[machOFile dataOffsetForAddress:address]];
        NSParameterAssert([cursor offset] != 0);
        //NSLog(@"method list data offset: %lu", [cursor offset]);

        listHeader.entsize = [cursor readInt32];
        listHeader.count = [cursor readInt32];
        NSParameterAssert(listHeader.entsize == 24);

        for (index = 0; index < listHeader.count; index++) {
            struct cd_objc2_method objc2Method;
            NSString *name, *types;
            CDOCMethod *method;

            objc2Method.name = [cursor readInt64];
            objc2Method.types = [cursor readInt64];
            objc2Method.imp = [cursor readInt64];
            name = [machOFile stringAtAddress:objc2Method.name];
            types = [machOFile stringAtAddress:objc2Method.types];

            //NSLog(@"%3u: %016lx %016lx %016lx", index, objc2Method.name, objc2Method.types, objc2Method.imp);
            //NSLog(@"name: %@", name);
            //NSLog(@"types: %@", types);

            method = [[CDOCMethod alloc] initWithName:name type:types imp:objc2Method.imp];
            [methods addObject:method];
            [method release];
        }
    }

    return [methods reversedArray];
}

- (NSArray *)loadIvarsAtAddress:(uint64_t)address;
{
    NSMutableArray *ivars;

    ivars = [NSMutableArray array];

    if (address != 0) {
        CDDataCursor *cursor;
        struct cd_objc2_list_header listHeader;
        uint32_t index;

        cursor = [[CDDataCursor alloc] initWithData:[machOFile data]];
        [cursor setByteOrder:[machOFile byteOrder]];
        [cursor setOffset:[machOFile dataOffsetForAddress:address]];
        NSParameterAssert([cursor offset] != 0);
        //NSLog(@"ivar list data offset: %lu", [cursor offset]);

        listHeader.entsize = [cursor readInt32];
        listHeader.count = [cursor readInt32];
        NSParameterAssert(listHeader.entsize == 32);

        for (index = 0; index < listHeader.count; index++) {
            struct cd_objc2_ivar objc2Ivar;
            NSString *name, *type;
            CDOCIvar *ivar;

            objc2Ivar.offset = [cursor readInt64];
            objc2Ivar.name = [cursor readInt64];
            objc2Ivar.type = [cursor readInt64];
            objc2Ivar.alignment = [cursor readInt32];
            objc2Ivar.size = [cursor readInt32];

            name = [machOFile stringAtAddress:objc2Ivar.name];
            type = [machOFile stringAtAddress:objc2Ivar.type];

            //NSLog(@"%3u: %016lx %016lx %016lx", index, objc2Method.name, objc2Method.types, objc2Method.imp);
            //NSLog(@"name: %@", name);
            //NSLog(@"types: %@", types);

            ivar = [[CDOCIvar alloc] initWithName:name type:type offset:objc2Ivar.offset];
            [ivars addObject:ivar];
            [ivar release];
        }
    }

    return ivars;
}

@end
