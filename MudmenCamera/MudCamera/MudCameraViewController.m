//
//  MudCameraViewController.m
//  MudmenCamera
//
//  Created by TimTiger on 14-8-6.
//  Copyright (c) 2014年 Mudmen. All rights reserved.
//

#import "MudCameraViewController.h"
#import "MudCameraPreviewLayer.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "UIImage+Extension.h"

static void * CapturingStillImageContext = &CapturingStillImageContext;
static void * SessionRunningAndDeviceAuthorizedContext = &SessionRunningAndDeviceAuthorizedContext;

@interface MudCameraViewController ()

// Session management.
@property (nonatomic) dispatch_queue_t sessionQueue; // Communicate with the session and other session objects on this queue.
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureStillImageOutput *stillImageOutput;

// Utilities.
@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;
@property (nonatomic, getter = isDeviceAuthorized) BOOL deviceAuthorized;
@property (nonatomic, readonly, getter = isSessionRunningAndDeviceAuthorized) BOOL sessionRunningAndDeviceAuthorized;
@property (nonatomic) BOOL lockInterfaceRotation;
@property (nonatomic) id runtimeErrorHandlingObserver;

@property (nonatomic,copy) UIImage *resultImage;

@end

@implementation MudCameraViewController

- (BOOL)isSessionRunningAndDeviceAuthorized
{
	return [[self session] isRunning] && [self isDeviceAuthorized];
}

+ (NSSet *)keyPathsForValuesAffectingSessionRunningAndDeviceAuthorized
{
	return [NSSet setWithObjects:@"session.running", @"deviceAuthorized", nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        //默认不支持屏幕旋转
        self.lockInterfaceRotation = YES;
        //默认认为有权限拍照
        self.deviceAuthorized = YES;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    //创建一个拍摄会话，这个会话负责处理从设备拍照，到转化成图像的过程。
	AVCaptureSession *session = [[AVCaptureSession alloc] init];
	[self setSession:session];
	
	//创建拍摄画面的呈现视图，与会话关联
	[[self cameraPreviewLayer] setSession:session];
	
    //检查是否有拍照权限
#ifdef __IPHONE_7_0
    if (IOS7_OR_LATER)
    {
        [self checkDeviceAuthorizationStatus];
    }
#endif
    
    //创建一个GCD线程对列
	dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
	[self setSessionQueue:sessionQueue];
	
	dispatch_async(sessionQueue, ^{
		[self setBackgroundRecordingID:UIBackgroundTaskInvalid];
		
		NSError *error = nil;
        //获取要拍照的输入流，及后置摄像头 并与会话关联
		AVCaptureDevice *videoDevice = [MudCameraViewController deviceWithMediaType:AVMediaTypeVideo preferringPosition:AVCaptureDevicePositionBack];
		AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
		
		if (error)
		{
			NSLog(@"%@", error);
		}
		
		if ([session canAddInput:videoDeviceInput])
		{
			[session addInput:videoDeviceInput];
			[self setVideoDeviceInput:videoDeviceInput];
            
			dispatch_async(dispatch_get_main_queue(), ^{
				// Why are we dispatching this to the main queue?
				// Because AVCaptureVideoPreviewLayer is the backing layer for AVCamPreviewView and UIView can only be manipulated on main thread.
				// Note: As an exception to the above rule, it is not necessary to serialize video orientation changes on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.
                
				[[(AVCaptureVideoPreviewLayer *)[[self cameraPreviewLayer] layer] connection] setVideoOrientation:(AVCaptureVideoOrientation)[self interfaceOrientation]];
                [(AVCaptureVideoPreviewLayer *)[[self cameraPreviewLayer] layer] setVideoGravity:AVLayerVideoGravityResizeAspectFill];
			});
		}
        
        //闪光灯设置成自动模式
        [MudCameraViewController setFlashMode:AVCaptureFlashModeAuto forDevice:videoDevice];
		
        //创建拍摄图像的输出流，与会话关联
		AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
		if ([session canAddOutput:stillImageOutput])
		{
			[stillImageOutput setOutputSettings:@{AVVideoCodecKey : AVVideoCodecJPEG}];
			[session addOutput:stillImageOutput];
			[self setStillImageOutput:stillImageOutput];
		}
	});
}

- (void)viewWillAppear:(BOOL)animated
{
	dispatch_async([self sessionQueue], ^{
        //监听照相机使用权限的变化，做出界面调整
		[self addObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:SessionRunningAndDeviceAuthorizedContext];
        //监听到拍摄了照片的动作，执行动画
		[self addObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:CapturingStillImageContext];
        //监听到镜头位置改变，重新自动对焦
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:[[self videoDeviceInput] device]];
		
		__weak MudCameraViewController *weakSelf = self;
		[self setRuntimeErrorHandlingObserver:[[NSNotificationCenter defaultCenter] addObserverForName:AVCaptureSessionRuntimeErrorNotification object:[self session] queue:nil usingBlock:^(NSNotification *note) {
            //如果照相机工作过程出现错误，将会执行这个Block里面的代码，主要是重新运行照相机
			MudCameraViewController *strongSelf = weakSelf;
			dispatch_async([strongSelf sessionQueue], ^{
				[[strongSelf session] startRunning];
			});
		}]];
        //照相机开始运行
		[[self session] startRunning];
	});
    
    [self.comfirmButton setHidden:YES];
    self.previewImageView.frame = self.cameraPreviewLayer.frame;
}

