//
//  BLEPeripheralComponent.m
//  BLEDemo
//
//  Created by Phineas.Huang on 08/03/2018.
//  Copyright © 2018 Phineas. All rights reserved.
//

#import "BLEPeripheralComponent.h"
#import <CoreBluetooth/CoreBluetooth.h>

#define BLE_MANAGER_DISPATCH_QUEUE "com.BLEPeripheralComponent.queue"

#define kPeripheralName @"iPhone"
#define kServiceUUID @"C4FB2349-72FE-4CA2-94D6-1F3CB16331EE"
#define kCharacteristicUUID @"6A3E4B28-522D-4B3B-82A9-D5E2004534FC"

@interface BLEPeripheralComponent()<CBPeripheralManagerDelegate>
@property (strong,nonatomic) CBPeripheralManager *peripheralManager;
@property (strong,nonatomic) dispatch_queue_t serialQueue;

@property (strong,nonatomic) NSMutableArray *centralM;
@property (strong, nonatomic) CBService *cbService;
@property (strong, nonatomic) CBCharacteristic *cbCharacteristic;

@property (strong,nonatomic) CBMutableCharacteristic *characteristicM;

@end

@implementation BLEPeripheralComponent

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupData];
    }
    return self;
}

- (void)setupData {
    _serialQueue = dispatch_queue_create(BLE_MANAGER_DISPATCH_QUEUE, DISPATCH_QUEUE_SERIAL);

    NSDictionary *options = [@{CBPeripheralManagerOptionShowPowerAlertKey:@YES} mutableCopy];
    _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:_serialQueue options:options];
}

- (void)sendMessage:(NSString *)context {
    if (self.peripheralManager == nil) {
        return;
    }

    NSData *xmlData = [context dataUsingEncoding:NSUTF8StringEncoding];
    [self sendData:xmlData];
}

- (void)sendData:(NSData *)sendMsg {
    [self sendData:sendMsg dataIndex:0];
}

- (void)sendData:(NSData *)sendMsg
       dataIndex:(NSInteger)sendMsgIndex {
    // First up, check if we're meant to be sending an EOM
    static BOOL sendingEOM = NO;
    NSString *logMessage = nil;

    const int NOTIFY_MTU = 20;
    const float SendMessageTimeInterval = 0.2f;

    if (sendingEOM) {
        [self writeToLog:@"Sent 0: sending"];
        sendingEOM = NO;
        [self writeToLog:@"Sent 1: EOM"];
        return;
    }

    // We're not sending an EOM, so we're sending data
    // Is there any left to send?

    if (sendMsgIndex >= sendMsg.length) {
        logMessage = [NSString stringWithFormat:@"No data left.  Do nothing sendMsgIndex:%ld, sendMsg.length:%lu, sendMsg:%@",(long)sendMsgIndex, (unsigned long)sendMsg.length, sendMsg];
        [self writeToLog:logMessage];
        return;
    }

    BOOL didSend = YES;
    while (didSend) {
        // Make the next chunk
        // Work out how big it should be
        NSInteger amountToSend = sendMsg.length - sendMsgIndex;

        // Can't be longer than 20 bytes
        if (amountToSend > NOTIFY_MTU) {
            amountToSend = NOTIFY_MTU;
        }
        logMessage = [NSString stringWithFormat:@"Make the next chunk amountToSend:%ld",(long)amountToSend];
        [self writeToLog:logMessage];

        // Copy out the data we want
        NSData *chunk = [NSData dataWithBytes:sendMsg.bytes+sendMsgIndex length:amountToSend];

        [NSThread sleepForTimeInterval:SendMessageTimeInterval];

        if (self.characteristicM == nil) {
            [self writeToLog:@"Error - Characteristic is nil"];
            break;
        }

        didSend = [self.peripheralManager updateValue:chunk
                                    forCharacteristic:self.characteristicM
                                 onSubscribedCentrals:nil];

        if (didSend == NO) {
            logMessage = [NSString stringWithFormat:@"Sending Message failed - %ld",(long)amountToSend];
            [self writeToLog:logMessage];
            return;
        }

        NSString *stringFromData = [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding];
        logMessage = [NSString stringWithFormat:@"Sent 2: %@", stringFromData];
        [self writeToLog:logMessage];

        sendMsgIndex += amountToSend;

        if (sendMsgIndex >= sendMsg.length) {
            sendingEOM = YES;
            logMessage = [NSString stringWithFormat:@"Sent 3: EOM %uld",sendingEOM];
            [self writeToLog:logMessage];

            sendingEOM = NO;

            logMessage = [NSString stringWithFormat:@"Sent 5: EOM"];
            [self writeToLog:logMessage];
            return;
        }
    }
}

#pragma mark - Advertising method

- (void)startAdvertising {
    //    NSDictionary *dic = @{CBAdvertisementDataLocalNameKey:kPeripheralName};

    CBUUID *serviceUUID = [CBUUID UUIDWithString:kServiceUUID];
    NSDictionary *dic = @{CBAdvertisementDataServiceUUIDsKey:@[serviceUUID]};

    [self.peripheralManager startAdvertising:dic];
    [self writeToLog:@"Add service & start advertising"];
}

- (void)stopAdvertising {
    NSString *logMessage = @"BLE Stop Advertising";
    [self writeToLog:logMessage];
    [self.peripheralManager stopAdvertising];
}

