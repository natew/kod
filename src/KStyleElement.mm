#import "KTextFormatter.h"
#import "KSyntaxHighlighter.h"
#import "NSColor-web.h"
#import "NSString-intern.h"
#include <srchilite/formatterparams.h>
#import <ChromiumTabs/common.h>

static NSCharacterSet *kQuoteCharacterSet = nil;

// Using a dummy category to hook code into load sequence
@implementation NSObject (dummycat_ktextformatter)
+ (void)load {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  kQuoteCharacterSet =
      [[NSCharacterSet characterSetWithCharactersInString:@"\""] retain];
  [pool drain];
}
@end


static NSColor *_NSColorFromStdStr(const std::string &color) {
  assert(color.size());
  NSString *colorDef = [NSString stringWithUTF8String:color.c_str()];
  colorDef = [colorDef stringByTrimmingCharactersInSet:kQuoteCharacterSet];
  NSColor *c = [NSColor colorWithCssDefinition:colorDef];
  #if !NDEBUG
  // warn/log missing color symbols in debug builds
  if (c == nil && colorDef && [colorDef characterAtIndex:0] != '#')
    DLOG("_NSColorFromStdStr(%@) -> NULL", colorDef);
  #endif
  return c;
}


static NSFont* _kBaseFont = nil;

NSFont* KTextFormatter::baseFont() {
  if (!_kBaseFont) {
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    _kBaseFont =
        [fontManager fontWithFamily:@"M+ 1m" traits:0 weight:0 size:13.0];
    if (!_kBaseFont) {
      //WLOG("unable to find default font \"M+\" -- using system default");
      _kBaseFont = [NSFont userFixedPitchFontOfSize:13.0];
    }
    [_kBaseFont retain];
  }
  return _kBaseFont;
}


NSString *KTextFormatter::ClassAttributeName = @"ktfclass";


//static
void KTextFormatter::clearAttributes(NSMutableAttributedString *astr,
                                     NSRange range,
                                     bool removeSpecials/*=0*/) {
  // remove all attributes we can possibly set
  [astr removeAttribute:NSFontAttributeName range:range];
  [astr removeAttribute:NSUnderlineStyleAttributeName range:range];
  [astr removeAttribute:NSForegroundColorAttributeName range:range];
  [astr removeAttribute:NSBackgroundColorAttributeName range:range];
  if (removeSpecials) {
    // remove special attribues we set
    [astr removeAttribute:KTextFormatter::ClassAttributeName range:range];
  }
}


KTextFormatter::KTextFormatter(const std::string &elem)
    : syntaxHighlighter_(NULL) {
  textAttributes_ = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
      baseFont(), NSFontAttributeName,
      nil];
  setElem(elem); // need to be called after creation of textAttributes_
}

KTextFormatter::~KTextFormatter() {
  objc_exch(&syntaxHighlighter_, nil);
  objc_exch(&textAttributes_, nil);
}


void KTextFormatter::setElem(const std::string &e) {
  elem_ = e;
  NSString *symbol = [[NSString stringWithUTF8String:e.c_str()] internedString];
  [textAttributes_ setObject:symbol forKey:ClassAttributeName];
}


void KTextFormatter::setStyle(srchilite::StyleConstantsPtr style) {
  BOOL underlined = NO;
  NSFont *font = baseFont();
  NSFontTraitMask fontTraitMask = 0;
  if (style.get()) {
    for (srchilite::StyleConstantsIterator it = style->begin();
         it != style->end(); ++it) {
      switch (*it) {
        case srchilite::ISBOLD:
          fontTraitMask |= NSBoldFontMask;
          break;
        case srchilite::ISITALIC:
          fontTraitMask |= NSItalicFontMask;
          break;
        case srchilite::ISUNDERLINE:
          underlined = YES;
          break;
        /*case srchilite::ISFIXED:
          formatter->setMonospace(true);
          break;
        case srchilite::ISNOTFIXED:
          formatter->setMonospace(false);
          break;
        case srchilite::ISNOREF:
          break;*/
      }
    }
    if (fontTraitMask) {
      NSFontManager *fontManager = [NSFontManager sharedFontManager];
      NSFont *font2 = [fontManager fontWithFamily:[font familyName]
                                           traits:fontTraitMask
                                           weight:0
                                             size:[font pointSize]];
      if (font2)
        font = font2;
    }
    
    [textAttributes_ setObject:font forKey:NSFontAttributeName];
    
    if (underlined) {
      [textAttributes_ setObject:[NSNumber numberWithBool:YES]
                          forKey:NSUnderlineStyleAttributeName];
    } else {
      [textAttributes_ removeObjectForKey:NSUnderlineStyleAttributeName];
    }
  }
}


void KTextFormatter::setForegroundColor(NSColor *color) {
  if (color) {
    [textAttributes_ setObject:color forKey:NSForegroundColorAttributeName];
  } else {
    [textAttributes_ removeObjectForKey:NSForegroundColorAttributeName];
  }
}

void KTextFormatter::setForegroundColor(const std::string &color) {
  setForegroundColor(_NSColorFromStdStr(color));
}

NSColor *KTextFormatter::foregroundColor() {
  return [textAttributes_ objectForKey:NSForegroundColorAttributeName];
}


void KTextFormatter::setBackgroundColor(NSColor *color) {
  if (color) {
    [textAttributes_ setObject:color forKey:NSBackgroundColorAttributeName];
  } else {
    [textAttributes_ removeObjectForKey:NSBackgroundColorAttributeName];
  }
}

void KTextFormatter::setBackgroundColor(const std::string &color) {
  setBackgroundColor(_NSColorFromStdStr(color));
}

NSColor *KTextFormatter::backgroundColor() {
  return [textAttributes_ objectForKey:NSBackgroundColorAttributeName];
}


void KTextFormatter::applyAttributes(NSMutableAttributedString *astr,
                                     NSRange range,
                                     bool replace/*=0*/) {
  if (replace) {
    [astr setAttributes:textAttributes_ range:range];
  } else {
    [astr addAttributes:textAttributes_ range:range];
  }
}


void KTextFormatter::format(const std::string &s,
                            const srchilite::FormatterParams *params) {
  #if 0
  if ( (elem_ != "normal" || !s.size()) && params ) {
    DLOG("<%s>format(\"%s\", start=%d)",
         elem_.c_str(), s.c_str(), params->start);
  }
  #endif
  //NSLog(@"format: s='%s', elem='%s'", s.c_str(), elem_.c_str());
  [syntaxHighlighter_ setFormat:this
                        inRange:NSMakeRange(params->start, s.size())];
}