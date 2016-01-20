//
//  XMPPConnectionStub.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 20.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CoreXMPP/CoreXMPP.h>

@class PXElement;

@interface XMPPConnectionStub : NSObject <XMPPConnection>
- (void)onHandleStanza:(void (^)(PXElement *))callback;
@end
