//
// $Id: ObjcClass.m,v 1.19 2003/12/05 06:49:42 nygard Exp $
//

//
//  This file is a part of class-dump v2, a utility for examining the
//  Objective-C segment of Mach-O files.
//  Copyright (C) 1997, 1999, 2000, 2002  Steve Nygard
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

#import "ObjcClass.h"

#import <Foundation/Foundation.h>
#include <stdio.h>
#include "datatypes.h"
#import "ObjcIvar.h"
#import "ObjcMethod.h"

extern void print_header(void);

@implementation ObjcClass

+ (NSMutableDictionary *)classDict;
{
    static NSMutableDictionary *classDict = nil;

    if (classDict == nil)
        classDict = [[NSMutableDictionary alloc] init];

    return classDict;
}

+ (NSArray *)sortedClasses;
{
    NSMutableArray *classes;
    NSMutableDictionary *classDict;
    BOOL done;

    classDict = [ObjcClass classDict];
    classes = [NSMutableArray array];

    do {
        NSEnumerator *enumerator;
        id object;

        enumerator = [classDict objectEnumerator];

        done = true;
        while (object = [enumerator nextObject]) {
            if (![classDict objectForKey:[object superClassName]]) {
                [classes addObject:object];
                [classDict removeObjectForKey:[object className]];
                done = false;
            }
        }
    } while (!done);

    return classes;
}

- (id)initWithClassName:(NSString *)aClassName superClassName:(NSString *)aSuperClassName;
{
    if ([super init] == nil)
        return nil;

    className = [aClassName retain];
    superClassName = [aSuperClassName retain];
    ivars = [[NSMutableArray alloc] init];
    classMethods = [[NSMutableArray alloc] init];
    instanceMethods = [[NSMutableArray alloc] init];
    protocolNames = [[NSMutableArray alloc] init];

    [[ObjcClass classDict] setObject:self forKey:className];

    return self;
}

- (void)dealloc;
{
    [className release];
    [superClassName release];
    [ivars release];
    [classMethods release];
    [instanceMethods release];
    [protocolNames release];

    [super dealloc];
}

- (NSString *)description;
{
    return [NSString stringWithFormat:@"@interface %@:%@ {\n%@\n}\n%@\n%@",
                     className, superClassName, ivars, classMethods, instanceMethods];
}

- (NSString *)className;
{
    return className;
}

- (NSArray *)protocolNames;
{
    return protocolNames;
}

- (NSString *)sortableName;
{
    return className;
}

- (NSString *)superClassName;
{
    return superClassName;
}

- (void)addIvars:(NSArray *)newIvars;
{
    [ivars addObjectsFromArray:newIvars];
}

- (void)addClassMethods:(NSArray *)newClassMethods;
{
    [classMethods addObjectsFromArray:newClassMethods];
}

- (void)addInstanceMethods:(NSArray *)newInstanceMethods;
{
    [instanceMethods addObjectsFromArray:newInstanceMethods];
}

- (void)addProtocolNames:(NSArray *)newProtocolNames;
{
    [protocolNames addObjectsFromArray:newProtocolNames];
}

- (void)generateImports;
{
    NSMutableSet *imports = [NSMutableSet setWithCapacity:5];
    ObjcIvar *ivar;
    NSString *import;
    NSEnumerator *enumerator;
    NSString *protocolName;

    // Add superclass import is necessary.
    if (superClassName != NULL && [superClassName hasPrefix:@"NS"] == NO)
        [imports addObject:superClassName];

    // Add protocol imports.
    enumerator = [protocolNames objectEnumerator];
    while (protocolName = [enumerator nextObject]) {
        if( [protocolName hasPrefix:@"NS"] == NO)
            [imports addObject:protocolName];
    }

    // Add ivar type imports.
    enumerator = [ivars objectEnumerator];
    while (ivar = [enumerator nextObject]) {
        NSString *type = [ivar type];

        if ([type hasPrefix:@"@\""] && [type hasPrefix:@"@\"NS"] == NO)
            [imports addObject:[type substringWithRange:NSMakeRange(2, [type length]-3)]];
        /*if( ![type hasPrefix:@"NS"]
          && ([type compare:[type lowercaseString] options:NSLiteralSearch] != NSOrderedSame)) {
          [imports addObject:type];
          }*/
    }

    // Print out the imports.
    print_header();
    printf("\n");
    enumerator = [imports objectEnumerator];
    while (import = [enumerator nextObject]) {
        printf("#import \"%s.h\"\n", [import cString]);
    }
    printf("\n");
}

