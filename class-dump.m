//
//  This file is a part of class-dump v2, a utility for examining the
//  Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004  Steve Nygard
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
//
//  You may contact the author by:
//     e-mail:  class-dump at codethecode.com
//

#include <stdio.h>
#include <libc.h>
#include <ctype.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <regex.h>
#include <stdio.h>

#include <mach/mach.h>
#include <mach/mach_error.h>

#include <mach-o/loader.h>
#include <mach-o/fat.h>

#import "rcsid.h"
#import <Foundation/Foundation.h>
#import "NSString-Extensions.h"

#import "class-dump.h"

#if 0
#import "CDSectionInfo.h"
#import "ObjcThing.h"
#import "ObjcClass.h"
#import "ObjcCategory.h"
#import "ObjcProtocol.h"
#import "ObjcIvar.h"
#import "ObjcMethod.h"
#import "MappedFile.h"
#endif
#import "CDTypeFormatter.h"
#import "CDTypeParser.h"
#import "CDMachOFile.h"
#import "CDClassDump.h"

RCS_ID("$Header: /Volumes/Data/tmp/Tools/class-dump/Attic/class-dump.m,v 1.66 2004/02/03 02:54:38 nygard Exp $");

//----------------------------------------------------------------------

#if 0
NSString *current_filename = nil;
#endif
//======================================================================

char *file_type_names[] =
{
    "MH_<unknown>",
    "MH_OBJECT",
    "MH_EXECUTE",
    "MH_FVMLIB",
    "MH_CORE",
    "MH_PRELOAD",
    "MH_DYLIB",
    "MH_DYLINKER",
    "MH_BUNDLE",
};

char *load_command_names[] =
{
    "LC_<unknown>",
    "LC_SEGMENT",
    "LC_SYMTAB",
    "LC_SYMSEG",
    "LC_THREAD",
    "LC_UNIXTHREAD",
    "LC_LOADFVMLIB",
    "LC_IDFVMLIB",
    "LC_IDENT",
    "LC_FVMFILE",
    "LC_PREPAGE",
    "LC_DYSYMTAB",
    "LC_LOAD_DYLIB",
    "LC_ID_DYLIB",
    "LC_LOAD_DYLINKER",
    "LC_ID_DYLINKER",
    "LC_PREBOUND_DYLIB",
    "LC_ROUTINES",
    "LC_SUB_FRAMEWORK",
};

void print_header(void);

//======================================================================
#if 0
@implementation CDClassDump

- (id)initWithPath:(NSString *)aPath;
{
    if ([super init] == nil)
        return nil;

    mainPath = [aPath retain];
    mappedFiles = [[NSMutableArray alloc] init];
    mappedFilesByInstallName = [[NSMutableDictionary alloc] init];
    sections = [[NSMutableArray alloc] init];

    protocols = [[NSMutableDictionary alloc] init];

    flags.shouldMatchRegex = NO;
    flags.shouldSwapFat = NO;
    flags.shouldSwapMachO = NO;

    return self;
}

- (void)dealloc;
{
    [mainPath release];
    [mappedFiles release];
    [mappedFilesByInstallName release];
    [sections release];
    [protocols release];

    if (flags.shouldMatchRegex == YES) {
        regfree(&compiledRegex);
    }

    [super dealloc];
}

