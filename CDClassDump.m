//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2007  Steve Nygard

#import "CDClassDump.h"

#import <Foundation/Foundation.h>
#import "NSArray-Extensions.h"
#import "NSString-Extensions.h"
#import "CDDylibCommand.h"
#import "CDFatArch.h"
#import "CDFatFile.h"
#import "CDMachOFile.h"
#import "CDObjCSegmentProcessor.h"
#import "CDStructureTable.h"
#import "CDSymbolReferences.h"
#import "CDType.h"
#import "CDTypeFormatter.h"
#import "CDTypeParser.h"
#import "CDVisitor.h"

@implementation CDClassDump

- (id)init;
{
    if ([super init] == nil)
        return nil;

    executablePath = nil;

    machOFiles = [[NSMutableArray alloc] init];
    machOFilesByID = [[NSMutableDictionary alloc] init];
    objCSegmentProcessors = [[NSMutableArray alloc] init];

    structureTable = [[CDStructureTable alloc] init];
    [structureTable setAnonymousBaseName:@"CDAnonymousStruct"];
    [structureTable setName:@"Structs"];

    unionTable = [[CDStructureTable alloc] init];
    [unionTable setAnonymousBaseName:@"CDAnonymousUnion"];
    [unionTable setName:@"Unions"];

    ivarTypeFormatter = [[CDTypeFormatter alloc] init];
    [ivarTypeFormatter setShouldExpand:NO];
    [ivarTypeFormatter setShouldAutoExpand:YES];
    [ivarTypeFormatter setBaseLevel:1];
    [ivarTypeFormatter setDelegate:self];

    methodTypeFormatter = [[CDTypeFormatter alloc] init];
    [methodTypeFormatter setShouldExpand:NO];
    [methodTypeFormatter setShouldAutoExpand:NO];
    [methodTypeFormatter setBaseLevel:0];
    [methodTypeFormatter setDelegate:self];

    structDeclarationTypeFormatter = [[CDTypeFormatter alloc] init];
    [structDeclarationTypeFormatter setShouldExpand:YES]; // But don't expand named struct members...
    [structDeclarationTypeFormatter setShouldAutoExpand:YES];
    [structDeclarationTypeFormatter setBaseLevel:0];
    [structDeclarationTypeFormatter setDelegate:self]; // But need to ignore some things?

    // These can be ppc, ppc7400, ppc64, i386, x86_64
    preferredArchName = nil; // Any cpu type is fine.

    flags.shouldShowHeader = YES;

    return self;
}

- (void)dealloc;
{
    [executablePath release];

    [machOFiles release];
    [machOFilesByID release];
    [objCSegmentProcessors release];

    [structureTable release];
    [unionTable release];

    [ivarTypeFormatter release];
    [methodTypeFormatter release];
    [structDeclarationTypeFormatter release];

    if (flags.shouldMatchRegex == YES)
        regfree(&compiledRegex);

    [preferredArchName release];

    [super dealloc];
}

- (NSString *)executablePath;
{
    return executablePath;
}

- (void)setExecutablePath:(NSString *)newPath;
{
    if (newPath == executablePath)
        return;

    [executablePath release];
    executablePath = [newPath retain];
}

- (BOOL)shouldProcessRecursively;
{
    return flags.shouldProcessRecursively;
}

- (void)setShouldProcessRecursively:(BOOL)newFlag;
{
    flags.shouldProcessRecursively = newFlag;
}

- (BOOL)shouldSortClasses;
{
    return flags.shouldSortClasses;
}

- (void)setShouldSortClasses:(BOOL)newFlag;
{
    flags.shouldSortClasses = newFlag;
}

- (BOOL)shouldSortClassesByInheritance;
{
    return flags.shouldSortClassesByInheritance;
}

- (void)setShouldSortClassesByInheritance:(BOOL)newFlag;
{
    flags.shouldSortClassesByInheritance = newFlag;
}

- (BOOL)shouldSortMethods;
{
    return flags.shouldSortMethods;
}

- (void)setShouldSortMethods:(BOOL)newFlag;
{
    flags.shouldSortMethods = newFlag;
}

- (BOOL)shouldShowIvarOffsets;
{
    return flags.shouldShowIvarOffsets;
}

- (void)setShouldShowIvarOffsets:(BOOL)newFlag;
{
    flags.shouldShowIvarOffsets = newFlag;
}

- (BOOL)shouldShowMethodAddresses;
{
    return flags.shouldShowMethodAddresses;
}

- (void)setShouldShowMethodAddresses:(BOOL)newFlag;
{
    flags.shouldShowMethodAddresses = newFlag;
}

- (BOOL)shouldMatchRegex;
{
    return flags.shouldMatchRegex;
}