- (void)viewWillDisappear:(BOOL)animated
{
    self.previewImageView.image = nil;
    [[self session] stopRunning];
    [[self session] removeInput:[self videoDeviceInput]];
    [[self session] removeOutput:[self stillImageOutput]];
    [[self cameraPreviewLayer] setSession:nil];
    [[self cameraPreviewLayer] removeFromSuperview];
    //停止照相机工作，移除相关的观察者，注销相关通知。
	dispatch_async([self sessionQueue], ^{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:[[self videoDeviceInput] device]];
		[[NSNotificationCenter defaultCenter] removeObserver:[self runtimeErrorHandlingObserver]];
		
		[self removeObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" context:SessionRunningAndDeviceAuthorizedContext];
		[self removeObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" context:CapturingStillImageContext];
	});
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context == CapturingStillImageContext)
	{
		BOOL isCapturingStillImage = [change[NSKeyValueChangeNewKey] boolValue];
		
		if (isCapturingStillImage)
		{
			[self runStillImageCaptureAnimation];
		}
	}
    else if (context == SessionRunningAndDeviceAuthorizedContext)
	{
		BOOL isRunning = [change[NSKeyValueChangeNewKey] boolValue];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if (isRunning)
			{
                //设备拍照获得用户允许
                
			}
			else
			{
                //用户不允许该应用使用设备拍照
                
			}
		});
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Button Action / Gesture Action

- (IBAction)cancelAction:(id)sender {
    if (self.previewImageView.image == nil) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(mudCameraControllerDidCancel:)]) {
            [self.delegate mudCameraControllerDidCancel:self];
        }
    } else {
        self.previewImageView.image = nil;
        [self setCaptured:NO];
    }
}

- (IBAction)flashAction:(id)sender {
    UIButton *flashButton = (UIButton *)sender;
    AVCaptureDevice *currentDevice = [[self videoDeviceInput] device];
    if ([currentDevice hasFlash]) {
        AVCaptureFlashMode currentFlashMode = [currentDevice flashMode];
        switch (currentFlashMode) {
            case AVCaptureFlashModeAuto:
            {
                [MudCameraViewController setFlashMode:AVCaptureFlashModeOn forDevice:currentDevice];
                [flashButton setTitle:@"打开" forState:UIControlStateNormal];
            }
                break;
            case AVCaptureFlashModeOn:
            {
                [MudCameraViewController setFlashMode:AVCaptureFlashModeOff forDevice:currentDevice];
                [flashButton setTitle:@"关闭" forState:UIControlStateNormal];
            }
                break;
            case AVCaptureFlashModeOff:
            {
                [MudCameraViewController setFlashMode:AVCaptureFlashModeAuto forDevice:currentDevice];
                [flashButton setTitle:@"自动" forState:UIControlStateNormal];
            }
                break;
            default:
                break;
        }
    }
}

