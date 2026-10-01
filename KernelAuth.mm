#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static void showAlert(NSString *title, NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                for (UIWindow *w in ws.windows) {
                    if (w.isKeyWindow) { window = w; break; }
                }
            }
        }
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:title
            message:message
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK"
            style:UIAlertActionStyleDefault handler:nil]];
        [window.rootViewController presentViewController:alert animated:YES completion:nil];
    });
}

static void performAuth(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSString *key = [UIPasteboard generalPasteboard].string;
        key = [key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        if (!key || key.length == 0) {
            showAlert(@"Error", @"Please copy your key to clipboard before trying to log in.");
            return;
        }

        NSString *udid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        NSURL *url = [NSURL URLWithString:@"http://ramp.kz:3001/auth"];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.HTTPMethod = @"POST";
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

        NSDictionary *body = @{ @"key": key, @"udid": udid };
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
        request.timeoutInterval = 10.0;

        [[NSURLSession.sharedSession dataTaskWithRequest:request
            completionHandler:^(NSData *data, NSURLResponse *r, NSError *error) {
            if (error || !data) {
                showAlert(@"Error", @"Connection failed. Check your internet.");
                return;
            }
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (!json) { showAlert(@"Error", @"Invalid server response."); return; }

            NSString *status = json[@"status"];
            if ([status isEqualToString:@"ok"]) return;
            else if ([status isEqualToString:@"banned"])
                showAlert(@"Error", [NSString stringWithFormat:@"Banned: %@, expires at: %@",
                    json[@"ban_code"] ?: @"11", json[@"expires_at"] ?: @""]);
            else if ([status isEqualToString:@"expired"])
                showAlert(@"Error", @"Your subscription has expired");
            else if ([status isEqualToString:@"device_mismatch"])
                showAlert(@"Error", @"Your device has changed since the last login. Contact the seller");
            else
                showAlert(@"Error", @"Invalid key.");
        }] resume];
    });
}

__attribute__((constructor))
static void dylib_init(void) {
    performAuth();
}
