# Jekyll AttachmentTag for OS X
# 
# Adds an "attachment" Liquid tag for displaying information about
# files and automatically creates icons for the display.
# 
# Copyright 2016 Brian D. Wells
#
# License: MIT

Kernel.require 'inline'
require 'date'
require 'filesize'
require 'fileutils'

class Inline::ObjC < Inline::C
  def initialize(mod)
    super(mod)
  end
  
  def import(header)
    @src << "#import #{header}"
  end
end

module Jekyll
  module Errors
		AttachmentIconError = Class.new(FatalException)
  end

  class AttachmentTag < Liquid::Block

    def initialize(tag_name, markup, tokens)
      super
      # extract params from markup
      @config = {}
      lastkey = "!!".to_sym
      @config[lastkey] = markup.strip
      x = markup
      while (m = x.match(/([A-Za-z_-]+):\s/)) do
      	@config[lastkey] = m.pre_match.strip
      	lastkey = m[1].to_sym
      	x = m.post_match
      	@config[lastkey] = x.strip
      end
      @file_path = @config["!!".to_sym]
    end

    def render(context)
    	site = context.registers[:site]
    	page_name = context.registers[:page]["name"]
    	converters = site.pages.find {|s| s.name == page_name }.converters
      content = converters.reduce(super(context)) do |output,converter|
      	begin
      		converter.convert output
      	rescue => e
      		path = context.registers[:page]["path"]
      		Jekyll.logger.error "Conversion error:", "#{converter.class} encountered an error while converting '#{path}':"
      		Jekyll.logger.error("", e.to_s)
      		raise e
      	end
      end

      site.config['keep_files'] << 'icons' unless site.config['keep_files'].include?('icons')

    	# get details from file
      full_path = File.join(site.config['source'], @file_path)
      unless @config.key?(:name)
      	@config[:name] = File.basename(@file_path) 	
      end 
      unless @config.key?(:size)
      	@config[:size] = Filesize.new(File.size(full_path)).pretty
      end
      unless @config.key?(:modified_date)
      	@config[:modified_date] = File.mtime(full_path).to_s
      end
      
      # get icon for file
      (name, image) = self.get_icon_image(@config.merge({ file_path: full_path }))

      icon_url = File.join(site.config['baseurl'],"icons",name)
      icon_path = File.join(site.config['destination'],icon_url)
      
      unless File.exists?(icon_path)
      	FileUtils.mkdir_p(File.dirname(icon_path))
      	File.open(icon_path, 'wb') do |output|
      		output.write image
      	end
      end

      <<-HTML.gsub(/^\s+/, '').gsub("\n",'')
        <div class="download">
        <div class="dlicon">
        <a href="#{@file_path}" class="dllink"><img src="#{icon_url}"></a>
        <div class="dlsize">#{@config[:size]}</div>
        </div>
        <div class="dlinfo">
        <h2><a href="#{@file_path}" class="dllink">#{@config[:name]}</a></h2>
        <div class="dldate">#{Date.parse(@config[:modified_date]).iso8601}</div>
        <div class="dldesc">#{content}</div>
        </div>
        </div>
      HTML
    end

    inline(:ObjC) do |builder|
	    builder.import "<AppKit/AppKit.h>"
	    builder.import "<CommonCrypto/CommonDigest.h>"
  	  builder.add_compile_flags '-x objective-c', '-framework AppKit'
  	  builder.c_raw <<-EOF

