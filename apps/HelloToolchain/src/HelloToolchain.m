#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>
#import <UIKit/UITextView.h>
#import <UIKit/UIFont.h>
#import "HelloToolchain.h"

int main(int argc, char **argv) {
    NSAutoreleasePool *autoreleasePool = [
        [ NSAutoreleasePool alloc ] init 
    ];

    int returnCode = UIApplicationMain(argc, argv, @"HelloToolchain", @"HelloToolchain");
    [ autoreleasePool release ];
    return returnCode;
}

@implementation HelloToolchain

- (void)applicationDidFinishLaunching: (UIApplication *) application {
    window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];

    CGRect windowRect = [ [ UIScreen mainScreen ] applicationFrame ];
    windowRect.origin.x = windowRect.origin.y = 0.0f;

    // Create the window object and assign it to the
    // window instance variable of the application delegate.

    window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    window.backgroundColor = [UIColor whiteColor];

    CGRect txtFrame = CGRectMake(50,150,150,150);
    UITextView *txtView = [[UITextView alloc] initWithFrame:txtFrame];
    txtView.text = @"HelloToolchain";
    UIFont *font = [UIFont boldSystemFontOfSize:18.0];
    txtView.font = font;

    [ window  addSubview: txtView ];

    [txtView release];

    // Show the window.

    [window makeKeyAndVisible];
}

@end

