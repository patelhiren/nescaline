/*
 Nescaline
 Copyright (c) 2007, Jonathan A. Zdziarski
 
 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; version 2
 of the License.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 
 */

#import "ScreenView.h"

@implementation ScreenView
@synthesize orientation;
@synthesize frameBufferAddress;
@synthesize frameBufferSize;
@synthesize delegate;

- (id)initWithFrame:(CGRect)frame {	
    self = [ super initWithFrame: frame ];
	if (self != nil) {
		settings = [ NSUserDefaults standardUserDefaults ];
		[ self initializeGraphics ];
    }
    return self;
}

- (void)gen_colorspace_tables
{	
	for (int i = 0; i < 256; i++)
	{
		uint32_t red = (uint32_t)((i & 31) * 255.0 / 31.0);
		uint32_t lowgreen = (uint32_t)(((i >> 5) & 7) * 255.0 / 63.0);
		lowtable[i] = red | (lowgreen << 8);
		
		uint32_t highgreen = (uint32_t)(((i & 7) << 3) * 255.0 / 63.0);
		uint32_t blue = (uint32_t)((i >> 3) * 255.0 / 31.0);
		hightable[i] = (blue << 16) | (highgreen << 8);
	}
}

- (void)initializeGraphics {
	
	NSLog(@"%s initializing screen layer in %s mode\n", __func__,
		  (UIInterfaceOrientationIsLandscape(orientation) == YES) ? "landscape" : "portrait");	
	
    /* Landscape Resolutions */
    if (UIInterfaceOrientationIsLandscape(orientation) == YES) {
		if ([ settings boolForKey: @"fullScreen" ] == YES) {
            w = 320;
            h = ([ settings boolForKey: @"aspectRatio" ] == YES) ? 341 : 480;
        } else {
            w = 240;
            h = 256;
        }
    } else {
		if ([ settings boolForKey: @"fullScreen" ] == YES) {
			NSLog(@"%s initializing for full screen", __func__);
            w = 320;
            h = 300;
        } else {
			NSLog(@"%s initializing for standard screen", __func__);
            w = 256;
            h = 240;
        }
    }
	
	frameBufferSize.height = h;
	frameBufferSize.width = w;
		
    int allocSize = 2 * w * h;

	NSLog(@"%s allocating screen layer for resolution %dx%d", __func__, w, h);

    frameBufferAddress = calloc(1, allocSize);
	NSLog(@"%s raw buffer base address: %p\n", __func__, frameBufferAddress);
	
	colorSpace = CGColorSpaceCreateDeviceRGB();
	frameBuffer8888 = calloc(1, w * h * 4);
	
	provider[0] = CGDataProviderCreateWithData(NULL, frameBuffer8888, w * h * 4, NULL);
	provider[1] = CGDataProviderCreateWithData(NULL, frameBuffer8888, w * h * 4, NULL);
	currentProvider = 0;
	
	[ self gen_colorspace_tables ];
	
	self.layer.magnificationFilter = nil;
	self.layer.minificationFilter = nil;
	self.layer.compositingFilter = nil;
	self.layer.edgeAntialiasingMask = 0;
	self.layer.opaque = YES;
	
	NSLog(@"%s graphics initialization complete\n", __func__);
}

#if 0
- (void)drawRect:(CGRect)rect {
		
	CGImageRef screenImage;
	screenImage = CGImageCreate(w, h, 8, 32, 4 * w, colorSpace, kCGBitmapByteOrder32Host | kCGImageAlphaNoneSkipFirst, provider[currentProvider], NULL, NO, kCGRenderingIntentDefault);
	if (currentProvider==0)
		currentProvider=1;
	else 
		currentProvider=0;

	
	//CGContextRef ctx = UIGraphicsGetCurrentContext();
	//CGContextScaleCTM(ctx, 1.0, -1.0);
	//CGContextDrawImage(ctx, CGRectMake(0, -h, w, h), screenImage);
	//self.layer.contents = screenImage;
	self.layer.contents = screenImage;
	//CGImageRelease (screenImage);	

	
}
#endif
 
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	UITouch *touch = [ touches anyObject ];
	CGPoint point = [ touch locationInView: self ];
    CGPoint location;
	  	
    if (UIInterfaceOrientationIsLandscape(orientation) == YES) {
        float x, y;
        y = (([ settings boolForKey: @"fullScreen" ] == YES) ? 320.0 : (240 + self.frame.origin.x)) - point.x;
        x = point.y - self.frame.origin.y;
		
        if ([ settings boolForKey: @"fullScreen" ] == YES) {
            x = (x * (256.0 / (([ settings boolForKey: @"aspectRatio" ] == YES) ? 341.0 : 480.0)));
            y = (y * (240.0 / 320.0));
        }
		
        NSLog(@"%s zapper touch at screen pos: %fx%f emulator pos: %fx%f layer origin: %fx%f\n", 
			  __func__, point.x, point.y, x, y, self.frame.origin.x, self.frame.origin.y);
        location = CGPointMake(x, y);
	} else {
        if ([ settings boolForKey: @"fullScreen" ] == YES) {
            point.x = (point.x * (256.0 / 320.0));
            point.y = (point.y * (240.0 / 300.0));
        }
		location = CGPointMake(point.x, point.y);
		NSLog(@"%s zapper touch at screen pos: %fx%f emulator pos: %fx%f layer origin: %fx%f\n", 
			  __func__, point.x, point.y, location.x, location.y, self.frame.origin.x, self.frame.origin.y);
    }
	
	if ([ delegate respondsToSelector: @selector(gameControllerZapperDidChange:locationInWindow:) ]==YES) {
		[ delegate gameControllerZapperDidChange: 0x10 locationInWindow:location ];
	}
}

- (void) emulatorCoreDidUpdateFrameBuffer {
	int x, y;
	unsigned short px;
	/* Convert active framebuffer from 565L to 8888 */
	for (y=0; y < h; y++)
	{
		for (x=0; x< w; x++)
		{
			px = frameBufferAddress[w*y+x];
//            NSLog(@"px=%x, w*y+x=%d*%d+%d=%d", px, w, y, x, w*y+x);
			frameBuffer8888[w*y+x] = hightable[px >> 8 ] + lowtable[px & 0xFF];
		}		
	}
	
	CGImageRef screenImage;
	screenImage = CGImageCreate(w, h, 8, 32, 4 * w, colorSpace, kCGBitmapByteOrder32Host | kCGImageAlphaNoneSkipFirst, provider[currentProvider], NULL, NO, kCGRenderingIntentDefault);
	if (currentProvider==0)
		currentProvider=1;
	else 
		currentProvider=0;
	self.layer.contents = (id) screenImage;
	CGImageRelease(screenImage);
}

- (void)dealloc {
	[ screenLayer release ];
    [ super dealloc ];
}

@end
