//
//  MudCameraViewController.h
//  MudmenCamera
//
//  Created by TimTiger on 14-8-6.
//  Copyright (c) 2014年 Mudmen. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MudCameraPreviewLayer;
@protocol MudCameraViewControllerDelegate;
@interface MudCameraViewController : UIViewController

@property (nonatomic,assign) id <MudCameraViewControllerDelegate> delegate;

@property (weak, nonatomic) IBOutlet MudCameraPreviewLayer *cameraPreviewLayer;
@property (weak, nonatomic) IBOutlet UIButton *captureButton;
@property (weak, nonatomic) IBOutlet UIButton *comfirmButton;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;
@property (weak, nonatomic) IBOutlet UIView *topPanelView;
@property (weak, nonatomic) IBOutlet UIButton *flashButton;
@property (weak, nonatomic) IBOutlet UIButton *switchCameraButton;
@property (weak, nonatomic) IBOutlet UIImageView *previewImageView;

//@property (weak, nonatomic) IBOutlet UIImageView *imagePreview;

- (IBAction)cancelAction:(id)sender;
- (IBAction)flashAction:(id)sender;
- (IBAction)cameraChangeAction:(id)sender;
- (IBAction)comfirmAction:(id)sender;
- (IBAction)captureAction:(id)sender;

@end

@protocol MudCameraViewControllerDelegate <NSObject>

- (void)mudCameraController:(MudCameraViewController *)picker didFinishPickingMediaWithImage:(UIImage *)image;
- (void)mudCameraControllerDidCancel:(MudCameraViewController *)picker;

@end