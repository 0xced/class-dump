// This file is part of APPNAME, SHORT DESCRIPTION
// Copyright (C) 2003 Steve Nygard.  All rights reserved.

#import <Foundation/NSObject.h>

@class NSMutableArray, NSMutableDictionary, NSMutableString, NSString;
@class CDMachOFile;

@interface CDObjCSegmentProcessor : NSObject
{
    CDMachOFile *machOFile;
    NSMutableArray *modules;
    NSMutableDictionary *protocolsByName;
}

- (id)initWithMachOFile:(CDMachOFile *)aMachOFile;
- (void)dealloc;

- (void)process;

- (NSString *)formattedStringByModule;
- (void)appendFormattedStringSortedByClass:(NSMutableString *)resultString;

- (NSString *)description;

@end
