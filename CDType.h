//
// $Id: CDType.h,v 1.11 2004/01/08 00:43:08 nygard Exp $
//

//  This file is part of class-dump, a utility for examining the
//  Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004  Steve Nygard

#import <Foundation/NSObject.h>
#import "CDStructRegistrationProtocol.h"

@class NSArray, NSString;
@class CDTypeFormatter;

@interface CDType : NSObject
{
    int type;
    CDType *subtype;
    NSString *typeName; // Class name? + bitfield size, array size
    NSArray *members;
    NSString *bitfieldSize;
    NSString *arraySize;

    NSString *variableName;
}

- (id)init;
- (id)initSimpleType:(int)aTypeCode;
- (id)initIDType:(NSString *)aName;
- (id)initNamedType:(NSString *)aName;
- (id)initStructType:(NSString *)aName members:(NSArray *)someMembers;
- (id)initUnionType:(NSString *)aName members:(NSArray *)someMembers;
- (id)initBitfieldType:(NSString *)aBitfieldSize;
- (id)initArrayType:(CDType *)aType count:(NSString *)aCount;
- (id)initPointerType:(CDType *)aType;
- (id)initModifier:(int)aModifier type:(CDType *)aType;
- (void)dealloc;

- (NSString *)variableName;
- (void)setVariableName:(NSString *)newVariableName;

- (int)type;
- (BOOL)isIDType;

- (CDType *)subtype;
- (NSString *)typeName;
- (NSArray *)members;

- (int)typeIgnoringModifiers;

- (NSString *)description;

- (NSString *)formattedString:(NSString *)previousName formatter:(CDTypeFormatter *)typeFormatter level:(int)level;
- (NSString *)formattedStringForMembersAtLevel:(int)level formatter:(CDTypeFormatter *)typeFormatter;
- (NSString *)formattedStringForSimpleType;

- (NSString *)typeString;
- (NSString *)bareTypeString;
- (NSString *)_typeStringWithVariableNames:(BOOL)shouldUseVariableNames;
- (NSString *)_typeStringForMembersWithVariableNames:(BOOL)shouldUseVariableNames;

//- (void)registerStructsWithObject:(id <CDStructRegistration>)anObject usedInMethod:(BOOL)isUsedInMethod;
- (void)registerStructsWithObject:(id <CDStructRegistration>)anObject usedInMethod:(BOOL)isUsedInMethod countReferences:(BOOL)shouldCountReferences;
- (void)registerMemberStructsWithObject:(id <CDStructRegistration>)anObject usedInMethod:(BOOL)isUsedInMethod countReferences:(BOOL)shouldCountReferences;

- (BOOL)isEqual:(CDType *)otherType;
- (BOOL)isStructureEqual:(CDType *)otherType;
- (int)namedMemberCount;

- (void)mergeWithType:(CDType *)otherType;

@end
