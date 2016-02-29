JekyllAttachmentTag
====================

Jekyll plugin to display information about attached files through an "attachment" Liquid tag. File icons are created though the OS X AppKit framework. As such, this Jekyll plugin **requires** Mac OS X.

Installation
--------------------

0. Install the [RubyInline] and [filesize] gems.
1. Drop `attachment.rb` into your Jekyll site's `_plugins` folder.
2. Drop `attachment.css` into your Jekyll site's `css` folder and add this line to your `_includes/head.html` file:

``` html
<link rel="stylesheet" href="{{ "/css/attachment.css" | prepend: site.baseurl }}">
```

Usage
--------------------

Jekyll will display information about attached files that are specified in an "attachment" Liquid tag like this:

```
{% attachment /files/brianwells.gpgkey  name: GPG Public Key  modified_date: 2008-08-16 %}Use to encrypt messages to me and verify messages from me via [GnuPG](https://www.gnupg.org). Signature: **D568 D159 B366 0F2F D3F2 74A5 B9D3 E316 6D4A A765**{% endattachment %}
```

The first parameter passed to the "attachment" tag is the file path (relative to your Jekyll directory). A number of optional parameters may be passed as `parameter: some value`. Note a space is required after the parameter name and colon but spaces are allowed within the value.

* `name` — The name to display for the file. Defaults to the actual file name.
* `modified_date` — The date to display. Defaults to the file's modified date.
* `size` — The size, in bytes, to display. Defaults to the file's actual size.
* `icon_size` — The size, in pixels, for the icon image. Defaults to 64 pixels.
* `icon_format` — The format of the icon image. Defaults to the 'png' format.
* `image_path` - Image to use for the icon. Overrides `file_type` and the type determined from the file's extension.
* `file_type` - Override the file type determined from the file's extension.
* `whiny` - Debug information displays if set to true.
 
Valid icon formats include gif, jpg, jp2, png, and tif. The file description goes in between the attachment/endattachment tags and is converted along with the rest of the page.

You can see an example of this Jekyll plugin in use on the [Files](http://www.briandwells.com/main/Files.html) page of my blog.
