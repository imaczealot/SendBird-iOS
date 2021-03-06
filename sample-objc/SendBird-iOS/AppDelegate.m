//
//  AppDelegate.m
//  SendBird-iOS
//
//  Created by Jed Kyung on 9/19/16.
//  Copyright © 2016 SendBird. All rights reserved.
//

#import "AppDelegate.h"
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <UserNotifications/UserNotifications.h>

#import "Constants.h"
#import "ConnectionManager.h"
#import "ViewController.h"
#import "MenuViewController.h"

@interface AppDelegate () <UNUserNotificationCenterDelegate>

@end

@implementation AppDelegate

+ (nonnull NSURLCache *)imageCache {
    static dispatch_once_t p = 0;
    __strong static NSURLCache *_sharedObject = nil;
    
    dispatch_once(&p, ^{
        _sharedObject = [NSURLCache sharedURLCache];
    });
    
    return _sharedObject;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self registerForRemoteNotification];
    
    [[UINavigationBar appearance] setTitleTextAttributes:@{
                                                           NSFontAttributeName: [Constants navigationBarTitleFont]
                                                           }];
    [[UINavigationBar appearance] setTintColor:[Constants navigationBarTitleColor]];
    
    application.applicationIconBadgeNumber = 0;
    
    [SBDMain initWithApplicationId:@"9DA1B1F4-0BE6-4DA8-82C5-2E81DAB56F23"];
    [SBDMain setLogLevel:SBDLogLevelNone];
    [SBDOptions setUseMemberAsMessageSender:YES];
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    if (audioSession != nil) {
        NSError *error = nil;
        [audioSession setCategory:AVAudioSessionCategoryPlayback error:&error];
        
        if (error != nil) {
            NSLog(@"Set Audio Session error: %@", error);
        }
    }
    
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"LaunchScreen" bundle:nil];
    UIViewController *launchViewController = [storyboard instantiateViewControllerWithIdentifier:@"com.sendbird.sample.viewcontroller.launch"];
    self.window.rootViewController = launchViewController;
    [self.window makeKeyAndVisible];
    
    [ConnectionManager loginWithCompletionHandler:^(SBDUser * _Nullable user, NSError * _Nullable error) {
        if (error != nil) {
            UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
            UIViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:@"com.sendbird.sample.viewcontroller.initial"];
            self.window.rootViewController = viewController;
            [self.window makeKeyAndVisible];
            return;
        }
        
        self.window.rootViewController = [[MenuViewController alloc] init];;
        [self.window makeKeyAndVisible];
    }];
    
    return YES;
}

- (void)registerForRemoteNotification {
    float osVersion = [UIDevice currentDevice].systemVersion.floatValue;
    if (osVersion >= 10.0) {
#if !(TARGET_OS_SIMULATOR) && (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0)
        [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:(UNAuthorizationOptionAlert|UNAuthorizationOptionBadge|UNAuthorizationOptionSound) completionHandler:^(BOOL granted, NSError * _Nullable error) {
            NSLog(@"Tries to register push token, granted: %d, error: %@", granted, error);
            if (granted) {
                [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
                    if (settings.authorizationStatus != UNAuthorizationStatusAuthorized) {
                        return;
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[UIApplication sharedApplication] registerForRemoteNotifications];
                    });
                }];
            }
        }];
        return;
#endif
    } else {
#if !(TARGET_OS_SIMULATOR)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
        if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
            UIUserNotificationSettings* notificationSettings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound categories:nil];
            [[UIApplication sharedApplication] registerUserNotificationSettings:notificationSettings];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[UIApplication sharedApplication] registerForRemoteNotifications];
            });
        }
#pragma clang diagnostic pop
#endif
    }
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
//    [SBDMain disconnectWithCompletionHandler:^{
//        NSLog(@"<<<<< Disconected by app delegate. >>>>>");
//    }];
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
//    [SBDMain connectWithUserId:nil completionHandler:^(SBDUser * _Nullable user, SBDError * _Nullable error) {
//        if (error != nil) {
//            NSLog(@"##### Error when connecting in app delegate. #####");
//
//            return;
//        }
//
//        NSLog(@">>>>> Connected in app delegat(%@). <<<<<", user.userId);
//    }];
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSLog(@"Device token: %@", deviceToken.description);
    [SBDMain registerDevicePushToken:deviceToken unique:YES completionHandler:^(SBDPushTokenRegistrationStatus status, SBDError * _Nullable error) {
        if (error == nil) {
            if (status == SBDPushTokenRegistrationStatusPending) {
                NSLog(@"Push registration is pending.");
            }
            else {
                NSLog(@"APNS Token is registered.");
            }
        }
        else {
            NSLog(@"APNS registration failed with error: %@", error);
        }
    }];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"Failed to get token, error: %@", error);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    if (userInfo[@"sendbird"] != nil) {
        NSDictionary *sendBirdPayload = userInfo[@"sendbird"];
        NSString *channel = sendBirdPayload[@"channel"][@"channel_url"];
        NSString *channelType = sendBirdPayload[@"channel_type"];
        if ([channelType isEqualToString:@"group_messaging"]) {
            self.receivedPushChannelUrl = channel;
        }
    }

    NSLog(@"[Sendbird] application: %@ didReceiveRemoteNotification: %@", application, userInfo);
}

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(nonnull void (^)(void))completionHandler {
    NSLog(@"method for handling events for background url session is waiting to be process. background session id: %@", identifier);
    if (completionHandler != nil) {
        completionHandler();
    }
}

@end
