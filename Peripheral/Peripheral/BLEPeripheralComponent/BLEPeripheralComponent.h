//
//  BLEPeripheralComponent.h
//  BLEDemo
//
//  Created by Phineas.Huang on 08/03/2018.
//  Copyright © 2018 Phineas. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BLEPeripheralComponent;
@protocol BLEPeripheralComponentDelegate<NSObject>

- (void)BLEPeripheralComponentConnectDevice:(BLEPeripheralComponent *)component;
- (void)BLEPeripheralComponentDisconnectDevice:(BLEPeripheralComponent *)component;
- (void)BLEPeripheralComponentReceiveMessage:(BLEPeripheralComponent *)component message:(NSString *)message;
- (void)BLEPeripheralComponentDebug:(BLEPeripheralComponent *)component context:(NSString *)context;

@end

@interface BLEPeripheralComponent : NSObject

@property (weak, nonatomic) id<BLEPeripheralComponentDelegate> delegate;
- (void)sendMessage:(NSString *)context;

@end