#pragma mark - CBPeripheralManager method

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    if (peripheral.state != CBPeripheralManagerStatePoweredOn) {
        [self writeToLog:@"BLE error"];
        [self stopAdvertising];
        return;
    }

    [self writeToLog:@"BLE turn on"];
    [self setupService];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
           didAddService:(CBService *)service
                   error:(NSError *)error {
    if (error) {
        [self writeToLog:[NSString stringWithFormat:@"Add service failed - error : %@",error.localizedDescription]];
        return;
    }

    [self startAdvertising];
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral
                                       error:(NSError *)error {
    if (error) {
        [self writeToLog:[NSString stringWithFormat:@"Start Advertising failed - error : %@", error.localizedDescription]];
        return;
    }

    [self writeToLog:@"Start Advertising ..."];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
                  central:(CBCentral *)central
didSubscribeToCharacteristic:(CBCharacteristic *)characteristic {
    NSString *logMessage = [NSString stringWithFormat:@"Central : %@, characteristic : %@.",central.identifier.UUIDString,characteristic.UUID];
    [self writeToLog:logMessage];

    if (![self.centralM containsObject:central]) {
        [self.centralM addObject:central];
    }

    [self updateCharacteristicValue];
    [self stopAdvertising];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
                  central:(CBCentral *)central
didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic {
    [self writeToLog:[NSString stringWithFormat:@"didUnsubscribeFromCharacteristic"]];
    [self startAdvertising];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
  didReceiveWriteRequests:(NSArray <CBATTRequest *>*)requests {
    for (CBATTRequest *request in requests) {
        if (request.value) {
            NSString *value = [[NSString alloc] initWithData:request.value encoding:NSUTF8StringEncoding];

            if ([_delegate respondsToSelector:@selector(BLEPeripheralComponentReceiveMessage:message:)]) {
                __weak typeof(self) weakSelf = self;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.delegate BLEPeripheralComponentReceiveMessage:self message:value];
                });
            }

            [self writeToLog:[NSString stringWithFormat:@"CBATTRequest - Value : %@",value]];
            [peripheral respondToRequest:request withResult:CBATTErrorSuccess];

        } else {
            [self writeToLog:@"Not found Characteristic"];
        }
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
         willRestoreState:(NSDictionary *)dict {
    [self writeToLog:[NSString stringWithFormat:@"willRestoreState"]];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
    didReceiveReadRequest:(CBATTRequest *)request {
    [self writeToLog:[NSString stringWithFormat:@"didReceiveReadRequest"]];

    if ([request.characteristic.UUID.UUIDString isEqualToString:kCharacteristicUUID]) {
        [self writeToLog:@"Request character 1"];
 
        [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
    }
}

#pragma mark - CBPeripheral Delegate

- (void)peripheral:(CBPeripheral *)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
              error:(NSError *)error {
    [self writeToLog:[NSString stringWithFormat:@"didUpdateValueForCharacteristic"]];
}

- (void)peripheral:(CBPeripheral *)peripheral
didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
              error:(NSError *)error {
    [self writeToLog:[NSString stringWithFormat:@"didWriteValueForCharacteristic"]];
}

#pragma mark - Property

- (NSMutableArray *)centralM {
    if (!_centralM) {
        _centralM = [NSMutableArray array];
    }
    return _centralM;
}

#pragma mark - private method

- (void)setupService {
    // Step 1: Create CharacteristicUUID
    CBUUID *characteristicUUID = [CBUUID UUIDWithString:kCharacteristicUUID];
    CBMutableCharacteristic *characteristicM = [[CBMutableCharacteristic alloc]
                                                initWithType:characteristicUUID
                                                  properties:CBCharacteristicPropertyNotify |
                                                           CBCharacteristicPropertyRead |
                                                           CBCharacteristicPropertyWrite |
                                                           CBCharacteristicPropertyWriteWithoutResponse
                                                       value:nil
                                                  permissions:CBAttributePermissionsReadable |
                                                              CBAttributePermissionsWriteable
                                                ];
    self.characteristicM = characteristicM;

    // Step 2: Create CBMutableService
    CBUUID *serviceUUID = [CBUUID UUIDWithString:kServiceUUID];
    CBMutableService *serviceM = [[CBMutableService alloc]initWithType:serviceUUID primary:YES];
    [serviceM setCharacteristics:@[characteristicM]];

    // Step 3: Add Service to Peripheral Manager
    [self.peripheralManager addService:serviceM];
}

- (void)updateCharacteristicValue {
    NSString *valueStr = [NSString stringWithFormat:@"%@ --%@", kPeripheralName, [NSDate date]];
    NSData *value = [valueStr dataUsingEncoding:NSUTF8StringEncoding];

    [self.peripheralManager updateValue:value forCharacteristic:self.characteristicM onSubscribedCentrals:nil];
    [self writeToLog:[NSString stringWithFormat:@"updateCharacteristicValue : %@",valueStr]];
}

#pragma mark - Debug Log

- (void)writeToLog:(NSString *)info {
    if ([_delegate respondsToSelector:@selector(BLEPeripheralComponentDebug:context:)]) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.delegate BLEPeripheralComponentDebug:weakSelf context:info];
        });
    }
}

@end