- (IBAction)cameraChangeAction:(id)sender {
    
    [self.cancelButton setEnabled:NO];
    [self.captureButton setEnabled:NO];
    [self.comfirmButton setEnabled:NO];
    
    dispatch_async([self sessionQueue], ^{
		AVCaptureDevice *currentVideoDevice = [[self videoDeviceInput] device];
		AVCaptureDevicePosition preferredPosition = AVCaptureDevicePositionUnspecified;
		AVCaptureDevicePosition currentPosition = [currentVideoDevice position];
		
		switch (currentPosition)
		{
			case AVCaptureDevicePositionUnspecified:
				preferredPosition = AVCaptureDevicePositionBack;
				break;
			case AVCaptureDevicePositionBack:
				preferredPosition = AVCaptureDevicePositionFront;
				break;
			case AVCaptureDevicePositionFront:
				preferredPosition = AVCaptureDevicePositionBack;
				break;
		}
        
		AVCaptureDevice *videoDevice = [MudCameraViewController deviceWithMediaType:AVMediaTypeVideo preferringPosition:preferredPosition];
		AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
		
		[[self session] beginConfiguration];
		
		[[self session] removeInput:[self videoDeviceInput]];
		if ([[self session] canAddInput:videoDeviceInput])
		{
			[[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:currentVideoDevice];
			
			[MudCameraViewController setFlashMode:AVCaptureFlashModeAuto forDevice:videoDevice];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:videoDevice];
			
			[[self session] addInput:videoDeviceInput];
			[self setVideoDeviceInput:videoDeviceInput];
		}
		else
		{
			[[self session] addInput:[self videoDeviceInput]];
		}
		
		[[self session] commitConfiguration];
		
		dispatch_async(dispatch_get_main_queue(), ^{
            [self.cancelButton setEnabled:YES];
            [self.captureButton setEnabled:YES];
            [self.comfirmButton setEnabled:YES];
            AVCaptureDevice *currentVideoDevice = [[self videoDeviceInput] device];
            AVCaptureDevicePosition currentPosition = [currentVideoDevice position];
            if (currentPosition == AVCaptureDevicePositionBack) {
                [self.flashButton setHidden:NO];
            } else {
                [self.flashButton setHidden:YES];
            }
		});
	});

    
}

- (IBAction)comfirmAction:(id)sender {
    if (self.delegate && [self.delegate respondsToSelector:@selector(mudCameraController:didFinishPickingMediaWithImage:)]) {
        [self.delegate mudCameraController:self didFinishPickingMediaWithImage:self.resultImage];
    }
}

- (IBAction)captureAction:(id)sender {
    dispatch_async([self sessionQueue], ^{
		// Update the orientation on the still image output video connection before capturing.
		[[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:[[(AVCaptureVideoPreviewLayer *)[[self cameraPreviewLayer] layer] connection] videoOrientation]];
		
		// Capture a still image.
		[[self stillImageOutput] captureStillImageAsynchronouslyFromConnection:[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo] completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
			
			if (imageDataSampleBuffer)
			{
                NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                UIImage *image = [[UIImage alloc] initWithData:imageData];
                self.resultImage = [self resizeImage:image];
                 dispatch_async(dispatch_get_main_queue(), ^{
                    [self setCaptured:YES];
                    self.previewImageView.frame = self.cameraPreviewLayer.frame;
                     UIDeviceOrientation orientaion = [UIDevice currentDevice].orientation;
                     if (orientaion == UIDeviceOrientationLandscapeLeft || orientaion == UIDeviceOrientationLandscapeRight) {
                         CGFloat radio = self.cameraPreviewLayer.bounds.size.width/self.cameraPreviewLayer.bounds.size.height;
                         self.previewImageView.bounds = CGRectMake(0, 0,self.cameraPreviewLayer.bounds.size.width,self.cameraPreviewLayer.bounds.size.width*radio);
                         self.previewImageView.center = self.cameraPreviewLayer.center;
                     }
                    self.previewImageView.image = self.resultImage;
                    [[[ALAssetsLibrary alloc] init] writeImageToSavedPhotosAlbum:[image CGImage] orientation:(ALAssetOrientation)[image imageOrientation] completionBlock:nil];
                });
			}
		}];
	});
}

#pragma mark - Private API
- (void)runStillImageCaptureAnimation
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[[[self cameraPreviewLayer] layer] setOpacity:0.0];
		[UIView animateWithDuration:.25 animations:^{
			[[[self cameraPreviewLayer] layer] setOpacity:1.0];
		}];
	});
}

