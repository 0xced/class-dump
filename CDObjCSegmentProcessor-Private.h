//
// $Id: CDObjCSegmentProcessor-Private.h,v 1.4 2004/01/27 21:32:09 nygard Exp $
//

//  This file is part of class-dump, a utility for examining the
//  Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004  Steve Nygard

#import "CDObjCSegmentProcessor.h"

// Section: __module_info
struct cd_objc_module {
    unsigned long version;
    unsigned long size;
    unsigned long name;
    unsigned long symtab;
};

// Section: __symbols
struct cd_objc_symtab
{
    long sel_ref_cnt;
    long refs; // not used until runtime?
    short cls_def_count;
    short cat_def_count;
    //long class_pointer;
};

// Section: __class
struct cd_objc_class
{
    long isa;
    long super_class;
    long name;
    long version;
    long info;
    long instance_size;
    long ivars;
    long methods;
    long cache;
    long protocols;
};

// Section: ??
struct cd_objc_category
{
    long category_name;
    long class_name;
    long methods;
    long class_methods;
    long protocols;
};

// Section: __instance_vars
struct cd_objc_ivar_list
{
    long ivar_count;
    // Followed by ivars
};

// Section: __instance_vars
struct cd_objc_ivar
{
    long name;
    long type;
    int offset;
};

// Section: __inst_meth
struct cd_objc_method_list
{
    long _obsolete;
    long method_count;
    // Followed by methods
};

// Section: __inst_meth
struct cd_objc_method
{
    long name;
    long types;
    long imp;
};


struct cd_objc_protocol_list
{
    long next;
    long count;
    //long list;
};

struct cd_objc_protocol
{
    long isa;
    long protocol_name;
    long protocol_list;
    long instance_methods;
    long class_methods;
};

struct cd_objc_protocol_method_list
{
    long method_count;
    // Followed by methods
};

struct cd_objc_protocol_method
{
    long name;
    long types;
};

@class NSArray;
@class CDOCCategory, CDOCClass, CDOCProtocol, CDOCSymtab;

@interface CDObjCSegmentProcessor (Private)

- (void)processModules;
- (CDOCSymtab *)processSymtab:(unsigned long)symtab;
- (CDOCClass *)processClassDefinition:(unsigned long)defRef;
- (NSArray *)processProtocolList:(unsigned long)protocolListAddr;
- (CDOCProtocol *)processProtocol:(unsigned long)protocolAddr;
- (NSArray *)processProtocolMethods:(unsigned long)methodsAddr;
- (NSArray *)processMethods:(unsigned long)methodsAddr;
- (CDOCCategory *)processCategoryDefinition:(unsigned long)defRef;

- (void)processProtocolSection;
- (void)checkUnreferencedProtocols;

@end
