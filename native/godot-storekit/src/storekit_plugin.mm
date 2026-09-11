#import "storekit_plugin.h"
#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

void emit_purchase_updated(const char *product_id);
void emit_purchase_failed(const char *message);
void emit_entitlements_updated(bool unlocked);
void emit_products_loaded(const char *price);
void emit_products_failed(const char *message);

static NSString *g_product_id = @"unlock_oil_due";
static NSString *g_price = @"";
static BOOL g_price_ready = NO;
static BOOL g_lifetime = NO;

static void oil_due_sk_log(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2) {
	va_list args;
	va_start(args, format);
	NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	NSLog(@"[OilDue StoreKit] %@", msg);
}

static void emit_purchase_updated_main(NSString *product_id) {
	NSString *copy = [product_id copy] ?: @"";
	dispatch_async(dispatch_get_main_queue(), ^{
		oil_due_sk_log(@"emit purchase_updated %@", copy);
		if (emit_purchase_updated) {
			emit_purchase_updated([copy UTF8String]);
		}
	});
}

static void emit_purchase_failed_main(NSString *message) {
	NSString *copy = [message copy] ?: @"Purchase didn't complete.";
	dispatch_async(dispatch_get_main_queue(), ^{
		oil_due_sk_log(@"emit purchase_failed %@", copy);
		if (emit_purchase_failed) {
			emit_purchase_failed([copy UTF8String]);
		}
	});
}

static void emit_entitlements_updated_main(BOOL unlocked) {
	dispatch_async(dispatch_get_main_queue(), ^{
		oil_due_sk_log(@"emit entitlements_updated %d", unlocked ? 1 : 0);
		if (emit_entitlements_updated) {
			emit_entitlements_updated(unlocked);
		}
	});
}

static void emit_products_loaded_main(NSString *price) {
	NSString *copy = [price copy] ?: @"";
	dispatch_async(dispatch_get_main_queue(), ^{
		oil_due_sk_log(@"emit products_loaded %@", copy);
		if (emit_products_loaded) {
			emit_products_loaded([copy UTF8String]);
		}
	});
}

static void emit_products_failed_main(NSString *message) {
	NSString *copy = [message copy] ?: @"Could not load App Store products. Check your connection.";
	dispatch_async(dispatch_get_main_queue(), ^{
		oil_due_sk_log(@"emit products_failed %@", copy);
		if (emit_products_failed) {
			emit_products_failed([copy UTF8String]);
		}
	});
}

static NSString *TapticoStoreErrorMessage(NSError *error) {
	if (error == nil) {
		return @"Purchase could not be completed.";
	}
	if ([error.domain isEqualToString:SKErrorDomain]) {
		switch (error.code) {
			case SKErrorPaymentCancelled:
				return @"Purchase cancelled.";
			case SKErrorPaymentNotAllowed:
				return @"Purchases are not allowed on this device.";
			case SKErrorStoreProductNotAvailable:
				return @"This product is not available in your App Store region.";
			default:
				break;
		}
	}
	if ([error.domain isEqualToString:NSURLErrorDomain]) {
		return @"No connection to the App Store. Check your network and try again.";
	}
	return error.localizedDescription ?: @"Purchase could not be completed.";
}

static NSString *OilDueTxnStateName(SKPaymentTransactionState state) {
	switch (state) {
		case SKPaymentTransactionStatePurchasing:
			return @"purchasing";
		case SKPaymentTransactionStatePurchased:
			return @"purchased";
		case SKPaymentTransactionStateFailed:
			return @"failed";
		case SKPaymentTransactionStateRestored:
			return @"restored";
		case SKPaymentTransactionStateDeferred:
			return @"deferred";
		default:
			return @"unknown";
	}
}

@interface TapticoStoreKit : NSObject <SKProductsRequestDelegate, SKPaymentTransactionObserver>
@property(nonatomic, copy) NSString *productId;
@property(nonatomic, strong) SKProduct *cachedProduct;
@property(nonatomic, strong) SKProductsRequest *productsRequest;
@property(nonatomic, assign) BOOL pendingPurchase;
@end

@implementation TapticoStoreKit