- (void)setShouldMatchRegex:(BOOL)newFlag;
{
    if (flags.shouldMatchRegex == YES && newFlag == NO)
        regfree(&compiledRegex);

    flags.shouldMatchRegex = newFlag;
}

- (BOOL)shouldShowHeader;
{
    return flags.shouldShowHeader;
}

- (void)setShouldShowHeader:(BOOL)newFlag;
{
    flags.shouldShowHeader = newFlag;
}

- (BOOL)setRegex:(char *)regexCString errorMessage:(NSString **)errorMessagePointer;
{
    int result;

    if (flags.shouldMatchRegex == YES)
        regfree(&compiledRegex);

    result = regcomp(&compiledRegex, regexCString, REG_EXTENDED);
    if (result != 0) {
        char regex_error_buffer[256];

        if (regerror(result, &compiledRegex, regex_error_buffer, 256) > 0) {
            if (errorMessagePointer != NULL) {
                *errorMessagePointer = [NSString stringWithCString:regex_error_buffer];
            }
        } else {
            if (errorMessagePointer != NULL)
                *errorMessagePointer = nil;
        }

        return NO;
    }

    [self setShouldMatchRegex:YES];

    return YES;
}

- (BOOL)regexMatchesString:(NSString *)aString;
{
    int result;

    result = regexec(&compiledRegex, [aString UTF8String], 0, NULL, 0);
    if (result != 0) {
        if (result != REG_NOMATCH) {
            char regex_error_buffer[256];

            if (regerror(result, &compiledRegex, regex_error_buffer, 256) > 0)
                NSLog(@"Error with regex matching string, %@", [NSString stringWithCString:regex_error_buffer]);
        }

        return NO;
    }

    return YES;
}

- (NSArray *)machOFiles;
{
    return machOFiles;
}

- (NSArray *)objCSegmentProcessors;
{
    return objCSegmentProcessors;
}

- (NSString *)preferredArchName;
{
    return preferredArchName;
}

- (void)setPreferredArchName:(NSString *)newArchName;
{
    if (newArchName == preferredArchName)
        return;

    [preferredArchName release];
    preferredArchName = [newArchName retain];
}

- (BOOL)containsObjectiveCSegments;
{
    unsigned int count, index;

    count = [objCSegmentProcessors count];
    for (index = 0; index < count; index++) {
        if ([[objCSegmentProcessors objectAtIndex:index] hasModules])
            return YES;
    }

    return NO;
}

- (CDStructureTable *)structureTable;
{
    return structureTable;
}

- (CDStructureTable *)unionTable;
{
    return unionTable;
}

- (CDTypeFormatter *)ivarTypeFormatter;
{
    return ivarTypeFormatter;
}

- (CDTypeFormatter *)methodTypeFormatter;
{
    return methodTypeFormatter;
}

- (CDTypeFormatter *)structDeclarationTypeFormatter;
{
    return structDeclarationTypeFormatter;
}

+ (NSString *)executablePathForFilename:(NSString *)aFilename;
{
    NSBundle *bundle;
    NSString *path;

    // I give up, all the methods dealing with paths seem to resolve symlinks with a vengence.
    bundle = [NSBundle bundleWithPath:aFilename];
    if (bundle != nil) {
        if ([bundle executablePath] == nil)
            return nil;

        path = [[[bundle executablePath] stringByResolvingSymlinksInPath] stringByStandardizingPath];
    } else {
        path = [[aFilename stringByResolvingSymlinksInPath] stringByStandardizingPath];
    }

    return path;
}

// Return YES if successful, NO if there was an error.
- (BOOL)processFilename:(NSString *)aFilename;
{
    NSString *path;

    path = [CDClassDump executablePathForFilename:aFilename];
    if (path == nil) {
        // TODO (2007-11-02): Maybe it would be good to use NSError here.
        fprintf(stderr, "class-dump: Input file (%s) doesn't contain an executable.\n", [aFilename fileSystemRepresentation]);
        return NO;
    }

    [self setExecutablePath:[path stringByDeletingLastPathComponent]];

    return [self _processFilename:path];
}