static VALUE get_icon_image(int argc, VALUE *argv, VALUE self)
{ 
    ID format_bmp  = rb_intern("bmp");
    ID format_gif  = rb_intern("gif");
    ID format_jpg  = rb_intern("jpg");
    ID format_jpe  = rb_intern("jpe");
    ID format_jpeg = rb_intern("jpeg");
    ID format_jp2  = rb_intern("jp2");
    ID format_jpf  = rb_intern("jpf");
    ID format_png  = rb_intern("png");
    ID format_tif  = rb_intern("tif");
    ID format_tiff = rb_intern("tiff");

    VALUE jekyll_module = rb_const_get(rb_cObject, rb_intern("Jekyll"));
    VALUE errors_module = rb_const_get(jekyll_module, rb_intern("Errors"));
    VALUE attachment_icon_error = rb_const_get(errors_module, rb_intern("AttachmentIconError"));

    VALUE result = Qnil;
    VALUE val;
    CGFloat size = 64.0f;
    ID format_id = format_png;
    VALUE whiny = Qnil;
    VALUE name;
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    NSImage *image = nil;
    NSArray *reps;
    NSBitmapImageRep *rep_selected = nil;
    NSBitmapImageRep *new_rep = nil;
    NSGraphicsContext *gfx_ctx;
    NSUInteger format_type;
    NSDictionary *format_properties;
    NSData *data;

    // expecting a hash
    if (!argc)
        rb_raise(rb_eArgError, "not enough arguments");
    if (argc > 0)
        Check_Type(argv[0], T_HASH);

    // get size
    val = rb_hash_aref(argv[0], ID2SYM(rb_intern("icon_size")));
    if (!NIL_P(val)) {
    	  size = NUM2DBL(val);
    }

    // get format
    val = rb_hash_aref(argv[0], ID2SYM(rb_intern("icon_format")));
    if (!NIL_P(val)) {
    	  format_id = SYM2ID(val);
    }

    // get whiny
    whiny = rb_hash_aref(argv[0], ID2SYM(rb_intern("whiny")));

    // get name
    val = rb_hash_aref(argv[0], ID2SYM(rb_intern("name")));
    if (NIL_P(val)) {
    	  name = rb_str_new2("UNKNOWN");
    } else {
    		name = val;
    }

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // get image_path
    val = rb_hash_aref(argv[0], ID2SYM(rb_intern("image_path")));
    if (!NIL_P(val)) {
        // load specified image
        Check_Type(val, T_STRING);
        image = [[NSImage alloc] initWithContentsOfFile:[NSString stringWithCString:RSTRING_PTR(val) encoding:NSASCIIStringEncoding]];
        if (image == nil && RTEST(whiny))
            rb_warn("Unable to load image at path: %s", RSTRING_PTR(val));
    }

    // get file_type
    val = rb_hash_aref(argv[0], ID2SYM(rb_intern("file_type")));
    if (!NIL_P(val) && image == nil) {
        Check_Type(val, T_STRING);
        // get icon for specified type
        image = [ws iconForFileType:[NSString stringWithCString:RSTRING_PTR(val) encoding:NSASCIIStringEncoding]];
        if (image == nil && RTEST(whiny))
            rb_warn("Unable to get icon for file type: %s", RSTRING_PTR(val));
        [image retain];
    }
    
    // get file_path
    val = rb_hash_aref(argv[0], ID2SYM(rb_intern("file_path")));
    if (!NIL_P(val) && image == nil) {
        // get icon for specified file
        Check_Type(val, T_STRING);
        image = [ws iconForFile:[NSString stringWithCString:RSTRING_PTR(val) encoding:NSASCIIStringEncoding]];
        if (image == nil && RTEST(whiny))
            rb_warn("Unable to get icon for file: %s", RSTRING_PTR(val));
        [image retain];
    }
    
    if (image != nil) {
        reps = [NSBitmapImageRep imageRepsWithData:[image TIFFRepresentation]];
        for (NSBitmapImageRep *rep in reps) {
            CGFloat width = [rep size].width;
            if (width == size) {
                // exact match
                rep_selected = rep;
                break;
            } else if (width > size) {
                if (rep_selected == nil || [rep_selected size].width > width) {
                    rep_selected = rep;
                }
            } else if (width < size) {
                if (rep_selected == nil || [rep_selected size].width < width) {
                    rep_selected = rep;
                }
            }
        }

        // done with image
        [image release];

        if (rep_selected == nil) {
            if (RTEST(whiny)) {
                [pool drain];
                rb_raise(attachment_icon_error,"Unable to find a usable icon for %s",RSTRING_PTR(name));
            }
        } else {
				    // always redraw image to prevent scaling for Retina displays

            // make new image rep of the correct size
            new_rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil
                                                pixelsWide:size 
                                                pixelsHigh:size 
                                                bitsPerSample:[rep_selected bitsPerPixel] / [rep_selected samplesPerPixel] 
                                                samplesPerPixel:[rep_selected samplesPerPixel] 
                                                hasAlpha:[rep_selected hasAlpha] 
                                                isPlanar:false 
                                                colorSpaceName:[rep_selected colorSpaceName] 
                                                bytesPerRow:0 
                                                bitsPerPixel:0];
            // new graphics context
            gfx_ctx = [NSGraphicsContext graphicsContextWithBitmapImageRep:new_rep];
            if (gfx_ctx == nil) {
                [new_rep release];
                if (RTEST(whiny)) {
                    [pool drain];
                    rb_raise(attachment_icon_error, "Unable to generate context for %s", RSTRING_PTR(name));
                }
            } else {
                // draw image into new rep
                [NSGraphicsContext saveGraphicsState];
                [NSGraphicsContext setCurrentContext:gfx_ctx];
                if ([rep_selected drawInRect:NSMakeRect(0.0, 0.0, size, size)])
                    rep_selected = new_rep;
                else
                    rep_selected = nil;
                [NSGraphicsContext restoreGraphicsState];
                if (rep_selected == nil && RTEST(whiny)) {
                    [new_rep release];
                    [pool drain];
                    rb_raise(attachment_icon_error, "Unable to draw representation for %s", RSTRING_PTR(name));
                }
            }
        }
        if (rep_selected != nil) {
            // get selected format
            if (format_id == format_bmp) {
                format_type = NSBMPFileType;
            } else if (format_id == format_gif) {
                format_type = NSGIFFileType;
            } else if (format_id == format_jpg || format_id == format_jpe || format_id == format_jpeg) {
                format_type = NSJPEGFileType;
            } else if (format_id == format_jp2 || format_id == format_jpf) {
                format_type = NSJPEG2000FileType;
            } else if (format_id == format_png) {
                format_type = NSPNGFileType;
            } else if (format_id == format_tif || format_id == format_tiff) {
                format_type = NSTIFFFileType;
            } else {
                [rep_selected release];
                rep_selected = nil;
                if (RTEST(whiny)) {
                    [pool drain];
                    rb_raise(attachment_icon_error, "Unsupported format \\\"%s\\\" for %s", RSTRING_PTR(rb_funcall(ID2SYM(format_id), rb_intern("to_s"), 0)), RSTRING_PTR(name));
                }
            }
        }
        if (rep_selected != nil) {
            format_properties = [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithFloat:0.9], NSImageCompressionFactor,
            NSTIFFCompressionLZW,NSImageCompressionMethod,nil];
            data = [rep_selected representationUsingType:format_type properties:format_properties];
						unsigned char md5_dat[16];
						char md5_hex[33];
						CC_MD5([data bytes], [data length], md5_dat);
						snprintf(md5_hex,33,"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
							md5_dat[0], md5_dat[1], md5_dat[2], md5_dat[3], md5_dat[4], md5_dat[5], md5_dat[6], md5_dat[7],
        			md5_dat[8], md5_dat[9], md5_dat[10], md5_dat[11], md5_dat[12], md5_dat[13], md5_dat[14], md5_dat[15]);
        		name = rb_str_new2(md5_hex);
        		rb_str_cat2(name,".");
        		rb_str_append(name,rb_funcall(ID2SYM(format_id), rb_intern("to_s"), 0));
            result = rb_str_new([data bytes], [data length]);
            [rep_selected release];
        }
    }

    [pool drain];
    VALUE array = rb_ary_new();
    rb_ary_push(array, name);
    rb_ary_push(array, result);
    return array;
}
EOF
    end

  end
end

Liquid::Template.register_tag('attachment', Jekyll::AttachmentTag)