- (instancetype)init {
	self = [super init];
	if (self) {
		self.productId = g_product_id;
		self.pendingPurchase = NO;
		void (^addObserver)(void) = ^{
			oil_due_sk_log(@"addTransactionObserver product=%@", self.productId ?: g_product_id);
			[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
		};
		if ([NSThread isMainThread]) {
			addObserver();
		} else {
			dispatch_sync(dispatch_get_main_queue(), addObserver);
		}
	}
	return self;
}

- (void)dealloc {
	[[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

- (void)initialize:(NSString *)productId {
	self.productId = productId.length > 0 ? productId : g_product_id;
	self.pendingPurchase = NO;
	oil_due_sk_log(@"initialize sku=%@", self.productId);
	[self fetchProducts];
	[self syncLocalEntitlements];
}

- (void)fetchProducts {
	NSString *sku = self.productId ?: g_product_id;
	oil_due_sk_log(@"fetchProducts sku=%@", sku);
	self.productsRequest.delegate = nil;
	self.productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithObject:sku]];
	self.productsRequest.delegate = self;
	[self.productsRequest start];
}

- (void)purchase:(NSString *)productId {
	if (![SKPaymentQueue canMakePayments]) {
		oil_due_sk_log(@"purchase blocked canMakePayments=NO");
		emit_purchase_failed_main(@"Purchases are not allowed on this device.");
		return;
	}
	NSString *sku = productId.length > 0 ? productId : (self.productId ?: g_product_id);
	self.productId = sku;
	oil_due_sk_log(@"purchase sku=%@ cached=%@", sku, self.cachedProduct.productIdentifier ?: @"(none)");
	if (self.cachedProduct && [self.cachedProduct.productIdentifier isEqualToString:sku]) {
		SKPayment *payment = [SKPayment paymentWithProduct:self.cachedProduct];
		[[SKPaymentQueue defaultQueue] addPayment:payment];
		return;
	}
	self.pendingPurchase = YES;
	[self fetchProducts];
}

- (void)restore {
	oil_due_sk_log(@"restoreCompletedTransactions");
	[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (void)syncLocalEntitlements {
	for (SKPaymentTransaction *transaction in [SKPaymentQueue defaultQueue].transactions) {
		BOOL matches = [transaction.payment.productIdentifier isEqualToString:(self.productId ?: g_product_id)];
		if (!matches) {
			continue;
		}
		if (transaction.transactionState == SKPaymentTransactionStatePurchased ||
			transaction.transactionState == SKPaymentTransactionStateRestored) {
			g_lifetime = YES;
			oil_due_sk_log(@"syncLocalEntitlements lifetime from queue txn=%@", transaction.payment.productIdentifier);
		}
	}
}

- (BOOL)has_lifetime { return g_lifetime; }
- (NSString *)get_price { return g_price ?: @""; }
- (BOOL)is_price_ready { return g_price_ready; }

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
	NSArray *invalid = response.invalidProductIdentifiers ?: @[];
	oil_due_sk_log(@"products count=%lu invalid=%@", (unsigned long)response.products.count, [invalid componentsJoinedByString:@","]);
	self.productsRequest.delegate = nil;
	self.productsRequest = nil;
	if (response.products.count == 0) {
		g_price_ready = NO;
		g_price = @"";
		NSString *fail = invalid.count > 0
			? @"Couldn't load Unlock Oil Due from the App Store."
			: @"Could not load App Store products. Check your connection.";
		if (self.pendingPurchase) {
			self.pendingPurchase = NO;
			emit_purchase_failed_main(fail);
		} else {
			emit_products_failed_main(fail);
		}
		return;
	}
	SKProduct *product = response.products.firstObject;
	self.cachedProduct = product;
	NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
	formatter.numberStyle = NSNumberFormatterCurrencyStyle;
	formatter.locale = product.priceLocale;
	NSString *localized = [formatter stringFromNumber:product.price];
	g_price = localized ?: @"";
	g_price_ready = g_price.length > 0;
	oil_due_sk_log(@"product ready id=%@ price=%@", product.productIdentifier, g_price);
	if (g_price_ready) {
		emit_products_loaded_main(g_price);
	} else {
		emit_products_failed_main(@"Could not load App Store products. Check your connection.");
	}
	if (self.pendingPurchase) {
		self.pendingPurchase = NO;
		SKPayment *payment = [SKPayment paymentWithProduct:product];
		[[SKPaymentQueue defaultQueue] addPayment:payment];
	}
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
	oil_due_sk_log(@"products request failed %@", TapticoStoreErrorMessage(error));
	self.productsRequest.delegate = nil;
	self.productsRequest = nil;
	g_price_ready = NO;
	BOOL wasPurchase = self.pendingPurchase;
	self.pendingPurchase = NO;
	NSString *msg = TapticoStoreErrorMessage(error);
	if (wasPurchase) {
		emit_purchase_failed_main(msg);
	} else {
		emit_products_failed_main(msg);
	}
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
	for (SKPaymentTransaction *transaction in transactions) {
		NSString *sku = transaction.payment.productIdentifier ?: @"";
		oil_due_sk_log(@"txn %@ state=%@", sku, OilDueTxnStateName(transaction.transactionState));
		if (![sku isEqualToString:(self.productId ?: g_product_id)]) {
			oil_due_sk_log(@"txn skip other sku");
			continue;
		}
		switch (transaction.transactionState) {
			case SKPaymentTransactionStatePurchased:
			case SKPaymentTransactionStateRestored:
				g_lifetime = YES;
				emit_purchase_updated_main(sku);
				emit_entitlements_updated_main(YES);
				[queue finishTransaction:transaction];
				oil_due_sk_log(@"finishTransaction %@", sku);
				break;
			case SKPaymentTransactionStateFailed: {
				NSError *error = transaction.error;
				BOOL cancelled = error && [error.domain isEqualToString:SKErrorDomain] && error.code == SKErrorPaymentCancelled;
				NSString *msg = cancelled ? @"Purchase cancelled." : TapticoStoreErrorMessage(error);
				emit_purchase_failed_main(msg);
				[queue finishTransaction:transaction];
				oil_due_sk_log(@"finishTransaction failed %@", sku);
				break;
			}
			case SKPaymentTransactionStateDeferred:
				emit_purchase_failed_main(@"Waiting for approval.");
				break;
			default:
				break;
		}
	}
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
	[self syncLocalEntitlements];
	oil_due_sk_log(@"restore finished lifetime=%d", g_lifetime ? 1 : 0);
	if (g_lifetime) {
		emit_entitlements_updated_main(YES);
	} else {
		emit_purchase_failed_main(@"Nothing to restore.");
	}
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
	NSString *msg = TapticoStoreErrorMessage(error);
	oil_due_sk_log(@"restore failed %@", msg);
	emit_purchase_failed_main(msg);
}

@end

static TapticoStoreKit *g_storekit = nil;

extern "C" {

void storekit_init_impl() {
	if (g_storekit == nil) {
		g_storekit = [[TapticoStoreKit alloc] init];
	}
}

void storekit_deinit_impl() {
	g_storekit = nil;
}

void storekit_initialize(const char *product_id) {
	NSString *sku = product_id ? [NSString stringWithUTF8String:product_id] : @"";
	[g_storekit initialize:sku];
}

void storekit_purchase(const char *product_id) {
	NSString *sku = product_id ? [NSString stringWithUTF8String:product_id] : @"";
	[g_storekit purchase:sku];
}

void storekit_restore() {
	[g_storekit restore];
}

void storekit_request_review() {
	dispatch_async(dispatch_get_main_queue(), ^{
		if (@available(iOS 16.0, *)) {
			UIWindowScene *scene = nil;
			for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
				if (candidate.activationState == UISceneActivationStateForegroundActive &&
					[candidate isKindOfClass:[UIWindowScene class]]) {
					scene = (UIWindowScene *)candidate;
					break;
				}
			}
			if (scene == nil) {
				for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
					if ([candidate isKindOfClass:[UIWindowScene class]]) {
						scene = (UIWindowScene *)candidate;
						break;
					}
				}
			}
			if (scene != nil) {
				[SKStoreReviewController requestReviewInScene:scene];
			}
		}
	});
}

const char *storekit_get_price() {
	return [(g_price ?: @"") UTF8String];
}

bool storekit_is_price_ready() {
	return [g_storekit is_price_ready];
}

bool storekit_has_lifetime() {
	return [g_storekit has_lifetime];
}

}