// Return YES if successful, NO if there was an error.
- (BOOL)_processFilename:(NSString *)aFilename;
{
    NSData *data;
    CDFatFile *aFatFile;
    CDMachOFile *aMachOFile;

    data = [[NSData alloc] initWithContentsOfMappedFile:aFilename];
    {
        CDFatFile *f1;

        f1 = [[CDFatFile alloc] initWithData:data];
        NSLog(@"f1: %@", f1);
        [f1 release];
    }
    [data release];

    // TODO (2005-07-08): This isn't good enough.  You only have your
    // choice on the main file.  Link frameworks MUST be the same
    // architecture, either as a stand-alone Mach-O file or within a fat file.

    // Initial combinations:
    // 1. macho file, no cpu preference
    // 2. macho file, cpu preference same as macho file
    // 3. macho file, cpu preference different from macho file
    // 4. fat file, no cpu preference
    // 5. fat file, cpu preference contained in fat file
    // 6. fat file, cpu preference not contained in fat file
    //
    // Actions:
    // 1, 2, 4, 5: All subsequent files must be same cpu
    // 3. Print message saying that arch isn't available in this macho file
    // 6. Print message saying that arch isn't available in this fat file
    //
    // For linked frameworks/libraries, if the arch isn't available silently skip?

    aFatFile = [[CDFatFile alloc] initWithFilename:aFilename];
    if (aFatFile == nil) {
        aMachOFile = [[CDMachOFile alloc] initWithFilename:aFilename];
        if (aMachOFile == nil) {
            fprintf(stderr, "class-dump: Input file (%s) is neither a Mach-O file nor a fat archive.\n", [aFilename fileSystemRepresentation]);
            return NO;
        }

        if (preferredArchName == nil) {
            [self setPreferredArchName:[aMachOFile archName]];
        } else if ([[aMachOFile archName] isEqual:preferredArchName] == NO) {
            fprintf(stderr, "class-dump: Mach-O file (%s) does not contain required cpu type: %@.\n",
                    [aFilename fileSystemRepresentation], [preferredArchName UTF8String]);
            [aMachOFile release];
            return NO;
        }
    } else {
        CDFatArch *fatArch;

        NSLog(@"aFatFile: %@", aFatFile);

        fatArch = [aFatFile fatArchWithName:preferredArchName];
        if (fatArch == nil) {
            if (preferredArchName == nil)
                fprintf(stderr, "class-dump: Fat archive (%s) did not contain any cpu types!\n", [aFilename fileSystemRepresentation]);
            else
                fprintf(stderr, "class-dump: Fat archive (%s) does not contain required cpu type: %s.\n",
                        [aFilename fileSystemRepresentation], [preferredArchName UTF8String]);
            [aFatFile release];
            return NO;
        }

        if (preferredArchName == nil) {
            [self setPreferredArchName:[fatArch archName]];
        }

        aMachOFile = [[CDMachOFile alloc] initWithFilename:aFilename archiveOffset:[fatArch offset]];
        [aFatFile release];

        if (aMachOFile == nil)
            return NO;
    }

    [aMachOFile setDelegate:self];

    // TODO (2005-07-03): Look for the newer exception handling stuff.
    NS_DURING {
        [aMachOFile process];
    } NS_HANDLER {
        [aMachOFile release];
        return NO;
    } NS_ENDHANDLER;

    assert([aMachOFile filename] != nil);
    [machOFiles addObject:aMachOFile];
    [machOFilesByID setObject:aMachOFile forKey:[aMachOFile filename]];

    [aMachOFile release];

    return YES;
}

- (void)processObjectiveCSegments;
{
    unsigned int count, index;

    count = [machOFiles count];
    for (index = 0; index < count; index++) {
        CDMachOFile *machOFile;
        CDObjCSegmentProcessor *aProcessor;

        machOFile = [machOFiles objectAtIndex:index];

        aProcessor = [[CDObjCSegmentProcessor alloc] initWithMachOFile:machOFile];
        [aProcessor process];
        [objCSegmentProcessors addObject:aProcessor];
        [aProcessor release];
    }
}

// This visits everything segment processors, classes, categories.  It skips over modules.  Need something to visit modules so we can generate separate headers.
- (void)recursivelyVisit:(CDVisitor *)aVisitor;
{
    [aVisitor willBeginVisiting];

    if ([self containsObjectiveCSegments]) {
        int count, index;

        count = [objCSegmentProcessors count];
        for (index = 0; index < count; index++)
            [[objCSegmentProcessors objectAtIndex:index] recursivelyVisit:aVisitor];
    } else {
    }

    [aVisitor didEndVisiting];
}

- (void)registerStuff;
{
    [self registerPhase:1];
    [self registerPhase:2];
    [self generateMemberNames];
}

- (void)logInfo;
{
    [structureTable logInfo];
    [unionTable logInfo];
}

- (void)appendStructuresToString:(NSMutableString *)resultString symbolReferences:(CDSymbolReferences *)symbolReferences;
{
    [structureTable appendNamedStructuresToString:resultString classDump:self formatter:structDeclarationTypeFormatter symbolReferences:symbolReferences];
    [structureTable appendTypedefsToString:resultString classDump:self formatter:structDeclarationTypeFormatter symbolReferences:symbolReferences];

    [unionTable appendNamedStructuresToString:resultString classDump:self formatter:structDeclarationTypeFormatter symbolReferences:symbolReferences];
    [unionTable appendTypedefsToString:resultString classDump:self formatter:structDeclarationTypeFormatter symbolReferences:symbolReferences];
}

