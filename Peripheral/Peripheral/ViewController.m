//
//  ViewController.m
//  Peripheral
//
//  Created by Phineas.Huang on 2018/7/27.
//  Copyright © 2018 Phineas. All rights reserved.
//

#import "ViewController.h"
#import "BLEPeripheralComponent.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UILabel *text;
@property (weak, nonatomic) IBOutlet UIButton *btnSendMessage;
@property (weak, nonatomic) IBOutlet UITextField *textFiled;

@property (strong, nonatomic) BLEPeripheralComponent *peripheral;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.peripheral = [BLEPeripheralComponent new];
    self.peripheral.delegate = self;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)actionSendMessage:(id)sender {
    NSString *message = [[self.textFiled text] isEqualToString:@""] ? @"Hello World!!" : [self.textFiled text];
    if (self.peripheral) {
        [self.peripheral sendMessage:message];
    }
}

- (void)BLEPeripheralComponentDebug:(BLEPeripheralComponent *)component context:(NSString *)context {
    self.text.text = [NSString stringWithFormat:@"%@\n%@", context, self.text.text];
}


@end
