//
//  BLECentralComponent.m
//  BLEDemo
//
//  Created by Phineas.Huang on 08/03/2018.
//  Copyright © 2018 Phineas. All rights reserved.
//

#import "BLECentralComponent.h"
#import <CoreBluetooth/CoreBluetooth.h>

#define CENTRAL_IDENTIFIER_KEY @"RestoreIdentifierKey"
#define BLE_MANAGER_DISPATCH_QUEUE "com.BLECentralComponent.queue"

#define kServiceUUID @"C4FB2349-72FE-4CA2-94D6-1F3CB16331EE"
#define kCharacteristicUUID @"6A3E4B28-522D-4B3B-82A9-D5E2004534FC"

@interface BLECentralComponent()<CBCentralManagerDelegate, CBPeripheralDelegate>

@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) NSMutableArray *peripherals;
@property (strong,nonatomic) dispatch_queue_t serialQueue;

@property (strong, nonatomic) CBService *cbService;
@property (strong, nonatomic) CBCharacteristic *cbCharacteristic;

@end

@implementation BLECentralComponent

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupData];
    }
    return self;
}

- (void)setupData {
    _serialQueue = dispatch_queue_create(BLE_MANAGER_DISPATCH_QUEUE, DISPATCH_QUEUE_SERIAL);

    // http://lecason.com/2015/10/31/iOS-bluetooth-restorestate-test/
    NSDictionary *options = @{CBCentralManagerOptionRestoreIdentifierKey : CENTRAL_IDENTIFIER_KEY};
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                   queue:_serialQueue
                                                  options:options];
}

- (void)sendMessage:(NSString *)context {
    if ([self.peripherals count] < 1 || context == nil) {
        return;
    }

    NSData *xmlData = [context dataUsingEncoding:NSUTF8StringEncoding];
    CBPeripheral *peripheral = [self.peripherals firstObject];
    [peripheral writeValue:xmlData forCharacteristic:self.cbCharacteristic type:CBCharacteristicWriteWithResponse];
}

- (void)cleanup:(CBPeripheral *)cbPeripheral {
    [self.centralManager cancelPeripheralConnection:cbPeripheral];
}

#pragma mark - CBCentralManager

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state != CBCentralManagerStatePoweredOn) {
        [self writeToLog:@"Not support BLE"];
        return;
    }

    [self writeToLog:@"Turn on BLE"];
    [self scan:central];
}

- (void)scan:(CBCentralManager *)central {
    [self writeToLog:@"Scanning start"];
    CBUUID *uuid = [CBUUID UUIDWithString:kServiceUUID];
    [central scanForPeripheralsWithServices:@[uuid]
                                options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@YES}];
}

