//
//  XMPPDataFormOption.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 27.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPDataFormOption.h"

@implementation XMPPDataFormOption

+ (void)load
{
    [PXDocument registerElementClass:[XMPPDataFormOption class]
                    forQualifiedName:PXQN(@"jabber:x:data", @"option")];
}

#pragma marks Properties

- (NSString *)label
{
    return [self valueForAttribute:@"label"];
}

- (void)setLabel:(NSString *)label
{
    [self setValue:label forAttribute:@"label"];
}

@end
