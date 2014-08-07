//
//  ViewController.m
//  MudmenCamera
//
//  Created by TimTiger on 14-8-6.
//  Copyright (c) 2014年 Mudmen. All rights reserved.
//

#import "ViewController.h"
#import "MudCameraViewController.h"

@interface ViewController () <MudCameraViewControllerDelegate>

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)cameraAction:(id)sender {
    
    UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"MudCamera" bundle:nil];
    MudCameraViewController *cameraVC = [storyBoard instantiateViewControllerWithIdentifier:@"MudCameraViewController"];
    cameraVC.delegate = self;
    [self presentViewController:cameraVC animated:YES completion:^{
        
    }];
}

#pragma mark - Delegate

- (void)mudCameraController:(MudCameraViewController *)picker didFinishPickingMediaWithImage:(UIImage *)image {
    [self.testButton setBackgroundImage:image forState:UIControlStateNormal];
}

- (void)mudCameraControllerDidCancel:(MudCameraViewController *)picker {
    
}

@end
