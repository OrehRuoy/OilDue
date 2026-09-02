#include "date_picker.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#if VERSION_MAJOR == 4
#if VERSION_MINOR >= 6
#import "drivers/apple_embedded/app_delegate_service.h"
#import "drivers/apple_embedded/godot_app_delegate.h"
#import "drivers/apple_embedded/godot_view_controller.h"
#elif VERSION_MINOR >= 5
#import "drivers/apple_embedded/godot_app_delegate.h"
#import "drivers/apple_embedded/view_controller.h"
#else
#import "platform/ios/app_delegate.h"
#import "platform/ios/view_controller.h"
#endif
#else
#import "platform/iphone/app_delegate.h"
#import "platform/iphone/view_controller.h"
#endif

static DatePicker *instance = NULL;

@interface GodotDatePicker : NSObject

@property (nonatomic, strong) UIDatePicker *picker;

- (void)presentYmd:(NSString *)ymd;

@end

@implementation GodotDatePicker

- (NSDateFormatter *)ymdFormatter {
	NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
	fmt.calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
	fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
	fmt.timeZone = [NSTimeZone localTimeZone];
	fmt.dateFormat = @"yyyy-MM-dd";
	return fmt;
}

- (void)presentYmd:(NSString *)ymd {
	dispatch_async(dispatch_get_main_queue(), ^{
#if VERSION_MAJOR == 4 && VERSION_MINOR >= 6
		UIViewController *root_controller = [GDTAppDelegateService viewController];
#else
		UIViewController *root_controller = [[UIApplication sharedApplication] delegate].window.rootViewController;
#endif
		if (!root_controller) {
			return;
		}

		UIViewController *host = [[UIViewController alloc] init];
		host.modalPresentationStyle = UIModalPresentationPageSheet;
		host.view.backgroundColor = [UIColor systemBackgroundColor];

		UIDatePicker *picker = [[UIDatePicker alloc] initWithFrame:CGRectZero];
		picker.datePickerMode = UIDatePickerModeDate;
		if (@available(iOS 13.4, *)) {
			picker.preferredDatePickerStyle = UIDatePickerStyleWheels;
		}
		picker.translatesAutoresizingMaskIntoConstraints = NO;
		NSDateFormatter *fmt = [self ymdFormatter];
		NSDate *start = [fmt dateFromString:ymd];
		if (start == nil) {
			start = [NSDate date];
		}
		picker.date = start;
		self.picker = picker;
		[host.view addSubview:picker];
		[NSLayoutConstraint activateConstraints:@[
			[picker.centerXAnchor constraintEqualToAnchor:host.view.centerXAnchor],
			[picker.centerYAnchor constraintEqualToAnchor:host.view.centerYAnchor],
			[picker.leadingAnchor constraintGreaterThanOrEqualToAnchor:host.view.leadingAnchor constant:16],
			[picker.trailingAnchor constraintLessThanOrEqualToAnchor:host.view.trailingAnchor constant:-16],
		]];

		UINavigationBar *bar = [[UINavigationBar alloc] init];
		bar.translatesAutoresizingMaskIntoConstraints = NO;
		UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:@"Date"];
		item.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
																			   target:self
																			   action:@selector(onCancel)];
		item.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
																				target:self
																				action:@selector(onDone)];
		bar.items = @[ item ];
		[host.view addSubview:bar];
		[NSLayoutConstraint activateConstraints:@[
			[bar.topAnchor constraintEqualToAnchor:host.view.safeAreaLayoutGuide.topAnchor],
			[bar.leadingAnchor constraintEqualToAnchor:host.view.leadingAnchor],
			[bar.trailingAnchor constraintEqualToAnchor:host.view.trailingAnchor],
		]];

		host.view.tag = 31031;
		[root_controller presentViewController:host animated:YES completion:nil];
	});
}

- (void)onCancel {
	UIViewController *root = [self rootController];
	[root dismissViewControllerAnimated:YES completion:^{
		if (DatePicker::get_singleton()) {
			DatePicker::get_singleton()->emit_cancelled();
		}
	}];
}

- (void)onDone {
	NSString *ymd = [[self ymdFormatter] stringFromDate:self.picker.date];
	UIViewController *root = [self rootController];
	[root dismissViewControllerAnimated:YES completion:^{
		if (DatePicker::get_singleton() && ymd.length > 0) {
			DatePicker::get_singleton()->emit_picked(String::utf8(ymd.UTF8String));
		} else if (DatePicker::get_singleton()) {
			DatePicker::get_singleton()->emit_cancelled();
		}
	}];
}

- (UIViewController *)rootController {
#if VERSION_MAJOR == 4 && VERSION_MINOR >= 6
	return [GDTAppDelegateService viewController];
#else
	return [[UIApplication sharedApplication] delegate].window.rootViewController;
#endif
}

@end

DatePicker *DatePicker::get_singleton() {
	return instance;
}

void DatePicker::_bind_methods() {
	ClassDB::bind_method(D_METHOD("present", "ymd"), &DatePicker::present);
	ADD_SIGNAL(MethodInfo("date_picked", PropertyInfo(Variant::STRING, "ymd")));
	ADD_SIGNAL(MethodInfo("date_cancelled"));
}

void DatePicker::present(const String &ymd) {
	CharString utf8 = ymd.utf8();
	NSString *ns = [NSString stringWithUTF8String:utf8.get_data()];
	if (ns == nil) {
		ns = @"";
	}
	[godot_date_picker presentYmd:ns];
}

void DatePicker::emit_picked(const String &ymd) {
	emit_signal("date_picked", ymd);
}

void DatePicker::emit_cancelled() {
	emit_signal("date_cancelled");
}

DatePicker::DatePicker() {
	instance = this;
	godot_date_picker = [[GodotDatePicker alloc] init];
}

DatePicker::~DatePicker() {
	instance = NULL;
	godot_date_picker = nil;
}
