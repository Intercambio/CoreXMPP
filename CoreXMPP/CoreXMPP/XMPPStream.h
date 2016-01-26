//
//  XMPPStream.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 04.11.15.
//  Copyright © 2015 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PureXML/PureXML.h>

typedef NS_ENUM(NSUInteger, XMPPStreamState) {
    XMPPStreamStateClosed = 0,
    XMPPStreamStateDiscovering,
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

#pragma mark Properties
@property (nonatomic, readonly) NSString *hostname;
@property (nonatomic, readonly) NSDictionary *options;

#pragma mark Queue

// The methods (and properties) of the stream must be called on the queue. If not, the stream can end up in an unexpected state.
// The delegate will be called on this queue.
// If the queue is not set, the main queue will be used.
// Setting the queue after opening the stream results into undefined behavior.
@property (nonatomic, strong) dispatch_queue_t queue;

#pragma mark Delegate
@property (nonatomic, weak) id<XMPPStreamDelegate> delegate;

#pragma mark State
@property (nonatomic, readonly) XMPPStreamState state;

#pragma mark Managing Stream
- (void)open;
- (void)reopen;
- (void)close;
- (void)suspend;

#pragma mark Sending Element
- (void)sendElement:(PXElement *)element;

@end
