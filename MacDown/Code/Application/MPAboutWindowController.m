//
//  MPAboutWindowController.m
//  MacDown
//
//  Custom About window for the treehousetim fork.
//

#import "MPAboutWindowController.h"

static NSString *const kForkURL    = @"https://github.com/treehousetim/macdown";
static NSString *const kOriginalURL = @"https://github.com/MacDownApp/macdown";

@interface MPAboutWindowController ()
@property (nonatomic, strong) NSTextView *licensesTextView;
@end

@implementation MPAboutWindowController

+ (instancetype)sharedController
{
    static MPAboutWindowController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    NSRect frame = NSMakeRect(0, 0, 560, 640);
    NSWindowStyleMask style = NSWindowStyleMaskTitled
                            | NSWindowStyleMaskClosable
                            | NSWindowStyleMaskMiniaturizable
                            | NSWindowStyleMaskResizable;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:style
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = NSLocalizedString(@"About MacDown", nil);
    window.minSize = NSMakeSize(480, 480);
    window.releasedWhenClosed = NO;
    [window center];

    self = [super initWithWindow:window];
    if (!self) return nil;

    [self buildContentView];
    return self;
}

- (void)buildContentView
{
    NSView *content = [[NSView alloc] initWithFrame:self.window.contentView.bounds];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    self.window.contentView = content;

    // App icon.
    NSImageView *iconView = [[NSImageView alloc] init];
    iconView.image = [NSApp applicationIconImage];
    iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:iconView];

    // Title.
    NSTextField *title = [self labelWithString:@"MacDown"];
    title.font = [NSFont systemFontOfSize:28 weight:NSFontWeightBold];
    title.alignment = NSTextAlignmentCenter;
    [content addSubview:title];

    // Version line.
    NSDictionary *info = [NSBundle mainBundle].infoDictionary;
    NSString *shortVersion = info[@"CFBundleShortVersionString"] ?: @"";
    NSString *buildVersion = info[@"CFBundleBuildVersion"] ?: info[@"CFBundleVersion"] ?: @"";
    NSString *versionString = [NSString stringWithFormat:@"Version %@ (%@)", shortVersion, buildVersion];
    NSTextField *version = [self labelWithString:versionString];
    version.font = [NSFont systemFontOfSize:11];
    version.textColor = [NSColor secondaryLabelColor];
    version.alignment = NSTextAlignmentCenter;
    [content addSubview:version];

    // Fork attribution.
    NSTextField *forkLine = [self labelWithString:@""];
    forkLine.allowsEditingTextAttributes = YES;
    forkLine.selectable = YES;
    forkLine.attributedStringValue = [self attributedAttributionString];
    forkLine.alignment = NSTextAlignmentCenter;
    [content addSubview:forkLine];

    // Licenses scroll view.
    NSScrollView *scroll = [[NSScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.borderType = NSBezelBorder;
    scroll.hasVerticalScroller = YES;
    scroll.hasHorizontalScroller = NO;
    scroll.autohidesScrollers = YES;

    NSTextView *textView = [[NSTextView alloc] init];
    textView.editable = NO;
    textView.richText = NO;
    textView.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    textView.textContainerInset = NSMakeSize(8, 8);
    textView.string = [self collectedLicensesText];
    textView.minSize = NSMakeSize(0, 0);
    textView.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);
    textView.verticallyResizable = YES;
    textView.horizontallyResizable = NO;
    textView.autoresizingMask = NSViewWidthSizable;
    textView.textContainer.widthTracksTextView = YES;
    textView.textContainer.containerSize = NSMakeSize(scroll.contentSize.width, FLT_MAX);
    scroll.documentView = textView;
    self.licensesTextView = textView;
    [content addSubview:scroll];

    // Constraints.
    [NSLayoutConstraint activateConstraints:@[
        [iconView.topAnchor constraintEqualToAnchor:content.topAnchor constant:24],
        [iconView.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [iconView.widthAnchor constraintEqualToConstant:96],
        [iconView.heightAnchor constraintEqualToConstant:96],

        [title.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:12],
        [title.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [title.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],

        [version.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:4],
        [version.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [version.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],

        [forkLine.topAnchor constraintEqualToAnchor:version.bottomAnchor constant:14],
        [forkLine.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [forkLine.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],

        [scroll.topAnchor constraintEqualToAnchor:forkLine.bottomAnchor constant:18],
        [scroll.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [scroll.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [scroll.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-20],
    ]];
}

- (NSTextField *)labelWithString:(NSString *)s
{
    NSTextField *f = [NSTextField labelWithString:s];
    f.translatesAutoresizingMaskIntoConstraints = NO;
    f.lineBreakMode = NSLineBreakByWordWrapping;
    f.maximumNumberOfLines = 0;
    return f;
}

- (NSAttributedString *)attributedAttributionString
{
    NSMutableAttributedString *out = [[NSMutableAttributedString alloc] init];

    NSDictionary *body = @{
        NSFontAttributeName: [NSFont systemFontOfSize:12],
        NSForegroundColorAttributeName: [NSColor labelColor],
    };
    NSDictionary *bold = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:12],
        NSForegroundColorAttributeName: [NSColor labelColor],
    };

    [out appendAttributedString:
        [[NSAttributedString alloc] initWithString:@"This binary is built and released by "
                                        attributes:body]];
    NSMutableAttributedString *forkLink = [[NSMutableAttributedString alloc]
        initWithString:@"treehousetim" attributes:bold];
    [forkLink addAttribute:NSLinkAttributeName value:kForkURL
                     range:NSMakeRange(0, forkLink.length)];
    [out appendAttributedString:forkLink];

    [out appendAttributedString:
        [[NSAttributedString alloc] initWithString:@".\n" attributes:body]];

    [out appendAttributedString:
        [[NSAttributedString alloc] initWithString:@"Original MacDown by Tzu-ping Chung & contributors ("
                                        attributes:body]];
    NSMutableAttributedString *origLink = [[NSMutableAttributedString alloc]
        initWithString:@"upstream" attributes:body];
    [origLink addAttribute:NSLinkAttributeName value:kOriginalURL
                     range:NSMakeRange(0, origLink.length)];
    [out appendAttributedString:origLink];
    [out appendAttributedString:
        [[NSAttributedString alloc] initWithString:@")." attributes:body]];

    NSMutableParagraphStyle *p = [[NSMutableParagraphStyle alloc] init];
    p.alignment = NSTextAlignmentCenter;
    p.lineSpacing = 2;
    [out addAttribute:NSParagraphStyleAttributeName value:p
                range:NSMakeRange(0, out.length)];
    return out;
}

- (NSString *)collectedLicensesText
{
    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *licenseDir = [bundle URLForResource:@"LICENSE" withExtension:nil];
    if (!licenseDir) {
        return @"License files were not bundled with this build.";
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *err = nil;
    NSArray<NSURL *> *contents = [fm contentsOfDirectoryAtURL:licenseDir
                                   includingPropertiesForKeys:nil
                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                        error:&err];
    if (!contents) {
        return [NSString stringWithFormat:@"Could not enumerate licenses: %@",
                err.localizedDescription];
    }

    // Sort so macdown.txt floats to the top, then alphabetic.
    NSArray<NSURL *> *sorted = [contents sortedArrayUsingComparator:
        ^NSComparisonResult(NSURL *a, NSURL *b) {
            NSString *na = a.lastPathComponent;
            NSString *nb = b.lastPathComponent;
            BOOL ma = [na isEqualToString:@"macdown.txt"];
            BOOL mb = [nb isEqualToString:@"macdown.txt"];
            if (ma && !mb) return NSOrderedAscending;
            if (mb && !ma) return NSOrderedDescending;
            return [na caseInsensitiveCompare:nb];
        }];

    NSMutableString *out = [NSMutableString string];
    [out appendString:@"MacDown is open source software released under the MIT License.\n"];
    [out appendString:@"It bundles and links the following third-party components, each "
                       "distributed under its own license terms reproduced below.\n\n"];
    [out appendString:@"================================================================\n\n"];

    for (NSURL *url in sorted) {
        NSString *name = [url.lastPathComponent stringByDeletingPathExtension];
        NSString *body = [NSString stringWithContentsOfURL:url
                                                  encoding:NSUTF8StringEncoding error:nil];
        if (!body) continue;
        [out appendFormat:@"### %@\n\n", name];
        [out appendString:body];
        if (![body hasSuffix:@"\n"]) [out appendString:@"\n"];
        [out appendString:@"\n----------------------------------------------------------------\n\n"];
    }

    return out;
}

@end
