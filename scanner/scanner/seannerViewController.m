//
//  seannerViewController.m
//  scanner
//
//  Created by hutilii on 16/1/13.
//  Copyright © 2016年 hutilii. All rights reserved.
//

#import "seannerViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface seannerViewController () <AVCaptureMetadataOutputObjectsDelegate>

/** 抽象的设备*/
@property (nonatomic, strong)AVCaptureDevice *device;
/** 连接设备的输入通道*/
@property (nonatomic, strong)AVCaptureDeviceInput *input;
@property (nonatomic, strong)AVCaptureSession *session;
/** 原始数据输出*/
@property (nonatomic, strong)AVCaptureMetadataOutput *output;
@property (weak, nonatomic) IBOutlet UIView *preView;
/** 扫描到的结果*/
@property (nonatomic, strong)NSString *resultUrl;


/**四角图片*/
@property (nonatomic, strong)UIImageView *codeBoundImageView;
@property (nonatomic, strong)UIImageView *imageView;

@property (nonatomic, strong)NSTimer *timer;
@end

@implementation seannerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //  添加二维码扫描的边框
    UIImage *image = [UIImage imageNamed:@"qrcode_border"];
    //  转换成可拉伸的图片
    image = [image resizableImageWithCapInsets:UIEdgeInsetsMake(25, 25, 26, 26)];
    UIImageView *border = [[UIImageView alloc] initWithImage:image];
    
    //  计算大小
    NSInteger borderWH = [UIScreen mainScreen].bounds.size.width - 2 * 70;
    border.frame = CGRectMake(70, 2  * 70, borderWH, borderWH);
    [self.view addSubview:border];
    self.codeBoundImageView = border;
    
    //  动画View
    UIImageView *imageV = [[UIImageView alloc] initWithFrame:border.bounds];
    [border addSubview:imageV];
    border.clipsToBounds = YES;
    [imageV setImage:[UIImage imageNamed:@"qrcode_scanline_barcode"]];
    self.imageView = imageV;
    
    //  初始化timer
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.01f target:self selector:@selector(imageChange:) userInfo:nil repeats:YES];
    
}

- (void)imageChange:(NSTimer *)timer {
    
    //  改变frame 用以产生动画
    self.imageView.frame = CGRectOffset(self.imageView.frame, 0, 1);
    if (self.imageView.frame.origin.y >= self.codeBoundImageView.frame.size.height - 10) {
        self.imageView.frame = CGRectOffset(self.codeBoundImageView.bounds, 0, -self.codeBoundImageView.frame.size.height);
    }
}

- (void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];
    //  开启二维码扫描
    [self read];  
}

- (void)viewWillDisappear:(BOOL)animated {
    
    [super viewWillDisappear:animated];
    //  停止二维码扫描
    [self stop];
}

- (void)read {
    
    //  获取设备
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    self.device = device;
    
    //  创建连接通道
    NSError *error;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (error) {
        NSLog(@"%@",error);
    }
    self.input = input;
    
    //  创建输出通道
    AVCaptureMetadataOutput *output = [[AVCaptureMetadataOutput alloc] init];
    //  设备输出的delegate
    dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
    [output setMetadataObjectsDelegate:self queue:queue];
    self.output =output;
    
    //  创建session 连接input和output 设置采集信息的处理
    self.session = [[AVCaptureSession alloc] init];
    [self.session addInput:self.input];
    [self.session addOutput:self.output];
    
    // 取出所有支持的类型
    NSMutableArray *result = [NSMutableArray arrayWithArray:self.output.availableMetadataObjectTypes];
    // 移除掉面部识别功能
    [result removeObject:AVMetadataObjectTypeFace];
    //  设置输出哪些信息，一定要在设置添加到session之后再设置
    [self.output setMetadataObjectTypes:result];
    
    //  设置预览效果
    AVCaptureVideoPreviewLayer *layer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    [layer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [layer setFrame:self.view.bounds];
    //  将layer显示出来
    [self.preView.layer addSublayer:layer];
    
    //  绘制一张中间透明，周围不透明的图片
    //  创建一张画布
    UIGraphicsBeginImageContextWithOptions(self.view.bounds.size, NO, [UIScreen mainScreen].scale);
    //  拿到画笔
    CGContextRef context = UIGraphicsGetCurrentContext();
    //  先将整个图片涂成半透明
    CGContextSetRGBFillColor(context, 0, 0, 0, 0.7f);
    CGContextAddRect(context, self.view.bounds);
    CGContextFillPath(context);
    
    //  将中间的涂成不透明
    CGContextSetRGBFillColor(context, 1, 1, 1, 1.f);
    CGContextAddRect(context, self.codeBoundImageView.frame);
    CGContextFillPath(context);
    
    //  绘制完成，生成图片
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    //  创建一个用于遮盖的mask层 mask层自身不显示，但是影响到把mask层作为属性的layer显示，mask 的没一点的透明度就会反作用到layer上
    CALayer *mask = [[CALayer alloc] init];
    mask.bounds = self.preView.bounds;
    mask.position = self.preView.center;
    mask.contents = (__bridge id)image.CGImage;
    layer.mask = mask;
    layer.masksToBounds = YES;
    //  开始运行
    [self.session startRunning];
    
}

- (void)stop {
    //  停止运行
    [self.session stopRunning];
    if (self.resultUrl) {
        //  用webView展示内容
        UIViewController *WebVC = [self.storyboard instantiateViewControllerWithIdentifier:@"WebViewController"];
        [WebVC setValue:self.resultUrl forKey:@"urlString"];
        [self.navigationController pushViewController:WebVC animated:YES];
    }
}

#pragma mark - delegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    
    id object = metadataObjects.firstObject;
    
    if ([object isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) {
        //  机器可识别的Code对象
        AVMetadataMachineReadableCodeObject *objc = (AVMetadataMachineReadableCodeObject *)object;
        
        NSLog(@"%@",objc.stringValue);
        self.resultUrl = objc.stringValue;
    }
    //  只加载一次
    if (self.navigationController.viewControllers.count == 1) {
        //  在主线程中更新UI
        [self performSelectorOnMainThread:@selector(stop) withObject:nil waitUntilDone:YES];
    }
    
}

- (IBAction)back:(UIBarButtonItem *)sender {
    
    [self dismissViewControllerAnimated:YES completion:nil];
    
}


@end
