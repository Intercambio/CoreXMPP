//
//  XMPPDocumentHandler.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 25.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PXDocument;

NS_SWIFT_NAME(DocumentHandler)
@protocol XMPPDocumentHandler <NSObject>
- (void)handleDocument:(nonnull PXDocument *)document completion:(nullable void (^)(NSError *_Nullable error))completion;
- (void)processPendingDocuments:(nullable void (^)(NSError *_Nullable error))completion;
@end
