//
//  XMPPMessageBody.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 09.08.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPMessageBody.h"

@implementation XMPPMessageBody

+ (void)load
{
    [PXDocument registerElementClass:[XMPPMessageBody class]
                    forQualifiedName:PXQN(@"jabber:client", @"body")];
}

@end
