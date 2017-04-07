//
//  DJICameraViewController.m
//  FPVDemo
//
//  Created by OliverOu on 2/7/15.
//  Copyright (c) 2015 DJI. All rights reserved.
//

#import "DJICameraViewController.h"
#import <DJISDK/DJISDK.h>
#import <VideoPreviewer/VideoPreviewer.h>

#import "DemoUtility.h"
#import <AFNetworking.h>
#import <AFHTTPSessionManager.h>


#import <AWSS3/AWSS3.h>



#define WeakRef(__obj) __weak typeof(self) __obj = self
#define WeakReturn(__obj) if(__obj ==nil)return;

@interface DJICameraViewController ()<DJIVideoFeedListener, DJISDKManagerDelegate, DJIBaseProductDelegate, DJICameraDelegate, DJIFlightControllerDelegate>


@property (weak, nonatomic) IBOutlet UIView *fpvPreviewView;
@property (assign, nonatomic) BOOL isRecording;
@property (weak, nonatomic) IBOutlet UIButton *button;
@property (weak, nonatomic) IBOutlet UILabel *latAndLong;
@property (weak, nonatomic) IBOutlet UILabel *currentRecordTimeLabel;
@property(nonatomic, assign) CLLocationCoordinate2D droneLocation;
@property(nonatomic, strong) NSTimer *myTimer;
@property (nonatomic, assign) double lat;
@property (nonatomic, assign) double lon;




@end

@implementation DJICameraViewController


- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [[VideoPreviewer instance] setView:self.fpvPreviewView];
    [self registerApp];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[VideoPreviewer instance] setView:nil];
    [[DJISDKManager videoFeeder].primaryVideoFeed removeListener:self];
}

- (void)viewDidLoad {
    
    [super viewDidLoad];

    [self.currentRecordTimeLabel setHidden:YES];
   }


-(void)takeScreenShot {
    
    NSLog(@"gome");
    
    CGSize screenSize = [[UIScreen mainScreen] applicationFrame].size;
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(nil, screenSize.width, screenSize.height, 8, 4*(int)screenSize.width, colorSpaceRef, kCGImageAlphaPremultipliedLast);
    CGContextTranslateCTM(ctx, 0.0, screenSize.height);
    CGContextScaleCTM(ctx, 1.0, -1.0);
    
    [(CALayer*)self.view.layer renderInContext:ctx];
    
    CGImageRef cgImage = CGBitmapContextCreateImage(ctx);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGContextRelease(ctx);
    //old [UIImageJPEGRepresentation(image, 1.0) writeToFile:@"screen.jpg" atomically:NO];
    
    //amazon stuff-- upload and get stuff
    // Create path.
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *filePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Image.png"];
    
    // Save image.
    [UIImagePNGRepresentation(image) writeToFile:filePath atomically:YES];
    //[self uploadImagewithPath:filePath];
    [self uploadPhotoWithPath:filePath andImage:image];
}


-(void)uploadImagewithPath:(NSString *)path{

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    
    NSString * fullString = [NSString stringWithFormat:@"https://rescuemyass.herokuapp.com/postimage1"];
    NSURL *URL = [NSURL URLWithString:fullString];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    
    NSURL *filePath = [NSURL fileURLWithPath:path];
    
    NSLog(@"the request is %@",request.HTTPBody);
    NSURLSessionUploadTask *uploadTask = [manager uploadTaskWithRequest:request fromFile:filePath progress:nil completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
        if (error) {
            NSLog(@"Error: %@", error);
        } else {
            NSLog(@"Success: %@ %@", response, responseObject);
        }
    }];
    [uploadTask resume];

}