- (BOOL)setRegex:(char *)regexCString errorMessage:(NSString **)errorMessagePointer;
{
    int result;

    if (flags.shouldMatchRegex == YES) {
        regfree(&compiledRegex);
    }

    result = regcomp(&compiledRegex, regexCString, REG_EXTENDED);
    if (result != 0) {
        char regex_error_buffer[256];

        if (regerror(result, &compiledRegex, regex_error_buffer, 256) > 0) {
            if (errorMessagePointer != NULL) {
                *errorMessagePointer = [NSString stringWithCString:regex_error_buffer];
                NSLog(@"Error with regex: '%@'", *errorMessagePointer);
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

- (BOOL)regexMatchesCString:(const char *)str;
{
    int result;

    if (flags.shouldMatchRegex == NO)
        return YES;

    result = regexec(&compiledRegex, str, 0, NULL, 0);

    return (result == 0) ? YES : NO;
}

- (NSArray *)sections;
{
    return sections;
}

- (void)addSectionInfo:(CDSectionInfo *)aSectionInfo;
{
    [sections addObject:aSectionInfo];
}

//======================================================================

- (void)processDylibCommand:(void *)start ptr:(void *)ptr;
{
    struct dylib_command *dc = (struct dylib_command *)ptr;
    NSString *str;
    char *strptr;

    strptr = ptr + dc->dylib.name.offset;
    str = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:strptr length:strlen(strptr)];
    //NSLog(@"strptr: '%s', str: '%@'", strptr, str);
    [self buildUpObjectiveCSegments:str];
}

- (void)processFvmlibCommand:(void *)start ptr:(void *)ptr;
{
    struct fvmlib_command *fc = (struct fvmlib_command *)ptr;
    NSString *str;
    char *strptr;

    strptr = ptr + fc->fvmlib.name.offset;
    str = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:strptr length:strlen(strptr)];
    NSLog(@"strptr: '%s', str: '%@'", strptr, str);
    [self buildUpObjectiveCSegments:str];
}

//----------------------------------------------------------------------

- (NSArray *)handleObjectiveCMethods:(struct my_objc_methods *)methods methodType:(char)ch;
{
    struct my_objc_method *method = (struct my_objc_method *)(methods + 1);
    NSMutableArray *methodArray = [NSMutableArray array];
    ObjcMethod *objcMethod;
    int l;

    if (methods == NULL)
        return nil;

    for (l = 0; l < methods->method_count; l++)
    {
        // Sometimes the name, types, and implementation are all zero.  However, the
        // implementation may legitimately be zero (most often the first method of an object file),
        // so we check the name instead.

        if (method->name != 0)
        {
            objcMethod = [[[ObjcMethod alloc] initWithMethodName:[self nsstringAt:method->name section:CDSECT_METH_VAR_NAMES]
                                              type:[self nsstringAt:method->types section:CDSECT_METH_VAR_TYPES]
                                              address:method->imp] autorelease];
            [methodArray addObject:objcMethod];
        }
        method++;
    }

    return methodArray;
}

//======================================================================

- (void)showSingleModule:(CDSectionInfo *)moduleInfo;
{
    struct my_objc_module *m;
    int module_count;
    int l;
    NSString *tmp;
    id en, thing, key;
    NSMutableArray *classList;
    NSArray *newClasses;
    int formatFlags;

    // begin wolf
    id en2, thing2;
    NSMutableDictionary *categoryByName = [NSMutableDictionary dictionaryWithCapacity:5];
    // end wolf

    if (moduleInfo == nil)
        return;

    classList = [NSMutableArray array];
    formatFlags = [self methodFormattingFlags];

    tmp = current_filename;
    m = [moduleInfo start];
    module_count = [moduleInfo size] / sizeof(struct my_objc_module);

    {
        MappedFile *currentFile;
        NSString *installName, *filename;
        NSString *key;

        key = [moduleInfo filename];
        currentFile = [mappedFilesByInstallName objectForKey:key];
        installName = [currentFile installName];
        filename = [currentFile filename];
        if (flags.shouldGenerateHeaders == NO) {
            if (filename == nil || [installName isEqual:filename] == YES) {
                printf("\n/*\n * File: %s\n */\n\n", [installName fileSystemRepresentation]);
            } else {
                printf("\n/*\n * File: %s\n * Install name: %s\n */\n\n", [filename fileSystemRepresentation], [installName fileSystemRepresentation]);
            }
        }

        current_filename = key;
    }
    //current_filename = module_info->filename;

    for (l = 0; l < module_count; l++) {
        newClasses = [self handleObjectiveCSymtab:(struct my_objc_symtab *)[self translateAddressToPointer:m->symtab section:CDSECT_SYMBOLS]];
        [classList addObjectsFromArray:newClasses];
        m++;
    }

    //begin wolf
    if (flags.shouldGenerateHeaders == YES) {
        printf("Should generate headers...\n");
#if 1
        en = [[protocols allKeys] objectEnumerator];
        while (key = [en nextObject]) {
            int old_stdout = dup(1);

            thing = [protocols objectForKey:key];
            freopen([[NSString stringWithFormat:@"%@.h", [thing protocolName]] cString], "w", stdout);
            [thing showDefinition:formatFlags];
            fclose(stdout);
            fdopen(old_stdout, "w");
        }

        en = [classList objectEnumerator];
        while (thing = [en nextObject]) {
            if ([thing isKindOfClass:[ObjcCategory class]] ) {
                NSMutableArray *categoryArray = [categoryByName objectForKey:[thing categoryName]];

                if (categoryArray != nil) {
                    [categoryArray addObject:thing];
                } else {
                    [categoryByName setObject:[NSMutableArray arrayWithObject:thing] forKey:[thing categoryName]];
                }
            } else {
                int old_stdout = dup(1);

                freopen([[NSString stringWithFormat:@"%@.h", [thing className]] cString], "w", stdout);
                [thing showDefinition:formatFlags];
                fclose(stdout);
                fdopen(old_stdout, "w");
            }
        }

        en = [[categoryByName allKeys] objectEnumerator];
        while (key = [en nextObject]) {
            int old_stdout = dup(1);

            freopen([[NSString stringWithFormat:@"%@.h", key] cString], "w", stdout);

            print_header();
            printf("\n");
            thing = [categoryByName objectForKey:key];
            en2 = [thing objectEnumerator];
            while (thing2 = [en2 nextObject]) {
                [thing2 showDefinition:formatFlags];
            }

            fclose(stdout);
            fdopen(old_stdout, "w");
        }
#endif
        // TODO: nothing prints to stdout after this.
        printf("Testing... 1.. 2.. 3..\n");
    }
    //end wolf

    if (flags.shouldSort == YES)
        en = [[[protocols allKeys] sortedArrayUsingSelector:@selector(compare:)] objectEnumerator];
    else
        en = [[protocols allKeys] objectEnumerator];

    while (key = [en nextObject]) {
        thing = [protocols objectForKey:key];
        if (flags.shouldMatchRegex == NO || [self regexMatchesCString:[[thing sortableName] cString]] == YES)
            [thing showDefinition:formatFlags];
    }

    if (flags.shouldSort == YES && flags.shouldSortClasses == NO)
        en = [[classList sortedArrayUsingSelector:@selector(orderByName:)] objectEnumerator];
    else if (flags.shouldSortClasses == YES)
        en = [[ObjcClass sortedClasses] objectEnumerator];
    else
        en = [classList objectEnumerator];

    while (thing = [en nextObject]) {
        if (flags.shouldMatchRegex == NO || [self regexMatchesCString:[[thing sortableName] cString]] == YES) {
            [thing showDefinition:formatFlags];
        }
    }

    [protocols removeAllObjects];

    current_filename = tmp;
}

- (int)methodFormattingFlags;
{
    int formatFlags = 0;

    if (flags.shouldSort == YES)
        formatFlags |= F_SORT_METHODS;

    if (flags.shouldShowIvarOffsets == YES)
        formatFlags |= F_SHOW_IVAR_OFFSET;

    if (flags.shouldShowMethodAddresses == YES)
        formatFlags |= F_SHOW_METHOD_ADDRESS;

    if (flags.shouldGenerateHeaders == YES)
        formatFlags |= F_SHOW_IMPORT;

    return formatFlags;
}

@end
#endif
//----------------------------------------------------------------------

void print_usage(void)
{
    fprintf(stderr,
            "class-dump %s\n"
            "Usage: class-dump [options] MachO-file\n"
            "  where options are:\n"
            "        -a        show instance variable offsets\n"
            "        -A        show implementation addresses\n"
            "        -C regex  only display classes matching regular expression\n"
            "        -H        generate header files in current directory\n"
            "        -I        sort classes, categories, and protocols by inheritance (overrides -S)\n"
            "        -R        recursively expand @protocol <>\n"
            "        -r        recursively expand frameworks and fixed VM shared libraries\n"
            "        -S        sort classes, categories, protocols and methods by name\n"
            ,
            [CLASS_DUMP_VERSION UTF8String]
       );
}

//======================================================================

extern int optind;
extern char *optarg;

int main(int argc, char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    CDClassDump2 *classDump;

    int ch;
    BOOL errorFlag = NO;

    if (argc == 1) {
        print_usage();
        exit(2);
    }

    classDump = [[[CDClassDump2 alloc] init] autorelease];

    while ( (ch = getopt(argc, argv, "aAC:HIrRS")) != EOF) {
        switch (ch) {
          case 'a':
              [classDump setShouldShowIvarOffsets:YES];
              break;

          case 'A':
              [classDump setShouldShowMethodAddresses:YES];
              break;

          case 'C':
          {
              NSString *errorMessage;

              if ([classDump setRegex:optarg errorMessage:&errorMessage] == NO) {
                  NSLog(@"Error with regex: '%@'\n\n", errorMessage);
                  errorFlag = YES;
              }
              // Last one wins now.
          }
              break;

          case 'H':
              [classDump setShouldGenerateSeparateHeaders:YES];
              break;

          case 'I':
              //[classDump setShouldSortByInheritance:YES];
              break;

          case 'r':
              [classDump setShouldProcessRecursively:YES];
              break;

          case 'R':
              [classDump setShouldExpandProtocols:YES];
              break;

          case 'S':
              [classDump setShouldSortClasses:YES];
              [classDump setShouldSortMethods:YES];
              break;

          case '?':
          default:
              errorFlag = YES;
              break;
        }
    }

    if (errorFlag == YES) {
        print_usage();
        exit(2);
    }

    if (optind < argc) {
        NSString *path;

        path = [NSString stringWithFileSystemRepresentation:argv[optind]];
        NSLog(@"path: '%@'", path);

        [classDump setOutputPath:@"/tmp/cd"];
        [classDump processFilename:path];
        [classDump doSomething];

        exit(99);
#if 0
        if (regexCString != NULL) {
            if ([classDump setRegex:regexCString errorMessage:&regexErrorMessage] == NO) {
                printf("Error with regex: %s\n", [regexErrorMessage cString]);
                [classDump release];
                exit(1);
            }
        }
#endif
    }

    [pool release];

    return 0;
}
