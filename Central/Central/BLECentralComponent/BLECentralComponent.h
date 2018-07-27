//
//  BLECentralComponent.h
//  BLEDemo
//
//  Created by Phineas.Huang on 08/03/2018.
//  Copyright © 2018 Phineas. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BLECentralComponent;
@protocol BLECentralComponentDelegate<NSObject>

- (void)BLECentralComponentConnectDevice:(BLECentralComponent *)component;
- (void)BLECentralComponentConnectDisconnectDevice:(BLECentralComponent *)component;
- (void)BLECentralComponentReceiveMessage:(BLECentralComponent *)component message:(NSString *)message;
- (void)BLECentralComponentDebug:(BLECentralComponent *)component context:(NSString *)context;

@end

@interface BLECentralComponent : NSObject

@property (weak, nonatomic) id<BLECentralComponentDelegate> delegate;
- (void)sendMessage:(NSString *)context;

@end