- (void)setCaptured:(BOOL)captured {
    self.captureButton.hidden = captured;
    self.switchCameraButton.hidden = captured;
    self.comfirmButton.hidden = !captured;
    self.cameraPreviewLayer.hidden = captured;
    if (captured) {
        [self.cancelButton setTitle:@"重拍" forState:UIControlStateNormal];
    } else {
        [self.cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    }
    AVCaptureDevice *currentVideoDevice = [[self videoDeviceInput] device];
    AVCaptureDevicePosition currentPosition = [currentVideoDevice position];
    if (currentPosition == AVCaptureDevicePositionBack) {
        [self.flashButton setHidden:captured];
    }
}

- (UIImage *)resizeImage:(UIImage *)image {
    
    CGRect resRect = CGRectMake(0,70, self.cameraPreviewLayer.bounds.size.width, self.cameraPreviewLayer.bounds.size.height);
    CGSize resSize = CGSizeMake([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
    UIImage *smallImage = [image resizedImageWithMaximumSize:resSize];
    CGImageRef imageRef = CGImageCreateWithImageInRect(smallImage.CGImage,resRect);
    smallImage = [UIImage imageWithCGImage:imageRef];
    UIImage *resImge = smallImage;
    UIDeviceOrientation orientaion = [UIDevice currentDevice].orientation;
    if (orientaion == UIDeviceOrientationLandscapeLeft || orientaion == UIDeviceOrientationLandscapeRight) {
        resImge = [smallImage imageRotatedByDegrees:270];
    }
    return resImge;
}

#pragma mark - AVCaptureDevice Configuration

- (void)checkDeviceAuthorizationStatus
{
	NSString *mediaType = AVMediaTypeVideo;
	
	[AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
		if (granted)
		{
			//Granted access to mediaType
			[self setDeviceAuthorized:YES];
		}
		else
		{
			//Not granted access to mediaType
			dispatch_async(dispatch_get_main_queue(), ^{
				[[[UIAlertView alloc] initWithTitle:@"提示"
											message:@"没有权限使用相机, 请到设置中设置允许使用"
										   delegate:self
								  cancelButtonTitle:@"确认"
								  otherButtonTitles:nil] show];
				[self setDeviceAuthorized:NO];
			});
		}
	}];
}

+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
	NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
	AVCaptureDevice *captureDevice = [devices firstObject];
	
	for (AVCaptureDevice *device in devices)
	{
		if ([device position] == position)
		{
			captureDevice = device;
			break;
		}
	}
	
	return captureDevice;
}

- (void)subjectAreaDidChange:(NSNotification *)notification
{
	CGPoint devicePoint = CGPointMake(.5, .5);
	[self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:NO];
}

//设置对焦模式
- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange
{
	dispatch_async([self sessionQueue], ^{
		AVCaptureDevice *device = [[self videoDeviceInput] device];
		NSError *error = nil;
		if ([device lockForConfiguration:&error])
		{
			if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:focusMode])
			{
				[device setFocusMode:focusMode];
				[device setFocusPointOfInterest:point];
			}
			if ([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:exposureMode])
			{
				[device setExposureMode:exposureMode];
				[device setExposurePointOfInterest:point];
			}
			[device setSubjectAreaChangeMonitoringEnabled:monitorSubjectAreaChange];
			[device unlockForConfiguration];
		}
		else
		{
			NSLog(@"%@", error);
		}
	});
}

//设置闪光灯
+ (void)setFlashMode:(AVCaptureFlashMode)flashMode forDevice:(AVCaptureDevice *)device
{
	if ([device hasFlash] && [device isFlashModeSupported:flashMode])
	{
		NSError *error = nil;
		if ([device lockForConfiguration:&error])
		{
			[device setFlashMode:flashMode];
			[device unlockForConfiguration];
		}
		else
		{
			NSLog(@"%@", error);
		}
	}
}


#pragma mark - Orientation Configuration

- (BOOL)prefersStatusBarHidden
{
	return YES;
}

- (BOOL)shouldAutorotate
{
	// Disable autorotation of the interface when recording is in progress.
	return ![self lockInterfaceRotation];
}

- (NSUInteger)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskAll;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[[(AVCaptureVideoPreviewLayer *)[[self cameraPreviewLayer] layer] connection] setVideoOrientation:(AVCaptureVideoOrientation)toInterfaceOrientation];
}



@end
