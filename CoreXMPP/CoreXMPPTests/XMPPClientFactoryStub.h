//
//  XMPPClientFactoryStub.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 23.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CoreXMPP/CoreXMPP.h>

@interface XMPPClientFactoryStub : NSObject <XMPPClientFactory>

@property (nonatomic, strong) XMPPStream *stream;

@end
