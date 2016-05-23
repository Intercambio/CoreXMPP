//
//  XMPPClientFactory.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 23.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPClientFactory.h"
#import "XMPPClient.h"

@implementation XMPPClientFactory

- (XMPPClient *)createClientToHost:(NSString *)hostname
                       withOptions:(NSDictionary *)options
                            stream:(XMPPStream *)stream
{
    return [[XMPPClient alloc] initWithHostname:hostname options:options stream:stream];
}

@end
