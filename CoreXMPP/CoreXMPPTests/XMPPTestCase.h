//
//  XMPPTestCase.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 18.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <XCTest/XCTest.h>

#define HC_SHORTHAND
#import <OCHamcrest/OCHamcrest.h>

#define MOCKITO_SHORTHAND
#import <OCMockito/OCMockito.h>

#import <OHHTTPStubs/OHHTTPStubs.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

#import <CoreXMPP/CoreXMPP.h>

#import "XMPPModuleStub.h"
#import "XMPPConnectionStub.h"
#import "XMPPStreamStub.h"
#import "XMPPStreamFeatureStub.h"

@interface XMPPTestCase : XCTestCase
@property (nonatomic, strong) NSString *keyChainServiceName;
@end