-(void)uploadPhotoWithPath:(NSString *)path andImage:(UIImage*)image{
    //UIImage *image = [UIImage imageNamed:@"joker.png"];  // name of the image
    
    NSData *imageData =  UIImagePNGRepresentation(image);  // convert your image into data
    
    NSString *urlString = [NSString stringWithFormat:@"https://rescuemyass.herokuapp.com/postimage1"];  // enter your url to upload
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];  // allocate AFHTTPManager
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    [manager.requestSerializer setValue:[NSString stringWithFormat:@"%f", self.lat] forHTTPHeaderField:@"lat"];
    [manager.requestSerializer setValue:[NSString stringWithFormat:@"%f", self.lon] forHTTPHeaderField:@"lon"];


    [manager POST:urlString parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {  // POST DATA USING MULTIPART CONTENT TYPE
        [formData appendPartWithFileData:imageData
                                    name:@"file"
                                fileName:path.lastPathComponent mimeType:@"image/jpeg"];   // add image to formData

    } progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        NSLog(@"Response: %@", responseObject);    // Get response from the server
        
        
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSLog(@"Error: %@", error);   // Gives Error
        
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)buttonact:(id)sender {
    
    
     _myTimer =  [NSTimer scheduledTimerWithTimeInterval:10.0
                                     target:self
                                                selector:@selector(takeScreenShot)
                                   userInfo:nil
                                    repeats:YES];
    
   
    
    DJIKeyManager *keyManager = [DJISDKManager keyManager];
    DJIFlightControllerKey *locationKey = [DJIFlightControllerKey keyWithParam:DJIFlightControllerParamAircraftLocation];
    
    // Start listening is as easy as passing a block with a key.
    // Note that start listening won't do a get. Your block will be executed
    // the next time the associated data is being pulled.
    [keyManager startListeningForChangesOnKey:locationKey
                                 withListener:self
                               andUpdateBlock:^(DJIKeyedValue * _Nullable oldValue, DJIKeyedValue * _Nullable newValue)
     {
         if (newValue) {
             // DJIFlightControllerParamAircraftLocation is associated with a DJISDKLocation object
             DJISDKLocation *aircraftCoordinates = (DJISDKLocation *)newValue.value;
             
             self.latAndLong.text = [NSString stringWithFormat:@"Lat: %.6f - Long: %.6f", aircraftCoordinates.coordinate.latitude, aircraftCoordinates.coordinate.longitude];
             self.lat = aircraftCoordinates.coordinate.latitude;
             self.lon = aircraftCoordinates.coordinate.longitude;
         }
     }];
    
    self.latAndLong.text = @"Started...";
    
}
#pragma mark Custom Methods
- (DJICamera*) fetchCamera {
    
    if (![DJISDKManager product]) {
        return nil;
    }
    
    if ([[DJISDKManager product] isKindOfClass:[DJIAircraft class]]) {
        return ((DJIAircraft*)[DJISDKManager product]).camera;
    }else if ([[DJISDKManager product] isKindOfClass:[DJIHandheld class]]){
        return ((DJIHandheld *)[DJISDKManager product]).camera;
    }
    
    return nil;
}

- (void)showAlertViewWithTitle:(NSString *)title withMessage:(NSString *)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)registerApp
{
    //Please enter your App key in the "DJISDKAppKey" key in info.plist file.
    [DJISDKManager registerAppWithDelegate:self];
}

- (NSString *)formattingSeconds:(NSUInteger)seconds
{
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:seconds];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"mm:ss"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    NSString *formattedTimeString = [formatter stringFromDate:date];
    return formattedTimeString;
}

#pragma mark DJIBaseProductDelegate Method
- (void)productConnected:(DJIBaseProduct *)product
{
    if(product){
        [product setDelegate:self];
        DJICamera *camera = [self fetchCamera];
        if (camera != nil) {
            camera.delegate = self;
        }
    }
}

#pragma mark DJISDKManagerDelegate Method

- (void)appRegisteredWithError:(NSError *)error
{
    NSString* message = @"Register App Successed!";
    if (error) {
        message = @"Register App Failed! Please enter your App Key and check the network.";
    }else
    {
        NSLog(@"registerAppSuccess");
    
        [DJISDKManager startConnectionToProduct];
        [[DJISDKManager videoFeeder].primaryVideoFeed addListener:self withQueue:nil];
        [[VideoPreviewer instance] start];
    }
    
    [self showAlertViewWithTitle:@"Register App" withMessage:message];
}

#pragma mark - DJICameraDelegate

-(void) camera:(DJICamera*)camera didUpdateSystemState:(DJICameraSystemState*)systemState
{
    self.isRecording = systemState.isRecording;
    
    [camera setMode:DJICameraModeRecordVideo withCompletion:^(NSError * _Nullable error) {
        
    }];
    [self.currentRecordTimeLabel setHidden:!self.isRecording];
    [self.currentRecordTimeLabel setText:[self formattingSeconds:systemState.currentVideoRecordingTimeInSeconds]];
    
}

#pragma mark - DJIVideoFeedListener
-(void)videoFeed:(DJIVideoFeed *)videoFeed didUpdateVideoData:(NSData *)videoData {
    [[VideoPreviewer instance] push:(uint8_t *)videoData.bytes length:(int)videoData.length];
}


@end