- (CDMachOFile *)machOFileWithID:(NSString *)anID;
{
    NSString *adjustedID;
    CDMachOFile *aMachOFile;
    NSString *replacementString = @"@executable_path";

    if ([anID hasPrefix:replacementString] == YES) {
        adjustedID = [executablePath stringByAppendingString:[anID substringFromIndex:[replacementString length]]];
    } else {
        adjustedID = anID;
    }

    aMachOFile = [machOFilesByID objectForKey:adjustedID];
    if (aMachOFile == nil) {
        [self _processFilename:adjustedID];
        aMachOFile = [machOFilesByID objectForKey:adjustedID];
    }

    return aMachOFile;
}

- (void)machOFile:(CDMachOFile *)aMachOFile loadDylib:(CDDylibCommand *)aDylibCommand;
{
    if ([aDylibCommand cmd] == LC_LOAD_DYLIB && [self shouldProcessRecursively] == YES)
        [self machOFileWithID:[aDylibCommand name]];
}

- (void)appendHeaderToString:(NSMutableString *)resultString;
{
    // Since this changes each version, for regression testing it'll be better to be able to not show it.
    if (flags.shouldShowHeader == NO)
        return;

    [resultString appendString:@"/*\n"];
    [resultString appendFormat:@" *     Generated by class-dump %@.\n", CLASS_DUMP_VERSION];
    [resultString appendString:@" *\n"];
    [resultString appendString:@" *     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2007 by Steve Nygard.\n"];
    [resultString appendString:@" */\n\n"];
}

- (CDType *)typeFormatter:(CDTypeFormatter *)aFormatter replacementForType:(CDType *)aType;
{
    if ([aType type] == '{')
        return [structureTable replacementForType:aType];

    if ([aType type] == '(')
        return [unionTable replacementForType:aType];

    return nil;
}

- (NSString *)typeFormatter:(CDTypeFormatter *)aFormatter typedefNameForStruct:(CDType *)structType level:(int)level;
{
    CDType *searchType;
    CDStructureTable *targetTable;

    if (level == 0 && aFormatter == structDeclarationTypeFormatter)
        return nil;

    if ([structType type] == '{') {
        targetTable = structureTable;
    } else {
        targetTable = unionTable;
    }

    // We need to catch top level replacements, not just replacements for struct members.
    searchType = [targetTable replacementForType:structType];
    if (searchType == nil)
        searchType = structType;

    return [targetTable typedefNameForStructureType:searchType];
}

- (void)registerPhase:(int)phase;
{
    NSAutoreleasePool *pool;
    int count, index;

    pool = [[NSAutoreleasePool alloc] init];

    count = [objCSegmentProcessors count];
    for (index = 0; index < count; index++) {
        [[objCSegmentProcessors objectAtIndex:index] registerStructuresWithObject:self phase:phase];
    }

    [self endPhase:phase];
    [pool release];
}

- (void)endPhase:(int)phase;
{
    if (phase == 1) {
        [structureTable finishPhase1];
        [unionTable finishPhase1];
    } else if (phase == 2) {
        [structureTable generateNamesForAnonymousStructures];
        [unionTable generateNamesForAnonymousStructures];
    }
}

- (void)phase1RegisterStructure:(CDType *)aStructure;
{
    if ([aStructure type] == '{') {
        [structureTable phase1RegisterStructure:aStructure];
    } else if ([aStructure type] == '(') {
        [unionTable phase1RegisterStructure:aStructure];
    } else {
        NSLog(@"%s, unknown structure type: %d", _cmd, [aStructure type]);
    }
}

- (BOOL)phase2RegisterStructure:(CDType *)aStructure usedInMethod:(BOOL)isUsedInMethod countReferences:(BOOL)shouldCountReferences;
{
    if ([aStructure type] == '{') {
        return [structureTable phase2RegisterStructure:aStructure withObject:self usedInMethod:isUsedInMethod countReferences:shouldCountReferences];
    } else if ([aStructure type] == '(') {
        return [unionTable phase2RegisterStructure:aStructure withObject:self usedInMethod:isUsedInMethod countReferences:shouldCountReferences];
    } else {
        NSLog(@"%s, unknown structure type: %d", _cmd, [aStructure type]);
    }

    return NO;
}

- (void)generateMemberNames;
{
    [structureTable generateMemberNames];
    [unionTable generateMemberNames];
}

- (void)showHeader;
{
    if ([machOFiles count] > 0) {
        [[[machOFiles lastObject] headerString:YES] print];
    }
}

- (void)showLoadCommands;
{
    if ([machOFiles count] > 0) {
        [[[machOFiles lastObject] loadCommandString:YES] print];
    }
}

@end
