//
// $Id: ObjcIvar.m,v 1.5 2002/12/19 06:13:19 nygard Exp $
//

//
//  This file is a part of class-dump v2, a utility for examining the
//  Objective-C segment of Mach-O files.
//  Copyright (C) 1997, 2000  Steve Nygard
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
//     e-mail:  nygard@omnigroup.com
//

#import "ObjcIvar.h"

#import <Foundation/Foundation.h>
#include "datatypes.h"

@implementation ObjcIvar

- (id)initWithName:(NSString *)ivarName type:(NSString *)ivarType offset:(long)ivarOffset;
{
    if ([super init] == nil)
        return nil;

    ivar_name = [ivarName retain];
    ivar_type = [ivarType retain];
    ivar_offset = ivarOffset;

    return self;
}

- (void)dealloc;
{
    [ivar_name release];
    [ivar_type release];
    
    [super dealloc];
}

- (NSString *)description;
{
    return [NSString stringWithFormat:@"%@/%@\t// %x", ivar_name, ivar_type, ivar_offset];
}

- (long)offset;
{
    return ivar_offset;
}

- (void)showIvarAtLevel:(int)level;
{
    format_type ([ivar_type cString], [ivar_name cString], level);
}

@end
