//
// $Id: CDMethodType.h,v 1.7 2004/01/15 03:04:52 nygard Exp $
//

//  This file is part of class-dump, a utility for examining the
//  Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004  Steve Nygard

#import <Foundation/NSObject.h>

#import "CDStructRegistrationProtocol.h"

@class NSMutableArray;
@class CDType;

@interface CDMethodType : NSObject
{
    CDType *type;
    NSString *offset;
}

- (id)initWithType:(CDType *)aType offset:(NSString *)anOffset;
- (void)dealloc;

- (CDType *)type;
- (NSString *)offset;

- (NSString *)description;

- (void)registerStructuresWithObject:(id <CDStructRegistration>)anObject phase:(int)phase;

@end
