//
//  XMPPStream.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 04.11.15.
//  Copyright © 2015 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PureXML/PureXML.h>

extern NSString *const XMPPStreamErrorDomain;

typedef NS_ENUM(NSInteger, XMPPStreamErrorCode) {
    XMPPStreamErrorCodeInvalidState = 10,
    XMPPStreamErrorCodeMessageFormatError = 20,
    XMPPStreamErrorCodeParseError = 30
};

typedef NS_ENUM(NSUInteger, XMPPStreamState) {
    XMPPStreamStateClosed = 0,
    XMPPStreamStateConnecting,
    XMPPStreamStateOpening,
    XMPPStreamStateOpen,
    XMPPStreamStateClosing,
    XMPPStreamStateDisconnecting
};

@class XMPPStream;

@protocol XMPPStreamDelegate <NSObject>
@optional
- (void)stream:(XMPPStream *)stream didOpenToHost:(NSString *)hostname withStreamId:(NSString *)streamId;
- (void)stream:(XMPPStream *)stream didReceiveElement:(PXElement *)element;
- (void)stream:(XMPPStream *)stream didFailWithError:(NSError *)error;
- (void)streamDidClose:(XMPPStream *)stream;
@end

@interface XMPPStream : NSObject

#pragma mark Life-cycle
- (instancetype)initWithHostname:(NSString *)hostname
                         options:(NSDictionary *)options;

#pragma mark Delegate
@property (nonatomic, weak) id<XMPPStreamDelegate> delegate;

#pragma mark Properties
@property (nonatomic, readonly) NSString *hostname;
@property (nonatomic, readonly) NSDictionary *options;

#pragma mark State
@property (nonatomic, readonly) XMPPStreamState state;

#pragma mark Managing Stream
- (void)open;
- (void)reopen;
- (void)close;

#pragma mark Sending Element
- (void)sendElement:(PXElement *)element;

@end
