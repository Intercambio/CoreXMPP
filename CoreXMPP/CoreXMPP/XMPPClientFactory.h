//
//  XMPPClientFactory.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 23.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@class XMPPClient;
@class XMPPStream;

@interface XMPPClientFactory : NSObject

- (XMPPClient *)createClientToHost:(NSString *)hostname
                       withOptions:(NSDictionary *)options
                            stream:(XMPPStream *)stream;

@end