- (BOOL)isIgnorePeripheral:(NSNumber *)RSSI {
    // Received Signal Strength Indicator
    if (RSSI.integerValue > -15) {
        [self writeToLog:@"RSSI > -15. call return."];
        return YES;
    }

    if (RSSI.integerValue < -60) {
        [self writeToLog:@"RSSI < -60. call return."];
        return YES;
    }

    return NO;
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI {
    if ([self isIgnorePeripheral:RSSI]) {
        return;
    }

    [self writeToLog:@"Discover Device ..."];

    if (peripheral) {
        if (![self.peripherals containsObject:peripheral]) {
            [self writeToLog:@"Add connecting the device"];
            [self.peripherals addObject:peripheral];
        }

        [self writeToLog:@"Start connecting the device"];
        [self.centralManager connectPeripheral:peripheral options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central
  didConnectPeripheral:(CBPeripheral *)peripheral {
    [self writeToLog:@"Stop scanning"];
    [self.centralManager stopScan];

    peripheral.delegate = self;
    [self writeToLog:@"Discover service"];
    [peripheral discoverServices:@[[CBUUID UUIDWithString:kServiceUUID]]];
}

- (void)centralManager:(CBCentralManager *)central
didFailToConnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error {
    [self writeToLog:@"Connect device failed."];
    [self cleanup:peripheral];
}

- (void)centralManager:(CBCentralManager *)central
      willRestoreState:(NSDictionary<NSString *,id> *)dict {
    
}

#pragma mark - CBPeripheral

- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverServices:(NSError *)error {
    BOOL isFindResult = NO;
    if (error) {
        [self writeToLog:[NSString stringWithFormat:@"Find service failed. Error : %@", error.localizedDescription]];
        [self cleanup:peripheral];
        return;
    }
    [self writeToLog:@"Find service ..."];

    CBUUID *serviceUUID = [CBUUID UUIDWithString:kServiceUUID];
    CBUUID *characteristicUUID = [CBUUID UUIDWithString:kCharacteristicUUID];
    for (CBService *service in peripheral.services) {
        if ([service.UUID isEqual:serviceUUID]) {
            [peripheral discoverCharacteristics:@[characteristicUUID] forService:service];
            isFindResult = YES;
            break;
        }
    }

    NSString *message = isFindResult ? @"Find the service" : @"NOT find the service";
    [self writeToLog:message];
}

- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error {
    if (error) {
        NSLog(@"Find Characteristics failed. Error : %@",error.localizedDescription);
        return;
    }
    [self writeToLog:@"Find Characteristics..."];

    CBUUID *serviceUUID = [CBUUID UUIDWithString:kServiceUUID];
    CBUUID *characteristicUUID = [CBUUID UUIDWithString:kCharacteristicUUID];
    if ([service.UUID isEqual:serviceUUID]) {
        for (CBCharacteristic *characteristic in service.characteristics) {
            if ([characteristic.UUID isEqual:characteristicUUID]) {
                // debug
                self.cbService = service;
                self.cbCharacteristic = characteristic;
                
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
                
                [peripheral readValueForCharacteristic:characteristic];
                if (characteristic.value) {
                    NSString *value = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
                    [self writeToLog:[NSString stringWithFormat:@"CBCharacteristic - %@",value]];
                }
                break;
            }
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral
didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error {
    [self writeToLog:@"didUpdateNotification ..."];
    if (error) {
        [self writeToLog:[NSString stringWithFormat:@"Error changing notification state: %@", error.localizedDescription]];
    }

    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:kCharacteristicUUID]]
        && ![characteristic.UUID isEqual:[CBUUID UUIDWithString:kCharacteristicUUID]]) {
        [self writeToLog:@"Characteristic is NOT exist"];
        return;
    }

    CBUUID *characteristicUUID = [CBUUID UUIDWithString:kCharacteristicUUID];
    if ([characteristic.UUID isEqual:characteristicUUID]) {
        if (characteristic.isNotifying) {
            if (characteristic.properties == CBCharacteristicPropertyNotify) {
                [self writeToLog:@"CBCharacteristicPropertyNotify"];
                return;

            } else if (characteristic.properties == CBCharacteristicPropertyRead) {
                [peripheral readValueForCharacteristic:characteristic];
            }

        } else {
            [self cleanup:peripheral];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error {
    if (error) {
        [self writeToLog:[NSString stringWithFormat:@"UpdateValueForCharacteristic failed. Error : %@", error.localizedDescription]];
        return;
    }

    if (characteristic.value == nil) {
        [self writeToLog:@"Characteristic is nil"];
        return;
    }

    NSString *value = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    if ([_delegate respondsToSelector:@selector(BLECentralComponentReceiveMessage:message:)]) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.delegate BLECentralComponentReceiveMessage:self message:value];
        });
    }
    [self writeToLog:[NSString stringWithFormat:@"Characteristic.value - %@", value]];
}

- (void)peripheral:(CBPeripheral *)peripheral
didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error {
    [self writeToLog:[NSString stringWithFormat:@"Write : Send message"]];
}

- (void)centralManager:(CBCentralManager *)central
didDisconnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error {
    [self cleanup:peripheral];
    [self scan:central];
}

#pragma mark - Property

- (NSMutableArray *)peripherals {
    if (!_peripherals) {
        _peripherals = [NSMutableArray array];
    }
    return _peripherals;
}

#pragma mark - Debug Log

- (void)writeToLog:(NSString *)info {
    if ([_delegate respondsToSelector:@selector(BLECentralComponentDebug:context:)]) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.delegate BLECentralComponentDebug:weakSelf context:info];
        });
    }
}

@end
