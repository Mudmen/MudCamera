MudCamera
=========

由于iPhone4和4s上 用UIImagePickerController调照相机拍照比较耗内存
于是根据苹果文档里的例子AVCam改写了一下，相当于一个简单版的照相机。

使用
=========
将工程中的MudCamera文件夹，拷入你的工程。
然后在ViewController presentViewController就行了
<pre><code>
UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"MudCamera" bundle:nil];
    MudCameraViewController *cameraVC = [storyBoard instantiateViewControllerWithIdentifier:@"MudCameraViewController"];
    cameraVC.delegate = self;
    [self presentViewController:cameraVC animated:YES completion:^{
}];
</code></pre>


拍照获得的图像将通过MudCameraViewControllerDelegate回调返回。

Keyword
=========
AVCaptureSession, AVCaptureDeviceInput ,AVCaptureStillImageOutput。