//
// $Id: CDOCProtocol.h,v 1.9 2004/01/06 01:51:54 nygard Exp $
//

//  This file is part of class-dump, a utility for exmaing the
//  Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004  Steve Nygard

#import <Foundation/NSObject.h>
#import "CDStructRegistrationProtocol.h"

@class NSArray, NSMutableArray, NSMutableSet, NSMutableString, NSString;
@class CDClassDump2;

@interface CDOCProtocol : NSObject
{
    NSString *name;
    NSMutableArray *protocols;
    NSArray *classMethods;
    NSArray *instanceMethods;

    NSMutableSet *adoptedProtocolNames;
}

- (id)init;
- (void)dealloc;

- (NSString *)name;
- (void)setName:(NSString *)newName;

- (NSArray *)protocols;
- (void)addProtocol:(CDOCProtocol *)aProtocol;
- (void)removeProtocol:(CDOCProtocol *)aProtocol;
- (void)addProtocolsFromArray:(NSArray *)newProtocols;

- (NSArray *)classMethods;
- (void)setClassMethods:(NSArray *)newClassMethods;

- (NSArray *)instanceMethods;
- (void)setInstanceMethods:(NSArray *)newInstanceMethods;

- (NSString *)description;
- (void)appendToString:(NSMutableString *)resultString classDump:(CDClassDump2 *)aClassDump;
- (void)registerStructsWithObject:(id <CDStructRegistration>)anObject;

- (NSString *)sortableName;
- (NSComparisonResult)ascendingCompareByName:(CDOCProtocol *)otherProtocol;

@end
