//
//  ViewController.m
//  Central
//
//  Created by Phineas.Huang on 2018/7/27.
//  Copyright © 2018 Phineas. All rights reserved.
//

#import "ViewController.h"
#import "BLECentralComponent.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UILabel *text;
@property (weak, nonatomic) IBOutlet UIButton *btnSendMessage;
@property (weak, nonatomic) IBOutlet UITextField *textFiled;

@property (strong, nonatomic) BLECentralComponent *central;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.central = [BLECentralComponent new];
    self.central.delegate = self;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)actionSendMessage:(id)sender {
    NSString *message = [[self.textFiled text] isEqualToString:@""] ? @"Hello World!!" : [self.textFiled text];
    if (self.central) {
        [self.central sendMessage:message];
    }
}

- (void)BLECentralComponentDebug:(BLECentralComponent *)component context:(NSString *)context {
    self.text.text = [NSString stringWithFormat:@"%@\n%@", context, self.text.text];
}


@end