- (void)showDefinition:(int)flags;
{
    NSEnumerator *enumerator;
    ObjcIvar *ivar;
    ObjcMethod *method;
    NSString *protocolName;

    if (flags & F_SHOW_IMPORT)
        [self generateImports];

    printf("@interface %s", [className cString]);
    if (superClassName != nil)
        printf(":%s", [superClassName cString]);

    if ([protocolNames count] > 0) {
        enumerator = [protocolNames objectEnumerator];
        printf(" <");
        protocolName = [enumerator nextObject];
        if (protocolName != nil) {
            printf("%s", [protocolName cString]);

            while (protocolName = [enumerator nextObject])
                printf(", %s", [protocolName cString]);
        }

        printf(">");
    }

    printf("\n{\n");

    enumerator = [ivars objectEnumerator];
    while (ivar = [enumerator nextObject]) {
        [ivar showIvarAtLevel:2];
        if (flags & F_SHOW_IVAR_OFFSET)
            printf("\t// %ld = 0x%lx", [ivar offset], [ivar offset]);

        printf("\n");
    }

    //printf("%s\n", [[ivars description] cString]);
    printf("}\n\n");

    //NSLog(@"classMethods: %@", classMethods);

    if (flags & F_SORT_METHODS)
        enumerator = [[classMethods sortedArrayUsingSelector:@selector (orderByMethodName:)] objectEnumerator];
    else
        enumerator = [classMethods reverseObjectEnumerator];

    while (method = [enumerator nextObject]) {
        [method showMethod:'+'];
        if (flags & F_SHOW_METHOD_ADDRESS)
            printf("\t// IMP=0x%08lx", [method address]);

        printf("\n");
    }

    if (flags & F_SORT_METHODS)
        enumerator = [[instanceMethods sortedArrayUsingSelector:@selector (orderByMethodName:)] objectEnumerator];
    else
        enumerator = [instanceMethods reverseObjectEnumerator];

    while (method = [enumerator nextObject]) {
        [method showMethod:'-'];
        if (flags & F_SHOW_METHOD_ADDRESS)
            printf("\t// IMP=0x%08lx", [method address]);

        printf("\n");
    }

    printf("\n@end\n\n");
}

#if 0
- (NSString *)definitionWithOptions:(int)flags;
{
    NSMutableString *result;

    NSEnumerator *enumerator;
    ObjcIvar *ivar;
    ObjcMethod *method;

    result = [NSMutableString string];
#if 0
    if (flags & F_SHOW_IMPORT)
        [self generateImports];
#endif
    [result appendFormat:@"@interface %@", className];
    if (superClassName != nil)
        [result appendFormat:@":%@", superClassName];

    if ([protocolNames count] > 0) {
        [result appendString:@" <"];
        [result appendString:[protocolNames componentsJoinedByString:@", "]];
        [result appendString:@">"];
    }

    [result appendString:@"\n{\n"];

    enumerator = [ivars objectEnumerator];
    while (ivar = [enumerator nextObject]) {
        [ivar showIvarAtLevel:2];
        if (flags & F_SHOW_IVAR_OFFSET)
            printf("\t// %ld = 0x%lx", [ivar offset], [ivar offset]);

        printf("\n");
    }

    //printf("%s\n", [[ivars description] cString]);
    printf("}\n\n");

    //NSLog(@"classMethods: %@", classMethods);

    if (flags & F_SORT_METHODS)
        enumerator = [[classMethods sortedArrayUsingSelector:@selector (orderByMethodName:)] objectEnumerator];
    else
        enumerator = [classMethods reverseObjectEnumerator];

    while (method = [enumerator nextObject]) {
        [method showMethod:'+'];
        if (flags & F_SHOW_METHOD_ADDRESS)
            printf("\t// IMP=0x%08lx", [method address]);

        printf("\n");
    }

    if (flags & F_SORT_METHODS)
        enumerator = [[instanceMethods sortedArrayUsingSelector:@selector (orderByMethodName:)] objectEnumerator];
    else
        enumerator = [instanceMethods reverseObjectEnumerator];

    while (method = [enumerator nextObject]) {
        [method showMethod:'-'];
        if (flags & F_SHOW_METHOD_ADDRESS)
            printf("\t// IMP=0x%08lx", [method address]);

        printf("\n");
    }

    printf("\n@end\n\n");
}
#endif

@end
