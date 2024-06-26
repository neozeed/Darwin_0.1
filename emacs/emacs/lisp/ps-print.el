;;; ps-print.el --- Print text from the buffer as PostScript

;; Copyright (C) 1993, 1994, 1995, 1996, 1997 Free Software Foundation, Inc.

;; Author:     Jim Thompson (was <thompson@wg2.waii.com>)
;; Author:     Jacques Duthen <duthen@cegelec-red.fr>
;; Maintainer: Vinicius Jose Latorre <vinicius@cpqd.br>
;; Keywords:   print, PostScript
;; Time-stamp: <97/08/27 13:00:37 vinicius>
;; Version:    3.05.1

(defconst ps-print-version "3.05.1"
  "ps-print.el, v 3.05.1 <97/08/24 vinicius>

Vinicius's last change version -- this file may have been edited as part of
Emacs without changes to the version number.  When reporting bugs,
please also report the version of Emacs, if any, that ps-print was
distributed with.

Please send all bug fixes and enhancements to
	Jacques Duthen <duthen@cegelec-red.fr>.
")

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; About ps-print
;; --------------
;;
;; This package provides printing of Emacs buffers on PostScript
;; printers; the buffer's bold and italic text attributes are
;; preserved in the printer output.  Ps-print is intended for use with
;; Emacs 19 or Lucid Emacs, together with a fontifying package such as
;; font-lock or hilit.
;;
;; ps-print uses the same face attributes defined through font-lock or hilit
;; to print a PostScript file, but some faces are better seeing on the screen
;; than on paper, specially when you have a black/white PostScript printer.
;;
;; ps-print allows a remap of face to another one that it is better to print,
;; for example, the face font-lock-comment-face (if you are using font-lock)
;; could have bold or italic attribute when printing, besides foreground color.
;; This remap improves printing look (see How Ps-Print Maps Faces).
;;
;;
;; Using ps-print
;; --------------
;;
;; The Commands
;;
;; Ps-print provides eight commands for generating PostScript images
;; of Emacs buffers:
;;
;;        ps-print-buffer
;;        ps-print-buffer-with-faces
;;        ps-print-region
;;        ps-print-region-with-faces
;;        ps-spool-buffer
;;        ps-spool-buffer-with-faces
;;        ps-spool-region
;;        ps-spool-region-with-faces
;;
;; These commands all perform essentially the same function: they
;; generate PostScript images suitable for printing on a PostScript
;; printer or displaying with GhostScript.  These commands are
;; collectively referred to as "ps-print- commands".
;;
;; The word "print" or "spool" in the command name determines when the
;; PostScript image is sent to the printer:
;;
;;        print      - The PostScript image is immediately sent to the
;;                     printer;
;;
;;        spool      - The PostScript image is saved temporarily in an
;;                     Emacs buffer.  Many images may be spooled locally
;;                     before printing them.  To send the spooled images
;;                     to the printer, use the command `ps-despool'.
;;
;; The spooling mechanism was designed for printing lots of small
;; files (mail messages or netnews articles) to save paper that would
;; otherwise be wasted on banner pages, and to make it easier to find
;; your output at the printer (it's easier to pick up one 50-page
;; printout than to find 50 single-page printouts).
;;
;; Ps-print has a hook in the `kill-emacs-hooks' so that you won't
;; accidentally quit from Emacs while you have unprinted PostScript
;; waiting in the spool buffer.  If you do attempt to exit with
;; spooled PostScript, you'll be asked if you want to print it, and if
;; you decline, you'll be asked to confirm the exit; this is modeled
;; on the confirmation that Emacs uses for modified buffers.
;;
;; The word "buffer" or "region" in the command name determines how
;; much of the buffer is printed:
;;
;;        buffer     - Print the entire buffer.
;;
;;        region     - Print just the current region.
;;
;; The -with-faces suffix on the command name means that the command
;; will include font, color, and underline information in the
;; PostScript image, so the printed image can look as pretty as the
;; buffer.  The ps-print- commands without the -with-faces suffix
;; don't include font, color, or underline information; images printed
;; with these commands aren't as pretty, but are faster to generate.
;;
;; Two ps-print- command examples:
;;
;;        ps-print-buffer             - print the entire buffer,
;;                                      without font, color, or
;;                                      underline information, and
;;                                      send it immediately to the
;;                                      printer.
;;
;;        ps-spool-region-with-faces  - print just the current region;
;;                                      include font, color, and
;;                                      underline information, and
;;                                      spool the image in Emacs to
;;                                      send to the printer later.
;;
;;
;; Invoking Ps-Print
;; -----------------
;;
;; To print your buffer, type
;;
;;        M-x ps-print-buffer
;;
;; or substitute one of the other seven ps-print- commands.  The
;; command will generate the PostScript image and print or spool it as
;; specified.  By giving the command a prefix argument
;;
;;        C-u M-x ps-print-buffer
;;
;; it will save the PostScript image to a file instead of sending it
;; to the printer; you will be prompted for the name of the file to
;; save the image to.  The prefix argument is ignored by the commands
;; that spool their images, but you may save the spooled images to a
;; file by giving a prefix argument to `ps-despool':
;;
;;        C-u M-x ps-despool
;;
;; When invoked this way, `ps-despool' will prompt you for the name of
;; the file to save to.
;;
;; Any of the `ps-print-' commands can be bound to keys; I recommend
;; binding `ps-spool-buffer-with-faces', `ps-spool-region-with-faces',
;; and `ps-despool'.  Here are the bindings I use on my Sun 4 keyboard:
;;
;;   (global-set-key 'f22 'ps-spool-buffer-with-faces) ;f22 is prsc
;;   (global-set-key '(shift f22) 'ps-spool-region-with-faces)
;;   (global-set-key '(control f22) 'ps-despool)
;;
;;
;; The Printer Interface
;; ---------------------
;;
;; The variables `ps-lpr-command' and `ps-lpr-switches' determine what
;; command is used to send the PostScript images to the printer, and
;; what arguments to give the command.  These are analogous to
;; `lpr-command' and `lpr-switches'.
;;
;; Make sure that they contain appropriate values for your system;
;; see the usage notes below and the documentation of these variables.
;;
;; NOTE: `ps-lpr-command' and `ps-lpr-switches' take their initial values
;;       from the variables `lpr-command' and `lpr-switches'.  If you have
;;       `lpr-command' set to invoke a pretty-printer such as `enscript',
;;       then ps-print won't work properly.  `ps-lpr-command' must name
;;       a program that does not format the files it prints.
;;
;;
;; The Page Layout
;; ---------------
;;
;; All dimensions are floats in PostScript points.
;; 1 inch  ==       2.54  cm    ==     72       points
;; 1 cm    ==  (/ 1 2.54) inch  ==  (/ 72 2.54) points
;;
;; The variable `ps-paper-type' determines the size of paper ps-print
;; formats for; it should contain one of the symbols:
;; `a4' `a3' `letter' `legal' `letter-small' `tabloid'
;; `ledger' `statement' `executive' `a4small' `b4' `b5'
;;
;; The variable `ps-landscape-mode' determines the orientation
;; of the printing on the page:
;; nil means `portrait' mode, non-nil means `landscape' mode.
;; There is no oblique mode yet, though this is easy to do in ps.
;;
;; In landscape mode, the text is NOT scaled: you may print 70 lines
;; in portrait mode and only 50 lignes in landscape mode.
;; The margins represent margins in the printed paper:
;; the top margin is the margin between the top of the page
;; and the printed header, whatever the orientation is.
;;
;; The variable `ps-number-of-columns' determines the number of columns
;; both in landscape and portrait mode.
;; You can use:
;; - (the standard) one column portrait mode
;; - (my favorite) two columns landscape mode (which spares trees)
;; but also
;; - one column landscape mode for files with very long lines.
;; - multi-column portrait or landscape mode
;;
;;
;; Horizontal layout
;; -----------------
;;
;; The horizontal layout is determined by the variables
;; `ps-left-margin' `ps-inter-column' `ps-right-margin'
;; as follows:
;;
;;  ------------------------------------------
;;  |    |      |    |      |    |      |    |
;;  | lm | text | ic | text | ic | text | rm |
;;  |    |      |    |      |    |      |    |
;;  ------------------------------------------
;;
;; If `ps-number-of-columns' is 1, `ps-inter-column' is not relevant.
;; Usually, lm = rm > 0 and ic = lm
;; If (ic < 0), the text of adjacent columns can overlap.
;;
;;
;; Vertical layout
;; ---------------
;;
;; The vertical layout is determined by the variables
;; `ps-bottom-margin' `ps-top-margin' `ps-header-offset'
;; as follows:
;;
;; |--------|        |--------|
;; | tm     |        | tm     |
;; |--------|        |--------|
;; | header |        |        |
;; |--------|        |        |
;; | ho     |        |        |
;; |--------|   or   | text   |
;; |        |        |        |
;; | text   |        |        |
;; |        |        |        |
;; |--------|        |--------|
;; | bm     |        | bm     |
;; |--------|        |--------|
;;
;; If `ps-print-header' is nil, `ps-header-offset' is not relevant.
;; The margins represent margins in the printed paper:
;; the top margin is the margin between the top of the page
;; and the printed header, whatever the orientation is.
;;
;;
;; Headers
;; -------
;;
;; Ps-print can print headers at the top of each column; the default
;; headers contain the following four items: on the left, the name of
;; the buffer and, if the buffer is visiting a file, the file's
;; directory; on the right, the page number and date of printing.
;; The default headers look something like this:
;;
;;     ps-print.el                                         1/21
;;     /home/jct/emacs-lisp/ps/new                     94/12/31
;;
;; When printing on duplex printers, left and right are reversed so
;; that the page numbers are toward the outside (cf. `ps-spool-duplex').
;;
;; Headers are configurable:
;; To turn them off completely, set `ps-print-header' to nil.
;; To turn off the header's gaudy framing box,
;; set `ps-print-header-frame' to nil.
;;
;; The font family and size of text in the header are determined
;; by the variables `ps-header-font-family', `ps-header-font-size' and
;; `ps-header-title-font-size' (see below).
;;
;; The variable `ps-header-line-pad' determines the portion of a header
;; title line height to insert between the header frame and the text
;; it contains, both in the vertical and horizontal directions:
;; .5 means half a line.

;; Page numbers are printed in `n/m' format, indicating page n of m pages;
;; to omit the total page count and just print the page number,
;; set `ps-show-n-of-n' to nil.
;;
;; The amount of information in the header can be changed by changing
;; the number of lines.  To show less, set `ps-header-lines' to 1, and
;; the header will show only the buffer name and page number.  To show
;; more, set `ps-header-lines' to 3, and the header will show the time of
;; printing below the date.
;;
;; To change the content of the headers, change the variables
;; `ps-left-header' and `ps-right-header'.
;; These variables are lists, specifying top-to-bottom the text
;; to display on the left or right side of the header.
;; Each element of the list should be a string or a symbol.
;; Strings are inserted directly into the PostScript arrays,
;; and should contain the PostScript string delimiters '(' and ')'.
;;
;; Symbols in the header format lists can either represent functions
;; or variables.  Functions are called, and should return a string to
;; show in the header.  Variables should contain strings to display in
;; the header.  In either case, function or variable, the PostScript
;; string delimiters are added by ps-print, and should not be part of
;; the returned value.
;;
;; Here's an example: say we want the left header to display the text
;;
;;     Moe
;;     Larry
;;     Curly
;;
;; where we have a function to return "Moe"
;;
;;     (defun moe-func ()
;;       "Moe")
;;
;; a variable specifying "Larry"
;;
;;     (setq larry-var "Larry")
;;
;; and a literal for "Curly".  Here's how `ps-left-header' should be
;; set:
;;
;;     (setq ps-left-header (list 'moe-func 'larry-var "(Curly)"))
;;
;; Note that Curly has the PostScript string delimiters inside his
;; quotes -- those aren't misplaced lisp delimiters!
;;
;; Without them, PostScript would attempt to call the undefined
;; function Curly, which would result in a PostScript error.
;;
;; Since most printers don't report PostScript errors except by
;; aborting the print job, this kind of error can be hard to track down.
;;
;; Consider yourself warned!
;;
;;
;; Duplex Printers
;; ---------------
;;
;; If you have a duplex-capable printer (one that prints both sides of
;; the paper), set `ps-spool-duplex' to t.
;; Ps-print will insert blank pages to make sure each buffer starts
;; on the correct side of the paper.
;; Don't forget to set `ps-lpr-switches' to select duplex printing
;; for your printer.
;;
;;
;; Line Number
;; -----------
;;
;; The variable `ps-line-number' specifies whether to number each line;
;; non-nil means do so.  The default is nil (don't number each line).
;;
;;
;; Zebra Stripes
;; -------------
;;
;; Zebra stripes are a kind of background that appear "underneath" the text
;; and can make the text easier to read.  They look like this:
;;
;; XXXXXXXXXXXXXXXXXXXXXXXX
;; XXXXXXXXXXXXXXXXXXXXXXXX
;; XXXXXXXXXXXXXXXXXXXXXXXX
;;
;;
;;
;; XXXXXXXXXXXXXXXXXXXXXXXX
;; XXXXXXXXXXXXXXXXXXXXXXXX
;; XXXXXXXXXXXXXXXXXXXXXXXX
;;
;; The blocks of X's represent rectangles filled with a light gray color.
;; Each rectangle extends all the way across the page.
;;
;; The height, in lines, of each rectangle is controlled by
;; the variable `ps-zebra-stripe-height', which is 3 by default.
;; The distance between stripes equals the height of a stripe.
;; 
;; The variable `ps-zebra-stripes' controls whether to print zebra stripes.
;; Non-nil means yes, nil means no.  The default is nil.
;;
;; See also section How Ps-Print Has A Text And/Or Image On Background.
;;
;;
;; Font managing
;; -------------
;;
;; Ps-print now knows rather precisely some fonts:
;; the variable `ps-font-info-database' contains information
;; for a list of font families (currently mainly `Courier' `Helvetica'
;; `Times' `Palatino' `Helvetica-Narrow' `NewCenturySchlbk').
;; Each font family contains the font names for standard, bold, italic
;; and bold-italic characters, a reference size (usually 10) and the
;; corresponding line height, width of a space and average character width.
;;
;; The variable `ps-font-family' determines which font family
;; is to be used for ordinary text.
;; If its value does not correspond to a known font family,
;; an error message is printed into the `*Messages*' buffer,
;; which lists the currently available font families.
;;
;; The variable `ps-font-size' determines the size (in points)
;; of the font for ordinary text, when generating Postscript.
;; Its value is a float.
;;
;; Similarly, the variable `ps-header-font-family' determines
;; which font family is to be used for text in the header.
;; The variable `ps-header-font-size' determines the font size,
;; in points, for text in the header.
;; The variable `ps-header-title-font-size' determines the font size,
;; in points, for the top line of text in the header.
;;
;;
;; Adding a new font family
;; ------------------------
;;
;; To use a new font family, you MUST first teach ps-print
;; this font, i.e., add its information to `ps-font-info-database',
;; otherwise ps-print cannot correctly place line and page breaks.
;;
;; For example, assuming `Helvetica' is unknown,
;; you first need to do the following ONLY ONCE:
;;
;; - create a new buffer
;; - generate the PostScript image to a file (C-u M-x ps-print-buffer)
;; - open this file and find the line:
;;	`% 3 cm 20 cm moveto  10 /Courier ReportFontInfo  showpage'
;; - delete the leading `%' (which is the PostScript comment character)
;; - replace in this line `Courier' by the new font (say `Helvetica')
;;   to get the line:
;;	`3 cm 20 cm moveto  10 /Helvetica ReportFontInfo  showpage'
;; - send this file to the printer (or to ghostscript).
;;   You should read the following on the output page:
;;
;;     For Helvetica 10 point, the line height is 11.56, the space width is 2.78
;;     and a crude estimate of average character width is 5.09243
;;
;; - Add these values to the `ps-font-info-database':
;;   (setq ps-font-info-database
;;	 (append
;;	  '((Helvetica ; the family name
;;	    "Helvetica" "Helvetica-Bold" "Helvetica-Oblique" "Helvetica-BoldOblique"
;;	    10.0 11.56 2.78 5.09243))
;;	  ps-font-info-database))
;; - Now you can use this font family with any size:
;;	(setq ps-font-family 'Helvetica)
;; - if you want to use this family in another emacs session, you must
;;   put into your `~/.emacs':
;;	(require 'ps-print)
;;	(setq ps-font-info-database (append ...)))
;;   if you don't want to load ps-print, you have to copy the whole value:
;;	(setq ps-font-info-database '(<your stuff> <the standard stuff>))
;;   or, if you can wait until the `ps-print-hook' is implemented, do:
;;      (add-hook 'ps-print-hook '(setq ps-font-info-database (append ...)))
;;      This does not work yet, since there is no `ps-print-hook' yet.
;;
;; You can create new `mixed' font families like:
;;	(my-mixed-family
;;	 "Courier-Bold" "Helvetica"
;;	 "Zapf-Chancery-MediumItalic" "NewCenturySchlbk-BoldItalic"
;;	 10.0 10.55 6.0 6.0)
;; Now you can use your new font family with any size:
;;	(setq ps-font-family 'my-mixed-family)
;;
;; You can get information on all the fonts resident in YOUR printer
;; by uncommenting the line:
;;	% 3 cm 20 cm moveto  ReportAllFontInfo           showpage
;;
;; The PostScript file should be sent to YOUR PostScript printer.
;; If you send it to ghostscript or to another PostScript printer,
;; you may get slightly different results.
;; Anyway, as ghostscript fonts are autoload, you won't get
;; much font info.
;;
;;
;; How Ps-Print Deals With Faces
;; -----------------------------
;;
;; The ps-print-*-with-faces commands attempt to determine which faces
;; should be printed in bold or italic, but their guesses aren't
;; always right.  For example, you might want to map colors into faces
;; so that blue faces print in bold, and red faces in italic.
;;
;; It is possible to force ps-print to consider specific faces bold or
;; italic, no matter what font they are displayed in, by setting the
;; variables `ps-bold-faces' and `ps-italic-faces'.  These variables
;; contain lists of faces that ps-print should consider bold or
;; italic; to set them, put code like the following into your .emacs
;; file:
;;
;; 	(setq ps-bold-faces '(my-blue-face))
;;      (setq ps-italic-faces '(my-red-face))
;;
;; Faces like bold-italic that are both bold and italic should go in
;; *both* lists.
;;
;; Ps-print keeps internal lists of which fonts are bold and which are
;; italic; these lists are built the first time you invoke ps-print.
;; For the sake of efficiency, the lists are built only once; the same
;; lists are referred in later invocations of ps-print.
;;
;; Because these lists are built only once, it's possible for them to
;; get out of sync, if a face changes, or if new faces are added.  To
;; get the lists back in sync, you can set the variable
;; `ps-build-face-reference' to t, and the lists will be rebuilt the
;; next time ps-print is invoked.
;;
;;
;; How Ps-Print Deals With Color
;; -----------------------------
;;
;; Ps-print detects faces with foreground and background colors
;; defined and embeds color information in the PostScript image.
;; The default foreground and background colors are defined by the
;; variables `ps-default-fg' and `ps-default-bg'.
;; On black-and-white printers, colors are displayed in grayscale.
;; To turn off color output, set `ps-print-color-p' to nil.
;;
;;
;; How Ps-Print Maps Faces
;; -----------------------
;;
;; As ps-print uses PostScript to print buffers, it is possible to have
;; other attributes associated with faces. So the new attributes used
;; by ps-print are:
;;
;;   strikeout - like underline, but the line is in middle of text.
;;   overline  - like underline, but the line is over the text.
;;   shadow    - text will have a shadow.
;;   box       - text will be surrounded by a box.
;;   outline   - print characters as hollow outlines.
;;
;; See the documentation for `ps-extend-face'.
;;
;; Let's, for example, remap font-lock-keyword-face to another foreground color
;; and bold attribute:
;;
;;    (ps-extend-face '(font-lock-keyword-face "RoyalBlue" nil bold) 'MERGE)
;;
;; If you want to use a new face, define it first with `defface',
;; and then call `ps-extend-face' to specify how to print it.
;;
;;
;; How Ps-Print Has A Text And/Or Image On Background
;; --------------------------------------------------
;;
;; Ps-print can print texts and/or EPS PostScript images on background; it is
;; possible to define the following text attributes: font name, font size,
;; initial position, angle, gray scale and pages to print.
;;
;; It has the following EPS PostScript images attributes: file name containing
;; the image, initial position, X and Y scales, angle and pages to print.
;;
;; See documentation for `ps-print-background-text' and
;; `ps-print-background-image'.
;;
;; For example, if we wish to print text "preliminary" on all pages and text
;; "special" on page 5 and from page 11 to page 17, we could specify:
;;
;; (setq ps-print-background-text
;;       '(("preliminary")
;;         ("special"
;;          "LeftMargin" "BottomMargin PrintHeight add" ; X and Y position
;;                                      ; (upper left corner)
;;          nil nil nil
;;          "PrintHeight neg PrintWidth atan" ; angle
;;          5 (11 . 17))                ; page list
;;         ))
;;
;; Similarly, we could print image "~/images/EPS-image1.ps" on all pages and
;; image "~/images/EPS-image2.ps" on page 5 and from page 11 to page 17, we
;; specify:
;;
;; (setq ps-print-background-image
;;       '(("~/images/EPS-image1.ps"
;;          "LeftMargin" "BottomMargin") ; X and Y position (lower left corner)
;;         ("~/images/EPS-image2.ps"
;;          "LeftMargin" "BottomMargin PrintHeight 2 div add" ; X and Y position
;;                                      ; (upper left corner)
;;          nil nil nil
;;          5 (11 . 17))                ; page list
;;         ))
;;
;; If it is not possible to read (or does not exist) an image file, that file
;; is ignored.
;;
;; The printing order is:
;;
;;    1. Print zebra stripes
;;    2. Print background texts that it should be on all pages
;;    3. Print background images that it should be on all pages
;;    4. Print background texts only for current page (if any)
;;    5. Print background images only for current page (if any)
;;    6. Print header
;;    7. Print buffer text (with faces, if specified) and line number
;;
;;
;; Utilities
;; ---------
;;
;; Some tools are provided to help you customize your font setup.
;;
;; `ps-setup' returns (some part of) the current setup.
;;
;; To avoid wrapping too many lines, you may want to adjust the
;; left and right margins and the font size.  On UN*X systems, do:
;; pr -t file | awk '{printf "%3d %s\n", length($0), $0}' | sort -r | head
;; to determine the longest lines of your file.
;; Then, the command `ps-line-lengths' will give you the correspondence
;; between a line length (number of characters) and the maximum font
;; size which doesn't wrap such a line with the current ps-print setup.
;;
;; The commands `ps-nb-pages-buffer' and `ps-nb-pages-region' display
;; the correspondence between a number of pages and the maximum font
;; size which allow the number of lines of the current buffer or of
;; its current region to fit in this number of pages.
;;
;; NOTE: line folding is not taken into account in this process and could
;;       change the results.
;;
;;
;; New since version 1.5
;; ---------------------
;;
;; Color output capability.
;; Automatic detection of font attributes (bold, italic).
;; Configurable headers with page numbers.
;; Slightly faster.
;; Support for different paper sizes.
;; Better conformance to PostScript Document Structure Conventions.
;;
;;
;; New since version 2.8
;; ---------------------
;;
;; [vinicius] 970809 Vinicius Jose Latorre <vinicius@cpqd.br>
;;
;; Handle control characters.
;; Face remapping.
;; New face attributes.
;; Line number.
;; Zebra stripes.
;; Text and/or image on background.
;;
;; [jack] 960517 Jacques Duthen <duthen@cegelec-red.fr>
;;
;; Font family and float size for text and header.
;; Landscape mode.
;; Multiple columns.
;; Tools for page setup.
;;
;;
;; Known bugs and limitations of ps-print:
;; --------------------------------------
;;
;; Although color printing will work in XEmacs 19.12, it doesn't work
;; well; in particular, bold or italic fonts don't print in the right
;; background color.
;;
;; Invisible properties aren't correctly ignored in XEmacs 19.12.
;;
;; Automatic font-attribute detection doesn't work well, especially
;; with hilit19 and older versions of get-create-face.  Users having
;; problems with auto-font detection should use the lists
;; `ps-italic-faces' and `ps-bold-faces' and/or turn off automatic
;; detection by setting `ps-auto-font-detect' to nil.
;;
;; Automatic font-attribute detection doesn't work with XEmacs 19.12
;; in tty mode; use the lists `ps-italic-faces' and `ps-bold-faces'
;; instead.
;;
;; Still too slow; could use some hand-optimization.
;;
;; Default background color isn't working.
;;
;; Faces are always treated as opaque.
;;
;; Epoch and Emacs 18 not supported.  At all.
;;
;; Fixed-pitch fonts work better for line folding, but are not required.
;;
;; `ps-nb-pages-buffer' and `ps-nb-pages-region' don't take care
;; of folding lines.
;;
;;
;; Things to change:
;; ----------------
;;
;; Add `ps-print-hook' (I don't know how to do that (yet!)).
;; Add 4-up capability (really needed?).
;; Add `ps-non-bold-faces' and `ps-non-italic-faces' (should be easy).
;; Put one header per page over the columns (easy but needed?).
;; Improve the memory management for big files (hard?).
;; `ps-nb-pages-buffer' and `ps-nb-pages-region' should take care
;; of folding lines.
;;
;;
;; Acknowledgements
;; ----------------
;; Thanks to Jim Thompson <?@?> for the 2.8 version I started from.
;; [jack]
;;
;; Thanks to Kevin Rodgers <kevinr@ihs.com> for adding support for
;; color and the invisible property.
;;
;; Thanks to Avishai Yacobi, avishaiy@mcil.comm.mot.com, for writing
;; the initial port to Emacs 19.  His code is no longer part of
;; ps-print, but his work is still appreciated.
;;
;; Thanks to Remi Houdaille and Michel Train, michel@metasoft.fdn.org,
;; for adding underline support.  Their code also is no longer part of
;; ps-print, but their efforts are not forgotten.
;;
;; Thanks also to all of you who mailed code to add features to
;; ps-print; although I didn't use your code, I still appreciate your
;; sharing it with me.
;;
;; Thanks to all who mailed comments, encouragement, and criticism.
;; Thanks also to all who responded to my survey; I had too many
;; responses to reply to them all, but I greatly appreciate your
;; interest.
;;
;; Jim
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Code:

(eval-when-compile
  (require 'cl))

(unless (featurep 'lisp-float-type)
  (error "`ps-print' requires floating point support"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; User Variables:

;;; Interface to the command system

(defgroup ps-print nil
  "Postscript generator for Emacs 19"
  :prefix "ps-"
  :group 'wp)

(defgroup ps-print-horizontal nil
  "Horizontal page layout"
  :prefix "ps-"
  :tag "Horizontal"
  :group 'ps-print)

(defgroup ps-print-vertical nil
  "Vertical page layout"
  :prefix "ps-"
  :tag "Vertical"
  :group 'ps-print)

(defgroup ps-print-header nil
  "Headers layout"
  :prefix "ps-"
  :tag "Header"
  :group 'ps-print)

(defgroup ps-print-font nil
  "Fonts customization"
  :prefix "ps-"
  :tag "Font"
  :group 'ps-print)

(defgroup ps-print-color nil
  "Color customization"
  :prefix "ps-"
  :tag "Color"
  :group 'ps-print)

(defgroup ps-print-face nil
  "Faces customization"
  :prefix "ps-"
  :tag "PS Faces"
  :group 'ps-print
  :group 'faces)


(defcustom ps-lpr-command lpr-command
  "*The shell command for printing a PostScript file."
  :type 'string
  :group 'ps-print)

(defcustom ps-lpr-switches lpr-switches
  "*A list of extra switches to pass to `ps-lpr-command'."
  :type '(repeat string)
  :group 'ps-print)

;;; Page layout

;; All page dimensions are in PostScript points.
;; 1 inch  ==       2.54  cm    ==     72       points
;; 1 cm    ==  (/ 1 2.54) inch  ==  (/ 72 2.54) points

;; Letter      8.5   inch x 11.0   inch
;; Legal       8.5   inch x 14.0   inch
;; A4          8.26  inch x 11.69  inch = 21.0 cm x 29.7 cm

;; LetterSmall 7.68  inch x 10.16  inch
;; Tabloid    11.0   inch x 17.0   inch
;; Ledger     17.0   inch x 11.0   inch
;; Statement   5.5   inch x  8.5   inch
;; Executive   7.5   inch x 10.0   inch
;; A3         11.69  inch x 16.5   inch = 29.7 cm x 42.0 cm
;; A4Small     7.47  inch x 10.85  inch
;; B4         10.125 inch x 14.33  inch
;; B5          7.16  inch x 10.125 inch

(defcustom ps-page-dimensions-database
  (list (list 'a4    (/ (* 72 21.0) 2.54) (/ (* 72 29.7) 2.54))
	(list 'a3    (/ (* 72 29.7) 2.54) (/ (* 72 42.0) 2.54))
	(list 'letter       (* 72  8.5)   (* 72 11.0))
	(list 'legal        (* 72  8.5)   (* 72 14.0))
	(list 'letter-small (* 72  7.68)  (* 72 10.16))
	(list 'tabloid      (* 72 11.0)   (* 72 17.0))
	(list 'ledger       (* 72 17.0)   (* 72 11.0))
	(list 'statement    (* 72  5.5)   (* 72  8.5))
	(list 'executive    (* 72  7.5)   (* 72 10.0))
	(list 'a4small      (* 72  7.47)  (* 72 10.85))
	(list 'b4           (* 72 10.125) (* 72 14.33))
	(list 'b5           (* 72  7.16)  (* 72 10.125)))
  "*List associating a symbolic paper type to its width and height.
see `ps-paper-type'."
  :type '(repeat (list :tag "Paper Type"
		       (symbol :tag "Name")
		       (number :tag "Width")
		       (number :tag "Height")))
  :group 'ps-print)

(defcustom ps-paper-type 'letter
  "*Specifies the size of paper to format for.
Should be one of the paper types defined in `ps-page-dimensions-database', for
example `letter', `legal' or `a4'."
  :type '(symbol :validate (lambda (wid)
			     (if (assq (widget-value wid)
				       ps-page-dimensions-database)
				 nil
			       (widget-put wid :error "Unknown paper size")
			       wid)))
  :group 'ps-print)

(defcustom ps-landscape-mode nil
  "*Non-nil means print in landscape mode."
  :type 'boolean
  :group 'ps-print)

(defcustom ps-number-of-columns (if ps-landscape-mode 2 1)
  "*Specifies the number of columns"
  :type 'number
  :group 'ps-print)

(defcustom ps-zebra-stripes nil
  "*Non-nil means print zebra stripes.
See also documentation for `ps-zebra-stripe-height'."
  :type 'boolean
  :group 'ps-print)

(defcustom ps-zebra-stripe-height 3
  "*Number of zebra stripe lines.
See also documentation for `ps-zebra-stripes'."
  :type 'number
  :group 'ps-print)

(defcustom ps-line-number nil
  "*Non-nil means print line number."
  :type 'boolean
  :group 'ps-print)

(defcustom ps-print-background-image nil
  "*EPS image list to be printed on background.

The elements are:

   (FILENAME X Y XSCALE YSCALE ROTATION PAGES...)

FILENAME is a file name which contains an EPS image or some PostScript
programming like EPS.
FILENAME is ignored, if it doesn't exist or is read protected.

X and Y are relative positions on paper to put the image.
If X and Y are nil, the image is centralized on paper.

XSCALE and YSCALE are scale factor to be applied to image before printing.
If XSCALE and YSCALE are nil, the original size is used.

ROTATION is the image rotation angle; if nil, the default is 0.

PAGES designates the page to print background image.
PAGES may be a number or a cons cell (FROM . TO) designating FROM page
to TO page.
If PAGES is nil, print background image on all pages.

X, Y, XSCALE, YSCALE and ROTATION may be a floating point number,
an integer number or a string. If it is a string, the string should contain
PostScript programming that returns a float or integer value.

For example, if you wish to print an EPS image on all pages do:

   '((\"~/images/EPS-image.ps\"))"
  :type 'list
  :group 'ps-print)

(defcustom ps-print-background-text nil
  "*Text list to be printed on background.

The elements are:

   (STRING X Y FONT FONTSIZE GRAY ROTATION PAGES...)

STRING is the text to be printed on background.

X and Y are positions on paper to put the text.
If X and Y are nil, the text is positioned at lower left corner.

FONT is a font name to be used on printing the text.
If nil, \"Times-Roman\" is used.

FONTSIZE is font size to be used, if nil, 200 is used.

GRAY is the text gray factor (should be very light like 0.8).
If nil, the default is 0.85.

ROTATION is the text rotation angle; if nil, the angle is given by
the diagonal from lower left corner to upper right corner.

PAGES designates the page to print background text.
PAGES may be a number or a cons cell (FROM . TO) designating FROM page
to TO page.
If PAGES is nil, print background text on all pages.

X, Y, FONTSIZE, GRAY and ROTATION may be a floating point number,
an integer number or a string. If it is a string, the string should contain
PostScript programming that returns a float or integer value.

For example, if you wish to print text \"Preliminary\" on all pages do:

   '((\"Preliminary\"))"
  :type 'list
  :group 'ps-print)

;;; Horizontal layout

;;  ------------------------------------------
;;  |    |      |    |      |    |      |    |
;;  | lm | text | ic | text | ic | text | rm |
;;  |    |      |    |      |    |      |    |
;;  ------------------------------------------

(defcustom ps-left-margin   (/ (* 72  2.0) 2.54) ;   2 cm
  "*Left margin in points (1/72 inch)."
  :type 'number
  :group 'ps-print-horizontal)

(defcustom ps-right-margin  (/ (* 72  2.0) 2.54) ;   2 cm
  "*Right margin in points (1/72 inch)."
  :type 'number
  :group 'ps-print-horizontal)

(defcustom ps-inter-column  (/ (* 72  2.0) 2.54) ;   2 cm
  "*Horizontal space between columns in points (1/72 inch)."
  :type 'number
  :group 'ps-print-horizontal)

;;; Vertical layout

;; |--------|
;; | tm     |
;; |--------|
;; | header |
;; |--------|
;; | ho     |
;; |--------|
;; | text   |
;; |--------|
;; | bm     |
;; |--------|

(defcustom ps-bottom-margin (/ (* 72  1.5) 2.54) ; 1.5 cm
  "*Bottom margin in points (1/72 inch)."
  :type 'number
  :group 'ps-print-vertical)

(defcustom ps-top-margin    (/ (* 72  1.5) 2.54) ; 1.5 cm
  "*Top margin in points (1/72 inch)."
  :type 'number
  :group 'ps-print-vertical)

(defcustom ps-header-offset (/ (* 72  1.0) 2.54) ; 1.0 cm
  "*Vertical space in points (1/72 inch) between the main text and the header."
  :type 'number
  :group 'ps-print-vertical)

(defcustom ps-header-line-pad 0.15
  "*Portion of a header title line height to insert between the header frame
and the text it contains, both in the vertical and horizontal directions."
  :type 'number
  :group 'ps-print-vertical)

;;; Header setup

(defcustom ps-print-header t
  "*Non-nil means print a header at the top of each page.
By default, the header displays the buffer name, page number, and, if
the buffer is visiting a file, the file's directory.  Headers are
customizable by changing variables `ps-left-header' and
`ps-right-header'."
  :type 'boolean
  :group 'ps-print-header)

(defcustom ps-print-header-frame t
  "*Non-nil means draw a gaudy frame around the header."
  :type 'boolean
  :group 'ps-print-header)

(defcustom ps-header-lines 2
  "*Number of lines to display in page header, when generating Postscript."
  :type 'integer
  :group 'ps-print-header)
(make-variable-buffer-local 'ps-header-lines)

(defcustom ps-show-n-of-n t
  "*Non-nil means show page numbers as N/M, meaning page N of M.
Note: page numbers are displayed as part of headers, see variable
`ps-print-headers'."
  :type 'boolean
  :group 'ps-print-header)

(defcustom ps-spool-duplex nil		; Not many people have duplex
					; printers, so default to nil.
  "*Non-nil indicates spooling is for a two-sided printer.
For a duplex printer, the `ps-spool-*' commands will insert blank pages
as needed between print jobs so that the next buffer printed will
start on the right page.  Also, if headers are turned on, the headers
will be reversed on duplex printers so that the page numbers fall to
the left on even-numbered pages."
  :type 'boolean
  :group 'ps-print-header)

;;; Fonts

(defcustom ps-font-info-database
  '((Courier				; the family key
     "Courier" "Courier-Bold" "Courier-Oblique" "Courier-BoldOblique"
     10.0 10.55 6.0     6.0)
    (Helvetica				; the family key
     "Helvetica" "Helvetica-Bold" "Helvetica-Oblique" "Helvetica-BoldOblique"
     10.0 11.56 2.78    5.09243)
    (Times
     "Times-Roman" "Times-Bold" "Times-Italic" "Times-BoldItalic"
     10.0 11.0  2.5     4.71432)
    (Palatino
     "Palatino-Roman" "Palatino-Bold" "Palatino-Italic" "Palatino-BoldItalic"
     10.0 12.1  2.5     5.08676)
    (Helvetica-Narrow
     "Helvetica-Narrow" "Helvetica-Narrow-Bold"
     "Helvetica-Narrow-Oblique" "Helvetica-Narrow-BoldOblique"
     10.0 11.56 2.2796  4.17579)
    (NewCenturySchlbk
     "NewCenturySchlbk-Roman" "NewCenturySchlbk-Bold"
     "NewCenturySchlbk-Italic" "NewCenturySchlbk-BoldItalic"
     10.0 12.15 2.78    5.31162)
    ;; got no bold for the next ones
    (AvantGarde-Book
     "AvantGarde-Book" "AvantGarde-Book"
     "AvantGarde-BookOblique" "AvantGarde-BookOblique"
     10.0 11.77 2.77    5.45189)
    (AvantGarde-Demi
     "AvantGarde-Demi" "AvantGarde-Demi"
     "AvantGarde-DemiOblique" "AvantGarde-DemiOblique"
     10.0 12.72 2.8     5.51351)
    (Bookman-Demi
     "Bookman-Demi" "Bookman-Demi"
     "Bookman-DemiItalic" "Bookman-DemiItalic"
     10.0 11.77 3.4     6.05946)
    (Bookman-Light
     "Bookman-Light" "Bookman-Light"
     "Bookman-LightItalic" "Bookman-LightItalic"
     10.0 11.79 3.2     5.67027)
    ;; got no bold and no italic for the next ones
    (Symbol
     "Symbol" "Symbol" "Symbol" "Symbol"
     10.0 13.03 2.5     3.24324)
    (Zapf-Dingbats
     "Zapf-Dingbats" "Zapf-Dingbats" "Zapf-Dingbats" "Zapf-Dingbats"
     10.0  9.63 2.78    2.78)
    (Zapf-Chancery-MediumItalic
     "Zapf-Chancery-MediumItalic" "Zapf-Chancery-MediumItalic"
     "Zapf-Chancery-MediumItalic" "Zapf-Chancery-MediumItalic"
     10.0 11.45 2.2     4.10811)
    )
  "*Font info database: font family (the key), name, bold, italic, bold-italic,
reference size, line height, space width, average character width.
To get the info for another specific font (say Helvetica), do the following:
- create a new buffer
- generate the PostScript image to a file (C-u M-x ps-print-buffer)
- open this file and delete the leading `%' (which is the Postscript
  comment character) from the line
	   `% 3 cm 20 cm moveto  10 /Courier ReportFontInfo  showpage'
  to get the line
	   `3 cm 20 cm moveto  10 /Helvetica ReportFontInfo  showpage'
- add the values to `ps-font-info-database'.
You can get all the fonts of YOUR printer using `ReportAllFontInfo'."
  :type '(repeat (list :tag "Font Definition"
		       (symbol :tag "Font")
		       (string :tag "Name")
		       (string :tag "Bold")
		       (string :tag "Italic")
		       (string :tag "Bold-Italic")
		       (number :tag "Reference Size")
		       (number :tag "Line Height")
		       (number :tag "Space Width")
		       (number :tag "Average Character Width")))
  :group 'ps-print-font)

(defcustom ps-font-family 'Courier
  "Font family name for ordinary text, when generating Postscript."
  :type 'symbol
  :group 'ps-print-font)

(defcustom ps-font-size   (if ps-landscape-mode 7 8.5)
  "Font size, in points, for ordinary text, when generating Postscript."
  :type 'number
  :group 'ps-print-font)

(defcustom ps-header-font-family      'Helvetica
  "Font family name for text in the header, when generating Postscript."
  :type 'symbol
  :group 'ps-print-font)

(defcustom ps-header-font-size       (if ps-landscape-mode 10 12)
  "Font size, in points, for text in the header, when generating Postscript."
  :type 'number
  :group 'ps-print-font)

(defcustom ps-header-title-font-size (if ps-landscape-mode 12 14)
  "Font size, in points, for the top line of text in the header,
when generating Postscript."
  :type 'number
  :group 'ps-print-font)

;;; Colors

;; Printing color requires x-color-values.
(defcustom ps-print-color-p (or (fboundp 'x-color-values) ; Emacs
				(fboundp 'pixel-components)) ; XEmacs
  "*If non-nil, print the buffer's text in color."
  :type 'boolean
  :group 'ps-print-color)

(defcustom ps-default-fg '(0.0 0.0 0.0)
  "*RGB values of the default foreground color.  Defaults to black."
  :type '(list (number :tag "Red") (number :tag "Green") (number :tag "Blue"))
  :group 'ps-print-color)

(defcustom ps-default-bg '(1.0 1.0 1.0)
  "*RGB values of the default background color.  Defaults to white."
  :type '(list (number :tag "Red") (number :tag "Green") (number :tag "Blue"))
  :group 'ps-print-color)

(defcustom ps-auto-font-detect t
  "*Non-nil means automatically detect bold/italic face attributes.
If nil, we rely solely on the lists `ps-bold-faces', `ps-italic-faces',
and `ps-underlined-faces'."
  :type 'boolean
  :group 'ps-print-font)

(defcustom ps-bold-faces
  (unless ps-print-color-p
    '(font-lock-function-name-face
      font-lock-builtin-face
      font-lock-variable-name-face
      font-lock-keyword-face
      font-lock-warning-face))
  "*A list of the \(non-bold\) faces that should be printed in bold font.
This applies to generating Postscript."
  :type '(repeat face)
  :group 'ps-print-face)

(defcustom ps-italic-faces
  (unless ps-print-color-p
    '(font-lock-variable-name-face
      font-lock-string-face
      font-lock-comment-face
      font-lock-warning-face))
  "*A list of the \(non-italic\) faces that should be printed in italic font.
This applies to generating Postscript."
  :type '(repeat face)
  :group 'ps-print-face)

(defcustom ps-underlined-faces
  (unless ps-print-color-p
    '(font-lock-function-name-face
      font-lock-type-face
      font-lock-reference-face
      font-lock-warning-face))
  "*A list of the \(non-underlined\) faces that should be printed underlined.
This applies to generating Postscript."
  :type '(repeat face)
  :group 'ps-print-face)

(defcustom ps-left-header
  (list 'ps-get-buffer-name 'ps-header-dirpart)
  "*The items to display (each on a line) on the left part of the page header.
This applies to generating Postscript.

The value should be a list of strings and symbols, each representing an
entry in the PostScript array HeaderLinesLeft.

Strings are inserted unchanged into the array; those representing
PostScript string literals should be delimited with PostScript string
delimiters '(' and ')'.

For symbols with bound functions, the function is called and should
return a string to be inserted into the array.  For symbols with bound
values, the value should be a string to be inserted into the array.
In either case, function or variable, the string value has PostScript
string delimiters added to it."
  :type '(repeat (choice string symbol))
  :group 'ps-print-header)
(make-variable-buffer-local 'ps-left-header)

(defcustom ps-right-header
  (list "/pagenumberstring load" 'time-stamp-mon-dd-yyyy 'time-stamp-hh:mm:ss)
  "*The items to display (each on a line) on the right part of the page header.
This applies to generating Postscript.

See the variable `ps-left-header' for a description of the format of
this variable."
  :type '(repeat (choice string symbol))
  :group 'ps-print-header)
(make-variable-buffer-local 'ps-right-header)

(defcustom ps-razzle-dazzle t
  "*Non-nil means report progress while formatting buffer."
  :type 'boolean
  :group 'ps-print)

(defcustom ps-adobe-tag "%!PS-Adobe-3.0\n"
  "*Contains the header line identifying the output as PostScript.
By default, `ps-adobe-tag' contains the standard identifier.  Some
printers require slightly different versions of this line."
  :type 'string
  :group 'ps-print)

(defcustom ps-build-face-reference t
  "*Non-nil means build the reference face lists.

Ps-print sets this value to nil after it builds its internal reference
lists of bold and italic faces.  By settings its value back to t, you
can force ps-print to rebuild the lists the next time you invoke one
of the ...-with-faces commands.

You should set this value back to t after you change the attributes of
any face, or create new faces.  Most users shouldn't have to worry
about its setting, though."
  :type 'boolean
  :group 'ps-print-face)

(defcustom ps-always-build-face-reference nil
  "*Non-nil means always rebuild the reference face lists.

If this variable is non-nil, ps-print will rebuild its internal
reference lists of bold and italic faces *every* time one of the
-with-faces commands is called.  Most users shouldn't need to set this
variable."
  :type 'boolean
  :group 'ps-print-face)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; User commands

;;;###autoload
(defun ps-print-buffer (&optional filename)
  "Generate and print a PostScript image of the buffer.

When called with a numeric prefix argument (C-u), prompts the user for
the name of a file to save the PostScript image in, instead of sending
it to the printer.

More specifically, the FILENAME argument is treated as follows: if it
is nil, send the image to the printer.  If FILENAME is a string, save
the PostScript image in a file with that name.  If FILENAME is a
number, prompt the user for the name of the file to save in."
  (interactive (list (ps-print-preprint current-prefix-arg)))
  (ps-print-without-faces (point-min) (point-max) filename))


;;;###autoload
(defun ps-print-buffer-with-faces (&optional filename)
  "Generate and print a PostScript image of the buffer.
Like `ps-print-buffer', but includes font, color, and underline
information in the generated image.  This command works only if you
are using a window system, so it has a way to determine color values."
  (interactive (list (ps-print-preprint current-prefix-arg)))
  (ps-print-with-faces (point-min) (point-max) filename))


;;;###autoload
(defun ps-print-region (from to &optional filename)
  "Generate and print a PostScript image of the region.
Like `ps-print-buffer', but prints just the current region."
  (interactive (list (point) (mark) (ps-print-preprint current-prefix-arg)))
  (ps-print-without-faces from to filename t))


;;;###autoload
(defun ps-print-region-with-faces (from to &optional filename)
  "Generate and print a PostScript image of the region.
Like `ps-print-region', but includes font, color, and underline
information in the generated image.  This command works only if you
are using a window system, so it has a way to determine color values."
  (interactive (list (point) (mark) (ps-print-preprint current-prefix-arg)))
  (ps-print-with-faces from to filename t))


;;;###autoload
(defun ps-spool-buffer ()
  "Generate and spool a PostScript image of the buffer.
Like `ps-print-buffer' except that the PostScript image is saved in a
local buffer to be sent to the printer later.

Use the command `ps-despool' to send the spooled images to the printer."
  (interactive)
  (ps-spool-without-faces (point-min) (point-max)))


;;;###autoload
(defun ps-spool-buffer-with-faces ()
  "Generate and spool a PostScript image of the buffer.
Like `ps-spool-buffer', but includes font, color, and underline
information in the generated image.  This command works only if you
are using a window system, so it has a way to determine color values.

Use the command `ps-despool' to send the spooled images to the printer."
  (interactive)
  (ps-spool-with-faces (point-min) (point-max)))


;;;###autoload
(defun ps-spool-region (from to)
  "Generate a PostScript image of the region and spool locally.
Like `ps-spool-buffer', but spools just the current region.

Use the command `ps-despool' to send the spooled images to the printer."
  (interactive "r")
  (ps-spool-without-faces from to t))


;;;###autoload
(defun ps-spool-region-with-faces (from to)
  "Generate a PostScript image of the region and spool locally.
Like `ps-spool-region', but includes font, color, and underline
information in the generated image.  This command works only if you
are using a window system, so it has a way to determine color values.

Use the command `ps-despool' to send the spooled images to the printer."
  (interactive "r")
  (ps-spool-with-faces from to t))

;;;###autoload
(defun ps-despool (&optional filename)
  "Send the spooled PostScript to the printer.

When called with a numeric prefix argument (C-u), prompt the user for
the name of a file to save the spooled PostScript in, instead of sending
it to the printer.

More specifically, the FILENAME argument is treated as follows: if it
is nil, send the image to the printer.  If FILENAME is a string, save
the PostScript image in a file with that name.  If FILENAME is a
number, prompt the user for the name of the file to save in."
  (interactive (list (ps-print-preprint current-prefix-arg)))
  (ps-do-despool filename))

;;;###autoload
(defun ps-line-lengths ()
  "Display the correspondence between a line length and a font size,
using the current ps-print setup.
Try: pr -t file | awk '{printf \"%3d %s\n\", length($0), $0}' | sort -r | head"
  (interactive)
  (ps-line-lengths-internal))

;;;###autoload
(defun ps-nb-pages-buffer (nb-lines)
  "Display number of pages to print this buffer, for various font heights.
The table depends on the current ps-print setup."
  (interactive (list (count-lines (point-min) (point-max))))
  (ps-nb-pages nb-lines))

;;;###autoload
(defun ps-nb-pages-region (nb-lines)
  "Display number of pages to print the region, for various font heights.
The table depends on the current ps-print setup."
  (interactive (list (count-lines (mark) (point))))
  (ps-nb-pages nb-lines))

;;;###autoload
(defun ps-setup ()
  "Return the current setup."
  (format
   "
\(setq ps-print-color-p  %s
      ps-lpr-command    \"%s\"
      ps-lpr-switches   %s

      ps-paper-type         '%s
      ps-landscape-mode     %s
      ps-number-of-columns  %s

      ps-zebra-stripes      %s
      ps-zebra-stripe-height %s
      ps-line-number        %s

      ps-print-background-image %s

      ps-print-background-text %s

      ps-left-margin        %s
      ps-right-margin       %s
      ps-inter-column       %s
      ps-bottom-margin      %s
      ps-top-margin         %s
      ps-header-offset      %s
      ps-header-line-pad    %s
      ps-print-header       %s
      ps-print-header-frame %s
      ps-header-lines       %s
      ps-show-n-of-n        %s
      ps-spool-duplex       %s

      ps-font-family            '%s
      ps-font-size              %s
      ps-header-font-family     '%s
      ps-header-font-size       %s
      ps-header-title-font-size %s)
"
   ps-print-color-p
   ps-lpr-command
   ps-lpr-switches
   ps-paper-type
   ps-landscape-mode
   ps-number-of-columns
   ps-zebra-stripes
   ps-zebra-stripe-height
   ps-line-number
   ps-print-background-image
   ps-print-background-text
   ps-left-margin
   ps-right-margin
   ps-inter-column
   ps-bottom-margin
   ps-top-margin
   ps-header-offset
   ps-header-line-pad
   ps-print-header
   ps-print-header-frame
   ps-header-lines
   ps-show-n-of-n
   ps-spool-duplex
   ps-font-family
   ps-font-size
   ps-header-font-family
   ps-header-font-size
   ps-header-title-font-size))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Utility functions and variables:

(defvar ps-print-emacs-type
  (cond ((string-match "XEmacs" emacs-version) 'xemacs)
	((string-match "Lucid" emacs-version) 'lucid)
	((string-match "Epoch" emacs-version) 'epoch)
	(t 'emacs)))

(if (or (eq ps-print-emacs-type 'lucid)
	(eq ps-print-emacs-type 'xemacs))
    (if (< emacs-minor-version 12)
	(setq ps-print-color-p nil))
  (require 'faces))			; face-font, face-underline-p,
					; x-font-regexp

(require 'time-stamp)

(defvar ps-font nil
  "Font family name for ordinary text, when generating Postscript.")

(defvar ps-font-bold nil
  "Font family name for bold text, when generating Postscript.")

(defvar ps-font-italic nil
  "Font family name for italic text, when generating Postscript.")

(defvar ps-font-bold-italic nil
  "Font family name for bold italic text, when generating Postscript.")

(defvar ps-avg-char-width nil
  "The average width, in points, of a character, for generating Postscript.
This is the value that ps-print uses to determine the length,
x-dimension, of the text it has printed, and thus affects the point at
which long lines wrap around.")

(defvar ps-space-width nil
  "The width of a space character, for generating Postscript.
This value is used in expanding tab characters.")

(defvar ps-line-height nil
  "The height of a line, for generating Postscript.
This is the value that ps-print uses to determine the height,
y-dimension, of the lines of text it has printed, and thus affects the
point at which page-breaks are placed.
The line-height is *not* the same as the point size of the font.")

(defvar ps-print-prologue-1
  "% ISOLatin1Encoding stolen from ps_init.ps in GhostScript 2.6.1.4:
/ISOLatin1Encoding where { pop } {
% -- The ISO Latin-1 encoding vector isn't known, so define it.
% -- The first half is the same as the standard encoding,
% -- except for minus instead of hyphen at code 055.
/ISOLatin1Encoding
StandardEncoding 0 45 getinterval aload pop
    /minus
StandardEncoding 46 82 getinterval aload pop
%*** NOTE: the following are missing in the Adobe documentation,
%*** but appear in the displayed table:
%*** macron at 0225, dieresis at 0230, cedilla at 0233, space at 0240.
% 0200 (128)
    /.notdef /.notdef /.notdef /.notdef /.notdef /.notdef /.notdef /.notdef
    /.notdef /.notdef /.notdef /.notdef /.notdef /.notdef /.notdef /.notdef
    /dotlessi /grave /acute /circumflex /tilde /macron /breve /dotaccent
    /dieresis /.notdef /ring /cedilla /.notdef /hungarumlaut /ogonek /caron
% 0240 (160)
    /space /exclamdown /cent /sterling
	/currency /yen /brokenbar /section
    /dieresis /copyright /ordfeminine /guillemotleft
	/logicalnot /hyphen /registered /macron
    /degree /plusminus /twosuperior /threesuperior
	/acute /mu /paragraph /periodcentered
    /cedilla /onesuperior /ordmasculine /guillemotright
	/onequarter /onehalf /threequarters /questiondown
% 0300 (192)
    /Agrave /Aacute /Acircumflex /Atilde
	/Adieresis /Aring /AE /Ccedilla
    /Egrave /Eacute /Ecircumflex /Edieresis
	/Igrave /Iacute /Icircumflex /Idieresis
    /Eth /Ntilde /Ograve /Oacute
	/Ocircumflex /Otilde /Odieresis /multiply
    /Oslash /Ugrave /Uacute /Ucircumflex
	/Udieresis /Yacute /Thorn /germandbls
% 0340 (224)
    /agrave /aacute /acircumflex /atilde
	/adieresis /aring /ae /ccedilla
    /egrave /eacute /ecircumflex /edieresis
	/igrave /iacute /icircumflex /idieresis
    /eth /ntilde /ograve /oacute
	/ocircumflex /otilde /odieresis /divide
    /oslash /ugrave /uacute /ucircumflex
	/udieresis /yacute /thorn /ydieresis
256 packedarray def
} ifelse

/reencodeFontISO { %def
  dup
  length 12 add dict	% Make a new font (a new dict the same size
			% as the old one) with room for our new symbols.

  begin			% Make the new font the current dictionary.


    { 1 index /FID ne
      { def } { pop pop } ifelse
    } forall		% Copy each of the symbols from the old dictionary
			% to the new one except for the font ID.

    /Encoding ISOLatin1Encoding def	% Override the encoding with
					% the ISOLatin1 encoding.

    % Use the font's bounding box to determine the ascent, descent,
    % and overall height; don't forget that these values have to be
    % transformed using the font's matrix.

%          ^    (x2 y2)
%          |       |
%          |       v
%          |  +----+ - -
%          |  |    |   ^
%          |  |    |   | Ascent (usually > 0)
%          |  |    |   |
% (0 0) -> +--+----+-------->
%             |    |   |
%             |    |   v Descent (usually < 0)
% (x1 y1) --> +----+ - -

    FontBBox				% -- x1 y1 x2 y2
    FontMatrix transform /Ascent  exch def pop
    FontMatrix transform /Descent exch def pop
    /FontHeight Ascent Descent sub def	% use `sub' because descent < 0

    % Define these in case they're not in the FontInfo
    % (also, here they're easier to get to).
    /UnderlinePosition  Descent 0.70 mul def
    /OverlinePosition   Descent UnderlinePosition sub Ascent add def
    /StrikeoutPosition  Ascent 0.30 mul def
    /LineThickness      0  50 FontMatrix transform exch pop def
    /Xshadow            0  80 FontMatrix transform exch pop def
    /Yshadow            0 -90 FontMatrix transform exch pop def
    /SpaceBackground    Descent neg UnderlinePosition add def
    /XBox               Descent neg def
    /YBox               LineThickness 0.7 mul def

    currentdict		% Leave the new font on the stack
    end			% Stop using the font as the current dictionary.
    definefont		% Put the font into the font dictionary
    pop			% Discard the returned font.
} bind def

/DefFont {				% Font definition
  findfont exch scalefont reencodeFontISO
} def

/F {					% Font selection
  findfont
  dup /Ascent            get /Ascent            exch def
  dup /Descent           get /Descent           exch def
  dup /FontHeight        get /FontHeight        exch def
  dup /UnderlinePosition get /UnderlinePosition exch def
  dup /OverlinePosition  get /OverlinePosition  exch def
  dup /StrikeoutPosition get /StrikeoutPosition exch def
  dup /LineThickness     get /LineThickness     exch def
  dup /Xshadow           get /Xshadow           exch def
  dup /Yshadow           get /Yshadow           exch def
  dup /SpaceBackground   get /SpaceBackground   exch def
  dup /XBox              get /XBox              exch def
  dup /YBox              get /YBox              exch def
  setfont
} def

/FG /setrgbcolor load def

/bg false def
/BG {
  dup /bg exch def
  {mark 4 1 roll ]}
  {[ 1.0 1.0 1.0 ]}
  ifelse
  /bgcolor exch def
} def

%  B    width    C
%   +-----------+
%               | Ascent  (usually > 0)
% A +           +
%               | Descent (usually < 0)
%   +-----------+
%  E    width    D

/dobackground {				% width --
  currentpoint				% -- width x y
  gsave
    newpath
    moveto				% A (x y)
    0 Ascent rmoveto			% B
    dup 0 rlineto			% C
    0 Descent Ascent sub rlineto	% D
    neg 0 rlineto			% E
    closepath
    bgcolor aload pop setrgbcolor
    fill
  grestore
} def

/eolbg {				% dobackground until right margin
  PrintWidth				% -- x-eol
  currentpoint pop			% -- cur-x
  sub					% -- width until eol
  dobackground
} def

/PLN {PrintLineNumber {doLineNumber}if} def

/SL {					% Soft Linefeed
  bg { eolbg } if
  0  currentpoint exch pop LineHeight sub  moveto
} def

/HL {SL PLN} def			% Hard Linefeed

% Some debug
/dcp { currentpoint exch 40 string cvs print (, ) print = } def
/dp { print 2 copy  exch 40 string cvs print (, ) print = } def

/W {
  ( ) stringwidth	% Get the width of a space in the current font.
  pop			% Discard the Y component.
  mul			% Multiply the width of a space
			% by the number of spaces to plot
  bg { dup dobackground } if
  0 rmoveto
} def

/Effect 0 def
/EF {/Effect exch def} def

% stack:  string  |-  --
% effect: 1  - underline  2   - strikeout  4  - overline
%         8  - shadow     16  - box        32 - outline
/S {
  /xx currentpoint dup Descent add /yy exch def
  Ascent add /YY exch def def
  dup stringwidth pop xx add /XX exch def
  Effect 8 and 0 ne {
    /yy yy Yshadow add def
    /XX XX Xshadow add def
  } if
  bg {
    true
    Effect 16 and 0 ne
      {SpaceBackground doBox}
      {xx yy XX YY doRect}
    ifelse
  } if							% background
  Effect 16 and 0 ne {false 0 doBox}if			% box
  Effect 8  and 0 ne {dup doShadow}if			% shadow
  Effect 32 and 0 ne
    {true doOutline}					% outline
    {show}						% normal text
  ifelse
  Effect 1  and 0 ne {UnderlinePosition Hline}if	% underline
  Effect 2  and 0 ne {StrikeoutPosition Hline}if	% strikeout
  Effect 4  and 0 ne {OverlinePosition  Hline}if	% overline
} bind def

% stack:  position  |-  --
/Hline {
  currentpoint exch pop add dup
  gsave
  newpath
  xx exch moveto
  XX exch lineto
  closepath
  LineThickness setlinewidth stroke
  grestore
} bind def

% stack:  fill-or-not delta  |-  --
/doBox {
  /dd exch def
  xx XBox sub dd sub yy YBox sub dd sub
  XX XBox add dd add YY YBox add dd add
  doRect
} bind def

% stack:  fill-or-not lower-x lower-y upper-x upper-y  |-  --
/doRect {
  /rYY exch def
  /rXX exch def
  /ryy exch def
  /rxx exch def
  gsave
  newpath
  rXX rYY moveto
  rxx rYY lineto
  rxx ryy lineto
  rXX ryy lineto
  closepath
  % top of stack: fill-or-not
    {FillBgColor}
    {LineThickness setlinewidth stroke}
  ifelse
  grestore
} bind def

% stack:  string  |-  --
/doShadow {
  gsave
  Xshadow Yshadow rmoveto
  false doOutline
  grestore
} bind def

/st 1 string def

% stack:  string fill-or-not  |-  --
/doOutline {
  /-fillp- exch def
  /-ox- currentpoint /-oy- exch def def
  gsave
  LineThickness setlinewidth
  {
    st 0 3 -1 roll put
    st dup true charpath
    -fillp- {gsave FillBgColor grestore}if
    stroke stringwidth
    -oy- add /-oy- exch def
    -ox- add /-ox- exch def
    -ox- -oy- moveto
  } forall
  grestore
  -ox- -oy- moveto
} bind def

% stack:  --
/FillBgColor {bgcolor aload pop setrgbcolor fill} bind def

/L0 6 /Times-Italic DefFont

% stack:  --
/doLineNumber {
  currentfont
  gsave
  0.0 0.0 0.0 setrgbcolor
  /L0 findfont setfont
  LineNumber Lines ge
    {(end      )}
    {LineNumber 6 string cvs (      ) strcat}
  ifelse
  dup stringwidth pop neg 0 rmoveto
  show
  grestore
  setfont
  /LineNumber LineNumber 1 add def
} def

% stack: --
/printZebra {
  gsave
  0.985 setgray
  /double-zebra NumberOfZebra NumberOfZebra add def
  /yiter double-zebra LineHeight mul neg def
  /xiter PrintWidth InterColumn add def
  NumberOfColumns {LinesPerColumn doColumnZebra xiter 0 rmoveto}repeat
  grestore
} def

% stack:  lines-per-column |- --
/doColumnZebra {
  gsave
  dup double-zebra idiv {NumberOfZebra doZebra 0 yiter rmoveto}repeat
  double-zebra mod
  dup 0 le {pop}{dup NumberOfZebra gt {pop NumberOfZebra}if doZebra}ifelse
  grestore
} def

% stack:  zebra-height (in lines) |- --
/doZebra {
  /zh exch 0.05 sub LineHeight mul def
  gsave
  0 LineHeight 0.65 mul rmoveto
  PrintWidth 0 rlineto
  0 zh neg rlineto
  PrintWidth neg 0 rlineto
  0 zh rlineto
  fill
  grestore
} def

% tx ty rotation xscale yscale xpos ypos BeginBackImage
/BeginBackImage {
  /-save-image- save def
  /showpage {}def
  translate
  scale
  rotate
  translate
} def

/EndBackImage {
  -save-image- restore
} def

% string fontsize fontname rotation gray xpos ypos ShowBackText
/ShowBackText {
  gsave
  translate
  setgray
  rotate
  findfont exch dup /-offset- exch -0.25 mul def scalefont setfont
  0 -offset- moveto
  /-saveLineThickness- LineThickness def
  /LineThickness 1 def
  false doOutline
  /LineThickness -saveLineThickness- def
  grestore
} def

/BeginDoc {
  % ---- save the state of the document (useful for ghostscript!)
  /docState save def
  % ---- [jack] Kludge: my ghostscript window is 21x27.7 instead of 21x29.7
  /JackGhostscript where {
    pop 1 27.7 29.7 div scale
  } if
  LandscapeMode {
    % ---- translate to bottom-right corner of Portrait page
    LandscapePageHeight 0 translate
    90 rotate
    } if
  /ColumnWidth PrintWidth InterColumn add def
  % ---- translate to lower left corner of TEXT
  LeftMargin BottomMargin translate
  % ---- define where  printing will start
  /f0 F					% this installs Ascent
  /PrintStartY PrintHeight Ascent sub def
  /ColumnIndex 1 def
} def

/EndDoc {
  % ---- on last page but not last column, spit out the page
  ColumnIndex 1 eq not { showpage } if
  % ---- restore the state of the document (useful for ghostscript!)
  docState restore
} def

/BeginDSCPage {
  % ---- when 1st column, save the state of the page
  ColumnIndex 1 eq { /pageState save def } if
  % ---- save the state of the column
  /columnState save def
} def

/BeginPage {
  % ---- when 1st column, print all background effects
  ColumnIndex 1 eq {
  0 PrintStartY moveto			% move to where printing will start
  Zebra {printZebra}if
  printGlobalBackground
  printLocalBackground
  } if
  PrintHeader {
    PrintHeaderFrame { HeaderFrame } if
    HeaderText
  } if
  0 PrintStartY moveto			% move to where printing will start
  PLN
} def

/EndPage {
  bg { eolbg } if
} def

/EndDSCPage {
  ColumnIndex NumberOfColumns eq {
    % ---- on last column, spit out the page
    showpage
    % ---- restore the state of the page
    pageState restore
    /ColumnIndex 1 def
  } { % else
    % ---- restore the state of the current column
    columnState restore
    % ---- and translate to the next column
    ColumnWidth 0 translate
    /ColumnIndex ColumnIndex 1 add def
  } ifelse
} def

/SetHeaderLines {			% nb-lines --
  /HeaderLines exch def
  % ---- bottom up
  HeaderPad
  HeaderLines 1 sub HeaderLineHeight mul add
  HeaderTitleLineHeight add
  HeaderPad add
  /HeaderHeight exch def
} def

% |---------|
% |  tm     |
% |---------|
% |  header |
% |-+-------| <-- (x y)
% |  ho     |
% |---------|
% |  text   |
% |-+-------| <-- (0 0)
% |  bm     |
% |---------|

/HeaderFrameStart {			% -- x y
  0  PrintHeight HeaderOffset add
} def

/HeaderFramePath {
  PrintWidth	 0			rlineto
  0		 HeaderHeight		rlineto
  PrintWidth neg 0			rlineto
  0		 HeaderHeight neg	rlineto
} def

/HeaderFrame {
  gsave
    0.4 setlinewidth
    % ---- fill a black rectangle (the shadow of the next one)
    HeaderFrameStart moveto
    1 -1 rmoveto
    HeaderFramePath
    0 setgray fill
    % ---- do the next rectangle ...
    HeaderFrameStart moveto
    HeaderFramePath
    gsave 0.9 setgray fill grestore	% filled with grey
    gsave 0 setgray stroke grestore	% drawn  with black
  grestore
} def

/HeaderStart {
  HeaderFrameStart
  exch HeaderPad add exch	% horizontal pad
  % ---- bottom up
  HeaderPad add			% vertical   pad
  HeaderDescent sub
  HeaderLineHeight HeaderLines 1 sub mul add
} def

/strcat {
  dup length 3 -1 roll dup length dup 4 -1 roll add string dup
  0 5 -1 roll putinterval
  dup 4 2 roll exch putinterval
} def

/pagenumberstring {
  PageNumber 32 string cvs
  ShowNofN {
    (/) strcat
    PageCount 32 string cvs strcat
  } if
} def

/HeaderText {
  HeaderStart moveto

  HeaderLinesRight HeaderLinesLeft	% -- rightLines leftLines

  % ---- hack: `PN 1 and'  ==  `PN 2 modulo'

  % ---- if duplex and even page number, then exchange left and right
  Duplex PageNumber 1 and 0 eq and { exch } if

  { % ---- process the left lines
    aload pop
    exch F
    gsave
      dup xcheck { exec } if
      show
    grestore
    0 HeaderLineHeight neg rmoveto
  } forall

  HeaderStart moveto

  { % ---- process the right lines
    aload pop
    exch F
    gsave
      dup xcheck { exec } if
      dup stringwidth pop
      PrintWidth exch sub HeaderPad 2 mul sub 0 rmoveto
      show
    grestore
    0 HeaderLineHeight neg rmoveto
  } forall
} def

/ReportFontInfo {
  2 copy
  /t0 3 1 roll DefFont
  /t0 F
  /lh FontHeight def
  /sw ( ) stringwidth pop def
  /aw (01234567890abcdefghijklmnopqrstuvwxyz) dup length exch
  stringwidth pop exch div def
  /t1 12 /Helvetica-Oblique DefFont
  /t1 F
  gsave
    (For ) show
    128 string cvs show
    ( ) show
    32 string cvs show
    ( point, the line height is ) show
    lh 32 string cvs show
    (, the space width is ) show
    sw 32 string cvs show
    (,) show
  grestore
  0 FontHeight neg rmoveto
  gsave
    (and a crude estimate of average character width is ) show
    aw 32 string cvs show
    (.) show
  grestore
  0 FontHeight neg rmoveto
} def

/cm { % cm to point
  72 mul 2.54 div
} def

/ReportAllFontInfo {
  FontDirectory
  { % key = font name  value = font dictionary
    pop 10 exch ReportFontInfo
  } forall
} def

% 3 cm 20 cm moveto  10 /Courier ReportFontInfo  showpage
% 3 cm 20 cm moveto  ReportAllFontInfo           showpage

")

(defvar ps-print-prologue-2
  "
% ---- These lines must be kept together because...

/h0 F
/HeaderTitleLineHeight FontHeight def

/h1 F
/HeaderLineHeight FontHeight def
/HeaderDescent    Descent def

% ---- ...because `F' has a side-effect on `FontHeight' and `Descent'

")

;; Start Editing Here:

(defvar ps-source-buffer nil)
(defvar ps-spool-buffer-name "*PostScript*")
(defvar ps-spool-buffer nil)

(defvar ps-output-head nil)
(defvar ps-output-tail nil)

(defvar ps-page-count 0)
(defvar ps-showline-count 1)

(defvar ps-background-pages nil)
(defvar ps-background-all-pages nil)
(defvar ps-background-text-count 0)
(defvar ps-background-image-count 0)

(defvar ps-current-font 0)
(defvar ps-default-color (if ps-print-color-p ps-default-fg)) ; black
(defvar ps-current-color ps-default-color)
(defvar ps-current-bg nil)

(defvar ps-razchunk 0)

(defvar ps-color-format
  (if (eq ps-print-emacs-type 'emacs)

    ;;Emacs understands the %f format; we'll
    ;;use it to limit color RGB values to
    ;;three decimals to cut down some on the
    ;;size of the PostScript output.
    "%0.3f %0.3f %0.3f"

    ;; Lucid emacsen will have to make do with
    ;; %s (princ) for floats.
    "%s %s %s"))

;; These values determine how much print-height to deduct when headers
;; are turned on.  This is a pretty clumsy way of handling it, but
;; it'll do for now.

(defvar ps-header-font nil)
(defvar ps-header-title-font nil)

(defvar ps-header-line-height nil)
(defvar ps-header-title-line-height nil)
(defvar ps-header-pad 0
  "Vertical and horizontal space in points (1/72 inch) between the header frame
and the text it contains.")

;; Define accessors to the dimensions list.

(defmacro ps-page-dimensions-get-width  (dims) `(nth 0 ,dims))
(defmacro ps-page-dimensions-get-height (dims) `(nth 1 ,dims))

(defvar ps-landscape-page-height nil)

(defvar ps-print-width nil)
(defvar ps-print-height nil)

(defvar ps-height-remaining)
(defvar ps-width-remaining)

(defvar ps-print-color-scale nil)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Internal Variables


(defvar ps-print-face-extension-alist nil
  "Alist of symbolic faces *WITH* extension features (box, outline, etc).
An element of this list has the following form:

   (FACE . [BITS FG BG])

   FACE is a symbol denoting a face name
   BITS is a bit vector, where each bit correspond
      to a feature (bold, underline, etc)
      (see documentation for `ps-print-face-map-alist')
   FG foreground color (string or nil)
   BG background color (string or nil)

Don't change this list directly; instead,
use `ps-extend-face' and `ps-extend-face-list'.
See documentation for `ps-extend-face' for valid extension symbol.")


(defvar ps-print-face-alist nil
  "Alist of symbolic faces *WITHOUT* extension features (box, outline, etc).

An element of this list has the same form as an element of
`ps-print-face-extension-alist'.

Don't change this list directly; this list is used by `ps-face-attributes',
`ps-map-face' and `ps-build-reference-face-lists'.")


(defconst ps-print-face-map-alist
  '((bold        . 1)
    (italic      . 2)
    (underline   . 4)
    (strikeout   . 8)
    (overline    . 16)
    (shadow      . 32)
    (box         . 64)
    (outline     . 128))
  "Alist of all features and the corresponding bit mask.
Each symbol correspond to one bit in a bit vector.")


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Remapping Faces


;;;###autoload
(defun ps-extend-face-list (face-extension-list &optional merge-p)
  "Extend face in `ps-print-face-extension-alist'.

If optional MERGE-P is non-nil, extensions in FACE-EXTENSION-LIST are merged
with face extension in `ps-print-face-extension-alist'; otherwise, overrides.

The elements in FACE-EXTENSION-LIST is like those for `ps-extend-face'.

See `ps-extend-face' for documentation."
  (while face-extension-list
    (ps-extend-face (car face-extension-list) merge-p)
    (setq face-extension-list (cdr face-extension-list))))


;;;###autoload
(defun ps-extend-face (face-extension &optional merge-p)
  "Extend face in `ps-print-face-extension-alist'.

If optional MERGE-P is non-nil, extensions in FACE-EXTENSION-LIST are merged
with face extensions in `ps-print-face-extension-alist'; otherwise, overrides.

The elements of FACE-EXTENSION list have the form:

   (FACE-NAME FOREGROUND BACKGROUND EXTENSION...)

FACE-NAME is a face name symbol.

FOREGROUND and BACKGROUND may be nil or a string that denotes the
foreground and background colors respectively.

EXTENSION is one of the following symbols:
   bold      - use bold font.
   italic    - use italic font.
   underline - put a line under text.
   strikeout - like underline, but the line is in middle of text.
   overline  - like underline, but the line is over the text.
   shadow    - text will have a shadow.
   box       - text will be surrounded by a box.
   outline   - print characters as hollow outlines.

If EXTENSION is any other symbol, it is ignored."
  (let* ((face-name  (nth 0 face-extension))
	 (foreground (nth 1 face-extension))
	 (background (nth 2 face-extension))
	 (ps-face (cdr (assq face-name ps-print-face-extension-alist)))
	 (face-vector (or ps-face (vector 0 nil nil)))
	 (face-bit (ps-extension-bit face-extension)))
    ;; extend face
    (aset face-vector 0 (if merge-p
			    (logior (aref face-vector 0) face-bit)
			  face-bit))
    (and foreground (stringp foreground) (aset face-vector 1 foreground))
    (and background (stringp background) (aset face-vector 2 background))
    ;; if face does not exist, insert it
    (or ps-face
	(setq ps-print-face-extension-alist
	      (cons (cons face-name face-vector)
		    ps-print-face-extension-alist)))))


(defun ps-extension-bit (face-extension)
  (let ((face-bit 0))
    ;; map valid symbol extension to bit vector
    (setq face-extension (cdr (cdr face-extension)))
    (while (setq face-extension (cdr face-extension))
      (setq face-bit (logior face-bit
			     (or (cdr (assq (car face-extension)
					    ps-print-face-map-alist))
				 0))))
    face-bit))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Internal functions and variables


(defun ps-print-without-faces (from to &optional filename region-p)
  (ps-printing-region region-p)
  (ps-generate (current-buffer) from to 'ps-generate-postscript)
  (ps-do-despool filename))


(defun ps-spool-without-faces (from to &optional region-p)
  (ps-printing-region region-p)
  (ps-generate (current-buffer) from to 'ps-generate-postscript))


(defun ps-print-with-faces (from to &optional filename region-p)
  (ps-printing-region region-p)
  (ps-generate (current-buffer) from to 'ps-generate-postscript-with-faces)
  (ps-do-despool filename))


(defun ps-spool-with-faces (from to &optional region-p)
  (ps-printing-region region-p)
  (ps-generate (current-buffer) from to 'ps-generate-postscript-with-faces))


(defsubst ps-count-lines (from to)
  (+ (count-lines from to)
     (save-excursion (goto-char to)
		     (if (= (current-column) 0) 1 0))))


(defvar ps-printing-region nil
  "Variable used to indicate if it is printing a region.
If non-nil, it is a cons, the car of which is the line number
where the region begins, and its cdr is the total number of lines
in the buffer.  Formatting functions can use this information
to print the original line number (and not the number of lines printed),
and to indicate in the header that the printout is of a partial file.")


(defun ps-printing-region (region-p)
  (setq ps-printing-region
	(and region-p
	     (cons (ps-count-lines (point-min) (region-beginning))
		   (ps-count-lines (point-min) (point-max))))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Internal functions

(defun ps-line-lengths-internal ()
  "Display the correspondence between a line length and a font size,
using the current ps-print setup.
Try: pr -t file | awk '{printf \"%3d %s\n\", length($0), $0}' | sort -r | head"
  (let ((buf (get-buffer-create "*Line-lengths*"))
	(ifs ps-font-size)		; initial font size
	(icw ps-avg-char-width)		; initial character width
	(print-width (progn (ps-get-page-dimensions)
			    ps-print-width))
	(ps-setup (ps-setup))		; setup for the current buffer
	(fs-min 5)			; minimum font size
	cw-min				; minimum character width
	nb-cpl-max			; maximum nb of characters per line
	(fs-max 14)			; maximum font size
	cw-max				; maximum character width
	nb-cpl-min			; minimum nb of characters per line
	fs				; current font size
	cw				; current character width
	nb-cpl				; current nb of characters per line
	)
    (setq cw-min     (/ (* icw fs-min) ifs)
	  nb-cpl-max (floor (/ print-width cw-min))
	  cw-max     (/ (* icw fs-max) ifs)
	  nb-cpl-min (floor (/ print-width cw-max)))
    (setq nb-cpl nb-cpl-min)
    (set-buffer buf)
    (goto-char (point-max))
    (if (not (bolp)) (insert "\n"))
    (insert ps-setup)
    (insert "nb char per line / font size\n")
    (while (<= nb-cpl nb-cpl-max)
      (setq cw     (/ print-width (float nb-cpl))
	    fs     (/ (* ifs cw) icw))
      (insert (format "%3s %s\n" nb-cpl fs))
      (setq nb-cpl (1+ nb-cpl)))
    (insert "\n")
    (display-buffer buf 'not-this-window)))

(defun ps-nb-pages (nb-lines)
  "Display an approximate correspondence between a font size and the number
of pages the number of lines would require to print
using the current ps-print setup."
  (let ((buf (get-buffer-create "*Nb-Pages*"))
	(ifs ps-font-size)		; initial font size
	(ilh ps-line-height)		; initial line height
	(page-height (progn (ps-get-page-dimensions)
			    ps-print-height))
	(ps-setup (ps-setup))		; setup for the current buffer
	(fs-min 4)			; minimum font size
	lh-min				; minimum line height
	nb-lpp-max			; maximum nb of lines per page
	nb-page-min			; minimum nb of pages
	(fs-max 14)			; maximum font size
	lh-max				; maximum line height
	nb-lpp-min			; minimum nb of lines per page
	nb-page-max			; maximum nb of pages
	fs				; current font size
	lh				; current line height
	nb-lpp				; current nb of lines per page
	nb-page				; current nb of pages
	)
    (setq lh-min      (/ (* ilh fs-min) ifs)
	  nb-lpp-max  (floor (/ page-height lh-min))
	  nb-page-min (ceiling (/ (float nb-lines) nb-lpp-max))
	  lh-max      (/ (* ilh fs-max) ifs)
	  nb-lpp-min  (floor (/ page-height lh-max))
	  nb-page-max (ceiling (/ (float nb-lines) nb-lpp-min)))
    (setq nb-page nb-page-min)
    (set-buffer buf)
    (goto-char (point-max))
    (if (not (bolp)) (insert "\n"))
    (insert ps-setup)
    (insert (format "%d lines\n" nb-lines))
    (insert "nb page / font size\n")
    (while (<= nb-page nb-page-max)
      (setq nb-lpp (ceiling (/ nb-lines (float nb-page)))
	    lh     (/ page-height nb-lpp)
	    fs     (/ (* ifs lh) ilh))
      (insert (format "%s %s\n" nb-page fs))
      (setq nb-page (1+ nb-page)))
    (insert "\n")
    (display-buffer buf 'not-this-window)))

(defun ps-select-font ()
  "Choose the font name and size (scaling data)."
  (let ((assoc (assq ps-font-family ps-font-info-database))
	l fn fb fi bi sz lh sw aw)
    (if (null assoc)
	(error "Don't have data to scale font %s. Known fonts families are %s"
	       ps-font-family
	       (mapcar 'car ps-font-info-database)))
    (setq l  (cdr assoc)
	  fn (prog1 (car l) (setq l (cdr l))) ; need `pop'
	  fb (prog1 (car l) (setq l (cdr l)))
	  fi (prog1 (car l) (setq l (cdr l)))
	  bi (prog1 (car l) (setq l (cdr l)))
	  sz (prog1 (car l) (setq l (cdr l)))
	  lh (prog1 (car l) (setq l (cdr l)))
	  sw (prog1 (car l) (setq l (cdr l)))
	  aw (prog1 (car l) (setq l (cdr l))))

    (setq ps-font             fn)
    (setq ps-font-bold        fb)
    (setq ps-font-italic      fi)
    (setq ps-font-bold-italic bi)
    ;; These data just need to be rescaled:
    (setq ps-line-height    (/ (* lh ps-font-size) sz))
    (setq ps-space-width    (/ (* sw ps-font-size) sz))
    (setq ps-avg-char-width (/ (* aw ps-font-size) sz))
    ps-font-family))

(defun ps-select-header-font ()
  "Choose the font name and size (scaling data) for the header."
  (let ((assoc (assq ps-header-font-family ps-font-info-database))
	l fn fb fi bi sz lh sw aw)
    (if (null assoc)
	(error "Don't have data to scale font %s. Known fonts families are %s"
	       ps-font-family
	       (mapcar 'car ps-font-info-database)))
    (setq l  (cdr assoc)
	  fn (prog1 (car l) (setq l (cdr l))) ; need `pop'
	  fb (prog1 (car l) (setq l (cdr l)))
	  fi (prog1 (car l) (setq l (cdr l)))
	  bi (prog1 (car l) (setq l (cdr l)))
	  sz (prog1 (car l) (setq l (cdr l)))
	  lh (prog1 (car l) (setq l (cdr l)))
	  sw (prog1 (car l) (setq l (cdr l)))
	  aw (prog1 (car l) (setq l (cdr l))))

    ;; Font name
    (setq ps-header-font             fn)
    (setq ps-header-title-font       fb)
    ;; Line height: These data just need to be rescaled:
    (setq ps-header-title-line-height (/ (* lh ps-header-title-font-size) sz))
    (setq ps-header-line-height       (/ (* lh ps-header-font-size)       sz))
    ps-header-font-family))

(defun ps-get-page-dimensions ()
  (let ((page-dimensions (cdr (assq ps-paper-type ps-page-dimensions-database)))
	page-width page-height)
    (cond
     ((null page-dimensions)
      (error "`ps-paper-type' must be one of:\n%s"
	     (mapcar 'car ps-page-dimensions-database)))
     ((< ps-number-of-columns 1)
      (error "The number of columns %d should not be negative" ps-number-of-columns)))

    (ps-select-font)
    (ps-select-header-font)

    (setq page-width  (ps-page-dimensions-get-width  page-dimensions)
	  page-height (ps-page-dimensions-get-height page-dimensions))

    ;; Landscape mode
    (if ps-landscape-mode
	;; exchange width and height
	(setq page-width (prog1 page-height (setq page-height page-width))))

    ;; It is used to get the lower right corner (only in landscape mode)
    (setq ps-landscape-page-height page-height)

    ;; | lm | text | ic | text | ic | text | rm |
    ;; page-width == lm  +  n * pw  +  (n - 1) * ic  +  rm
    ;; => pw == (page-width - lm -rm - (n - 1) * ic) / n
    (setq ps-print-width
	  (/ (- page-width
		ps-left-margin ps-right-margin
		(* (1- ps-number-of-columns) ps-inter-column))
	     ps-number-of-columns))
    (if (<= ps-print-width 0)
	(error "Bad horizontal layout:
page-width           == %s
ps-left-margin       == %s
ps-right-margin      == %s
ps-inter-column      == %s
ps-number-of-columns == %s
| lm | text | ic | text | ic | text | rm |
page-width == lm  +  n * print-width  +  (n - 1) * ic  +  rm
=> print-width == %d !"
	       page-width
	       ps-left-margin
	       ps-right-margin
	       ps-inter-column
	       ps-number-of-columns
	       ps-print-width))

    (setq ps-print-height
	  (- page-height ps-bottom-margin ps-top-margin))
    (if (<= ps-print-height 0)
	(error "Bad vertical layout:
ps-top-margin    == %s
ps-bottom-margin == %s
page-height == bm + print-height + tm
=> print-height == %d !"
	       ps-top-margin
	       ps-bottom-margin
	       ps-print-height))
    ;; If headers are turned on, deduct the height of the header from
    ;; the print height.
    (cond
     (ps-print-header
      (setq ps-header-pad
	    (* ps-header-line-pad ps-header-title-line-height))
      (setq ps-print-height
	    (- ps-print-height
	       ps-header-offset
	       ps-header-pad
	       ps-header-title-line-height
	       (* ps-header-line-height (- ps-header-lines 1))
	       ps-header-pad))))
    (if (<= ps-print-height 0)
	(error "Bad vertical layout:
ps-top-margin    == %s
ps-bottom-margin == %s
ps-header-offset == %s
ps-header-pad    == %s
header-height    == %s
page-height == bm + print-height + tm - ho - hh
=> print-height == %d !"
	       ps-top-margin
	       ps-bottom-margin
	       ps-header-offset
	       ps-header-pad
	       (+ ps-header-pad
		  ps-header-title-line-height
		  (* ps-header-line-height (- ps-header-lines 1))
		  ps-header-pad)
	       ps-print-height))))

(defun ps-print-preprint (&optional filename)
  (if (and filename
	   (or (numberp filename)
	       (listp filename)))
      (let* ((name (concat (buffer-name) ".ps"))
	     (prompt (format "Save PostScript to file: (default %s) "
			     name))
	     (res (read-file-name prompt default-directory name nil)))
	(if (file-directory-p res)
	    (expand-file-name name (file-name-as-directory res))
	  res))))

;; The following functions implement a simple list-buffering scheme so
;; that ps-print doesn't have to repeatedly switch between buffers
;; while spooling.  The functions ps-output and ps-output-string build
;; up the lists; the function ps-flush-output takes the lists and
;; insert its contents into the spool buffer (*PostScript*).

(defun ps-output-string-prim (string)
  (insert "(")				;insert start-string delimiter
  (save-excursion			;insert string
    (insert string))

  ;; Find and quote special characters as necessary for PS
  (while (re-search-forward "[()\\]" nil t)
    (save-excursion
      (forward-char -1)
      (insert "\\")))

  (goto-char (point-max))
  (insert ")"))				;insert end-string delimiter

(defun ps-init-output-queue ()
  (setq ps-output-head (list ""))
  (setq ps-output-tail ps-output-head))

(defun ps-output (&rest args)
  (setcdr ps-output-tail args)
  (while (cdr ps-output-tail)
    (setq ps-output-tail (cdr ps-output-tail))))

(defun ps-output-string (string)
  (ps-output t string))

(defun ps-output-list (the-list)
  (mapcar 'ps-output the-list))

(defun ps-flush-output ()
  (save-excursion
    (set-buffer ps-spool-buffer)
    (goto-char (point-max))
    (while ps-output-head
      (let ((it (car ps-output-head)))
	(if (not (eq t it))
	    (insert it)
	  (setq ps-output-head (cdr ps-output-head))
	  (ps-output-string-prim (car ps-output-head))))
      (setq ps-output-head (cdr ps-output-head))))
  (ps-init-output-queue))

(defun ps-insert-file (fname)
  (ps-flush-output)
  ;; Check to see that the file exists and is readable; if not, throw
  ;; an error.
  (or (file-readable-p fname)
      (error "Could not read file `%s'" fname))
  (save-excursion
    (set-buffer ps-spool-buffer)
    (goto-char (point-max))
    (insert-file fname)))

;; These functions insert the arrays that define the contents of the
;; headers.

(defun ps-generate-header-line (fonttag &optional content)
  (ps-output "  [ " fonttag " ")
  (cond
   ;; Literal strings should be output as is -- the string must
   ;; contain its own PS string delimiters, '(' and ')', if necessary.
   ((stringp content)
    (ps-output content))

   ;; Functions are called -- they should return strings; they will be
   ;; inserted as strings and the PS string delimiters added.
   ((and (symbolp content) (fboundp content))
    (ps-output-string (funcall content)))

   ;; Variables will have their contents inserted.  They should
   ;; contain strings, and will be inserted as strings.
   ((and (symbolp content) (boundp content))
    (ps-output-string (symbol-value content)))

   ;; Anything else will get turned into an empty string.
   (t
    (ps-output-string "")))
  (ps-output " ]\n"))

(defun ps-generate-header (name contents)
  (ps-output "/" name " [\n")
  (if (> ps-header-lines 0)
      (let ((count 1))
	(ps-generate-header-line "/h0" (car contents))
	(while (and (< count ps-header-lines)
		    (setq contents (cdr contents)))
	  (ps-generate-header-line "/h1" (car contents))
	  (setq count (+ count 1)))
	(ps-output "] def\n"))))

(defun ps-output-boolean (name bool)
  (ps-output (format "/%s %s def\n" name (if bool "true" "false"))))


(defun ps-background-pages (page-list func)
  (if page-list
      (mapcar
       '(lambda (pages)
	  (let ((start (if (consp pages) (car pages) pages))
		(end   (if (consp pages) (cdr pages) pages)))
	    (and (integerp start) (integerp end) (<= start end)
		 (add-to-list 'ps-background-pages (vector start end func)))))
       page-list)
    (setq ps-background-all-pages (cons func ps-background-all-pages))))


(defun ps-get-boundingbox ()
  (save-excursion
    (set-buffer ps-spool-buffer)
    (save-excursion
      (if (re-search-forward
	   "^%%BoundingBox:\\s-+\\([0-9.]+\\)\\s-+\\([0-9.]+\\)\\s-+\\([0-9.]+\\)\\s-+\\([0-9.]+\\)"
	   nil t)
	  (vector (string-to-number	; lower x
		   (buffer-substring (match-beginning 1) (match-end 1)))
		  (string-to-number	; lower y
		   (buffer-substring (match-beginning 2) (match-end 2)))
		  (string-to-number	; upper x
		   (buffer-substring (match-beginning 3) (match-end 3)))
		  (string-to-number	; upper y
		   (buffer-substring (match-beginning 4) (match-end 4))))
	(vector 0 0 0 0)))))


;; Emacs understands the %f format; we'll use it to limit color RGB values
;; to three decimals to cut down some on the size of the PostScript output.
;; Lucid emacsen will have to make do with %s (princ) for floats.

(defvar ps-float-format (if (eq ps-print-emacs-type 'emacs)
			    "%0.3f "	; emacs
			  "%s "))	; Lucid emacsen


(defun ps-float-format (value &optional default)
  (let ((literal (or value default)))
    (if literal
	(format (if (numberp literal)
		    ps-float-format
		  "%s ")
		literal)
      " ")))


(defun ps-background-text ()
  (mapcar
   '(lambda (text)
      (setq ps-background-text-count (1+ ps-background-text-count))
      (ps-output (format "/ShowBackText-%d {\n" ps-background-text-count))
      (ps-output-string (nth 0 text))	; text
      (ps-output
       "\n"
       (ps-float-format (nth 4 text) 200.0) ; font size
       (format "/%s " (or (nth 3 text) "Times-Roman")) ; font name
       (ps-float-format (nth 6 text)
			"PrintHeight PrintPageWidth atan") ; rotation
       (ps-float-format (nth 5 text) 0.85) ; gray
       (ps-float-format (nth 1 text) "0") ; x position
       (ps-float-format (nth 2 text) "BottomMargin") ; y position
       "\nShowBackText} def\n")
      (ps-background-pages (nthcdr 7 text) ; page list
			   (format "ShowBackText-%d\n"
				   ps-background-text-count)))
   ps-print-background-text))


(defun ps-background-image ()
  (mapcar
   '(lambda (image)
      (let ((image-file (expand-file-name (nth 0 image))))
	(if (file-readable-p image-file)
	    (progn
	      (setq ps-background-image-count (1+ ps-background-image-count))
	      (ps-output
	       (format "/ShowBackImage-%d {\n--back-- " ps-background-image-count)
	       (ps-float-format (nth 5 image) 0.0) ; rotation
	       (ps-float-format (nth 3 image) 1.0) ; x scale
	       (ps-float-format (nth 4 image) 1.0) ; y scale
	       (ps-float-format (nth 1 image) ; x position
				"PrintPageWidth 2 div")
	       (ps-float-format (nth 2 image) ; y position
				"PrintHeight 2 div BottomMargin add")
	       "\nBeginBackImage\n")
	      (ps-insert-file image-file)
	      ;; coordinate adjustment to centralize image
	      ;; around x and y position
	      (let ((box (ps-get-boundingbox)))
		(save-excursion
		  (set-buffer ps-spool-buffer)
		  (save-excursion
		    (if (re-search-backward "^--back--" nil t)
			(replace-match
			 (format "%s %s"
				 (ps-float-format
				  (- (+ (/ (- (aref box 2) (aref box 0)) 2.0)
					(aref box 0))))
				 (ps-float-format
				  (- (+ (/ (- (aref box 3) (aref box 1)) 2.0)
					(aref box 1)))))
			 t)))))
	      (ps-output "\nEndBackImage} def\n")
	      (ps-background-pages (nthcdr 6 image) ; page list
				   (format "ShowBackImage-%d\n"
					   ps-background-image-count))))))
   ps-print-background-image))


(defun ps-background (page-number)
  (let (has-local-background)
    (mapcar '(lambda (range)
	       (and (<= (aref range 0) page-number)
		    (<= page-number (aref range 1))
		    (if has-local-background
			(ps-output (aref range 2))
		      (setq has-local-background t)
		      (ps-output "/printLocalBackground {\n"
				 (aref range 2)))))
	    ps-background-pages)
    (and has-local-background (ps-output "} def\n"))))


(defun ps-begin-file ()
  (ps-get-page-dimensions)
  (setq ps-showline-count (if ps-printing-region (car ps-printing-region) 1)
	ps-background-text-count 0
	ps-background-image-count 0
	ps-background-pages nil
	ps-background-all-pages nil)

  (ps-output ps-adobe-tag)
  (ps-output "%%Title: " (buffer-name))	;Take job name from name of
					;first buffer printed
  (ps-output "\n%%Creator: " (user-full-name))
  (ps-output "\n%%CreationDate: "
	     (time-stamp-hh:mm:ss) " " (time-stamp-mon-dd-yyyy)
	     "\n%%Orientation: "
	     (if ps-landscape-mode "Landscape" "Portrait"))
  (ps-output "\n%% DocumentFonts: Times-Roman Times-Italic "
	     ps-font " " ps-font-bold " " ps-font-italic " "
	     ps-font-bold-italic " "
	     ps-header-font " " ps-header-title-font)
  (ps-output "\n%%Pages: (atend)\n")
  (ps-output "%%EndComments\n\n")

  (ps-output-boolean "LandscapeMode"             ps-landscape-mode)
  (ps-output (format "/NumberOfColumns %d def\n" ps-number-of-columns))

  (ps-output (format "/LandscapePageHeight %s def\n" ps-landscape-page-height))
  (ps-output (format "/PrintPageWidth      %s def\n"
		     (- (* (+ ps-print-width ps-inter-column)
			   ps-number-of-columns)
			ps-inter-column)))
  (ps-output (format "/PrintWidth   %s def\n" ps-print-width))
  (ps-output (format "/PrintHeight  %s def\n" ps-print-height))

  (ps-output (format "/LeftMargin   %s def\n" ps-left-margin))
  (ps-output (format "/RightMargin  %s def\n" ps-right-margin)) ; not used
  (ps-output (format "/InterColumn  %s def\n" ps-inter-column))

  (ps-output (format "/BottomMargin %s def\n" ps-bottom-margin))
  (ps-output (format "/TopMargin    %s def\n" ps-top-margin)) ; not used
  (ps-output (format "/HeaderOffset %s def\n" ps-header-offset))
  (ps-output (format "/HeaderPad    %s def\n" ps-header-pad))

  (ps-output-boolean "PrintHeader"      ps-print-header)
  (ps-output-boolean "PrintHeaderFrame" ps-print-header-frame)
  (ps-output-boolean "ShowNofN"         ps-show-n-of-n)
  (ps-output-boolean "Duplex"           ps-spool-duplex)

  (ps-output (format "/LineHeight   %s def\n" ps-line-height)
	     (format "/LinesPerColumn %d def\n"
		     (round (/ (+ ps-print-height
				  (* ps-line-height 0.45))
			       ps-line-height))))

  (ps-output-boolean "Zebra" ps-zebra-stripes)
  (ps-output (format "/NumberOfZebra %d def\n" ps-zebra-stripe-height))

  (ps-output-boolean "PrintLineNumber" ps-line-number)
  (ps-output (format "/Lines %d def\n"
		     (if ps-printing-region
			 (cdr ps-printing-region)
		       (ps-count-lines (point-min) (point-max)))))

  (ps-background-text)
  (ps-background-image)
  (setq ps-background-all-pages (nreverse ps-background-all-pages)
	ps-background-pages (nreverse ps-background-pages))

  (ps-output ps-print-prologue-1)

  (ps-output "/printGlobalBackground {\n")
  (ps-output-list ps-background-all-pages)
  (ps-output "} def\n/printLocalBackground {\n} def\n")

  ;; Header fonts
  (ps-output				; /h0 14 /Helvetica-Bold Font
   (format "/h0 %s /%s DefFont\n" ps-header-title-font-size ps-header-title-font))
  (ps-output				; /h1 12 /Helvetica Font
   (format "/h1 %s /%s DefFont\n" ps-header-font-size       ps-header-font))

  (ps-output ps-print-prologue-2)

  ;; Text fonts
  (ps-output (format "/f0 %s /%s DefFont\n" ps-font-size ps-font))
  (ps-output (format "/f1 %s /%s DefFont\n" ps-font-size ps-font-bold))
  (ps-output (format "/f2 %s /%s DefFont\n" ps-font-size ps-font-italic))
  (ps-output (format "/f3 %s /%s DefFont\n" ps-font-size ps-font-bold-italic))

  (ps-output "\nBeginDoc\n\n")
  (ps-output "%%EndPrologue\n"))

(defun ps-header-dirpart ()
  (let ((fname (buffer-file-name)))
    (if fname
	(if (string-equal (buffer-name) (file-name-nondirectory fname))
	    (file-name-directory fname)
	  fname)
      "")))

(defun ps-get-buffer-name ()
  (cond
   ;; Indulge Jim this little easter egg:
   ((string= (buffer-name) "ps-print.el")
    "Hey, Cool!  It's ps-print.el!!!")
   ;; Indulge Jack this other little easter egg:
   ((string= (buffer-name) "sokoban.el")
    "Super! C'est sokoban.el!")
   (t (concat
       (and ps-printing-region "Subset of: ")
       (buffer-name)
       (and (buffer-modified-p) " (unsaved)")))))

(defun ps-begin-job ()
  (setq ps-page-count 0))

(defun ps-end-file ()
  (ps-output "\n%%Trailer\n")
  (ps-output (format "%%%%Pages: %d\n" (1+ (/ (1- ps-page-count)
					      ps-number-of-columns))))
  (ps-output "\nEndDoc\n\n%%EOF\n"))


(defun ps-next-page ()
  (ps-end-page)
  (ps-flush-output)
  (ps-begin-page))

(defun ps-header-page (&optional inc-p)
  (if (zerop (mod ps-page-count ps-number-of-columns))
      ;; Print only when a new real page begins.
      (let ((page-number (1+ (/ ps-page-count ps-number-of-columns))))
	(ps-output (format "\n%%%%Page: %d %d\n" page-number page-number))
	(ps-output "BeginDSCPage\n")
	(ps-background page-number)
	(and inc-p (incf ps-page-count)))
    ;; Print when any other page begins.
    (ps-output "BeginDSCPage\n")))

(defun ps-begin-page (&optional dummypage)
  (ps-get-page-dimensions)
  (setq ps-width-remaining  ps-print-width)
  (setq ps-height-remaining ps-print-height)

  (ps-header-page)

  (ps-output (format "/LineNumber %d def\n" ps-showline-count)
	     (format "/PageNumber %d def\n" (incf ps-page-count)))
  (ps-output "/PageCount 0 def\n")

  (when ps-print-header
    (ps-generate-header "HeaderLinesLeft"    ps-left-header)
    (ps-generate-header "HeaderLinesRight"   ps-right-header)
    (ps-output (format "%d SetHeaderLines\n" ps-header-lines)))

  (ps-output "BeginPage\n")
  (ps-set-font  ps-current-font)
  (ps-set-bg    ps-current-bg)
  (ps-set-color ps-current-color))

(defun ps-end-page ()
  (ps-output "EndPage\nEndDSCPage\n"))

(defun ps-dummy-page ()
  (ps-header-page t)
  (ps-output "/PrintHeader false def
BeginPage
EndPage
EndDSCPage\n"))

(defun ps-next-line ()
  (setq ps-showline-count (1+ ps-showline-count))
  (if (< ps-height-remaining ps-line-height)
      (ps-next-page)
    (setq ps-width-remaining  ps-print-width)
    (setq ps-height-remaining (- ps-height-remaining ps-line-height))
    (ps-hard-lf)))

(defun ps-continue-line ()
  (if (< ps-height-remaining ps-line-height)
      (ps-next-page)
    (setq ps-width-remaining  ps-print-width)
    (setq ps-height-remaining (- ps-height-remaining ps-line-height))
    (ps-soft-lf)))

;; [jack] Why hard and soft ?

(defun ps-hard-lf ()
  (ps-output "HL\n"))

(defun ps-soft-lf ()
  (ps-output "SL\n"))

(defun ps-find-wrappoint (from to char-width)
  (let ((avail (truncate (/ ps-width-remaining char-width)))
	(todo (- to from)))
    (if (< todo avail)
	(cons to (* todo char-width))
      (cons (+ from avail) ps-width-remaining))))

(defun ps-basic-plot-string (from to &optional bg-color)
  (let* ((wrappoint (ps-find-wrappoint from to ps-avg-char-width))
	 (to (car wrappoint))
	 (string (buffer-substring-no-properties from to)))
    (ps-output-string string)
    (ps-output " S\n")
    wrappoint))

(defun ps-basic-plot-whitespace (from to &optional bg-color)
  (let* ((wrappoint (ps-find-wrappoint from to ps-space-width))
	 (to (car wrappoint)))
    (ps-output (format "%d W\n" (- to from)))
    wrappoint))

(defun ps-plot (plotfunc from to &optional bg-color)
  (while (< from to)
    (let* ((wrappoint (funcall plotfunc from to bg-color))
	   (plotted-to (car wrappoint))
	   (plotted-width (cdr wrappoint)))
      (setq from plotted-to)
      (setq ps-width-remaining (- ps-width-remaining plotted-width))
      (if (< from to)
	  (ps-continue-line))))
  (if ps-razzle-dazzle
      (let* ((q-todo (- (point-max) (point-min)))
	     (q-done (- (point) (point-min)))
	     (chunkfrac (/ q-todo 8))
	     (chunksize (if (> chunkfrac 1000) 1000 chunkfrac)))
	(if (> (- q-done ps-razchunk) chunksize)
	    (let (foo)
	      (setq ps-razchunk q-done)
	      (setq foo
		    (if (< q-todo 100)
			(/ (* 100 q-done) q-todo)
		      (/ q-done (/ q-todo 100))))
	      (message "Formatting...%3d%%" foo))))))

(defun ps-set-font (font)
  (setq ps-current-font font)
  (ps-output (format "/f%d F\n" ps-current-font)))

(defun ps-set-bg (color)
  (if (setq ps-current-bg color)
      (ps-output (format ps-color-format (nth 0 color) (nth 1 color)
			 (nth 2 color))
		 " true BG\n")
    (ps-output "false BG\n")))

(defun ps-set-color (color)
  (setq ps-current-color (or color ps-default-fg))
  (ps-output (format ps-color-format (nth 0 ps-current-color)
		     (nth 1 ps-current-color) (nth 2 ps-current-color))
	     " FG\n"))


(defvar ps-current-effect 0)


(defun ps-plot-region (from to font &optional fg-color bg-color effects)
  (if (not (equal font ps-current-font))
      (ps-set-font font))

  ;; Specify a foreground color only if one's specified and it's
  ;; different than the current.
  (if (not (equal fg-color ps-current-color))
      (ps-set-color fg-color))

  (if (not (equal bg-color ps-current-bg))
      (ps-set-bg bg-color))

  ;; Specify effects (underline, overline, box, etc)
  (cond
   ((not (integerp effects))
    (ps-output "0 EF\n")
    (setq ps-current-effect 0))
   ((/= effects ps-current-effect)
    (ps-output (number-to-string effects) " EF\n")
    (setq ps-current-effect effects)))

  ;; Starting at the beginning of the specified region...
  (save-excursion
    (goto-char from)

    ;; ...break the region up into chunks separated by tabs, linefeeds,
    ;; pagefeeds, control characters, and plot each chunk.
    (while (< from to)
      (if (re-search-forward "[\000-\037\177-\377]" to t)
	  ;; region with some control characters
	  (let ((match (char-after (match-beginning 0))))
	    (if (= match ?\t)		; tab
		(let ((linestart
		       (save-excursion (beginning-of-line) (point))))
		  (ps-plot 'ps-basic-plot-string from (- (point) 1)
			   bg-color)
		  (forward-char -1)
		  (setq from (+ linestart (current-column)))
		  (if (re-search-forward "[ \t]+" to t)
		      (ps-plot 'ps-basic-plot-whitespace
			       from (+ linestart (current-column))
			       bg-color)))
	      ;; any other control character except tab
	      (ps-plot 'ps-basic-plot-string from (- (point) 1) bg-color)
	      (cond
	       ((= match ?\n)		; newline
		(ps-next-line))

	       ((= match ?\f)		; form feed
		(ps-next-page))

	       ((<= match ?\037)	; characters from ^@ to ^_
		(ps-control-character (format "^%c" (+ match ?@))))

	       ((= match ?\177)		; del (127) is printed ^?
		(ps-control-character "^?"))

	       (t			; characters from 128 to 255
		(ps-control-character (format "\\%o" match)))))
	    (setq from (point)))
	;; region without control characters
	(ps-plot 'ps-basic-plot-string from to bg-color)
	(setq from to)))))

(defun ps-control-character (str)
  (let* ((from (1- (point)))
	 (len (length str))
	 (to (+ from len))
	 (wrappoint (ps-find-wrappoint from to ps-avg-char-width)))
    (if (< (car wrappoint) to)
	(ps-continue-line))
    (setq ps-width-remaining (- ps-width-remaining (* len ps-avg-char-width)))
    (ps-output-string str)
    (ps-output " S\n")))

(defun ps-color-value (x-color-value)
  ;; Scale 16-bit X-COLOR-VALUE to PostScript color value in [0, 1] interval.
  (/ x-color-value ps-print-color-scale))

(defun ps-color-values (x-color)
  (cond ((fboundp 'x-color-values)
	 (x-color-values x-color))
	((fboundp 'pixel-components)
	 (pixel-components x-color))
	(t (error "No available function to determine X color values."))))


(defun ps-face-attributes (face)
  "Return face attribute vector.

If FACE is not in `ps-print-face-extension-alist' or in
`ps-print-face-alist', insert it on `ps-print-face-alist' and
return the attribute vector.

If FACE is not a valid face name, it is used default face."
  (cdr (or (assq face ps-print-face-extension-alist)
	   (assq face ps-print-face-alist)
	   (let* ((the-face (if (facep face) face 'default))
		  (new-face (ps-screen-to-bit-face the-face)))
	     (or (and (eq the-face 'default)
		      (assq the-face ps-print-face-alist))
		 (setq ps-print-face-alist (cons new-face ps-print-face-alist)))
	     new-face))))


(defun ps-face-attribute-list (face-or-list)
  (if (listp face-or-list)
      ;; list of faces
      (let ((effects 0) foreground background face-attr face)
	(while face-or-list
	  (setq face (car face-or-list)
		face-attr (ps-face-attributes face)
		effects (logior effects (aref face-attr 0)))
	  (or foreground (setq foreground (aref face-attr 1)))
	  (or background (setq background (aref face-attr 2)))
	  (setq face-or-list (cdr face-or-list)))
	(vector effects foreground background))
    ;; simple face
    (ps-face-attributes face-or-list)))


(defun ps-plot-with-face (from to face)
  (if face
      (let* ((face-bit   (ps-face-attribute-list face))
	     (effect     (aref face-bit 0))
	     (foreground (aref face-bit 1))
	     (background (aref face-bit 2))
	     (fg-color (if (and ps-print-color-p foreground)
			   (mapcar 'ps-color-value
				   (ps-color-values foreground))
			 ps-default-color))
	     (bg-color (if (and ps-print-color-p background)
			   (mapcar 'ps-color-value
				   (ps-color-values background)))))
	(ps-plot-region from to (logand effect 3)
			fg-color bg-color (lsh effect -2)))
    (ps-plot-region from to 0))
  (goto-char to))


(defun ps-xemacs-face-kind-p (face kind kind-regex kind-list)
  (let* ((frame-font (or (face-font face) (face-font 'default)))
	 (kind-cons (assq kind (x-font-properties frame-font)))
	 (kind-spec (cdr-safe kind-cons))
	 (case-fold-search t))

    (or (and kind-spec (string-match kind-regex kind-spec))
	;; Kludge-compatible:
	(memq face kind-list))))

(defun ps-face-bold-p (face)
  (if (eq ps-print-emacs-type 'emacs)
      (or (face-bold-p face)
	  (memq face ps-bold-faces))
    (ps-xemacs-face-kind-p face 'WEIGHT_NAME "bold\\|demibold"
			   ps-bold-faces)))

(defun ps-face-italic-p (face)
  (if (eq ps-print-emacs-type 'emacs)
      (or (face-italic-p face)
	  (memq face ps-italic-faces))
    (or
     (ps-xemacs-face-kind-p face 'ANGLE_NAME "i\\|o" ps-italic-faces)
     (ps-xemacs-face-kind-p face 'SLANT "i\\|o" ps-italic-faces))))

(defun ps-face-underlined-p (face)
  (or (face-underline-p face)
      (memq face ps-underlined-faces)))


;; Ensure that face-list is fbound.
(or (fboundp 'face-list) (defalias 'face-list 'list-faces))


(defun ps-build-reference-face-lists ()
  (setq ps-print-face-alist nil)
  (if ps-auto-font-detect
      (mapcar 'ps-map-face (face-list))
    (mapcar 'ps-set-face-bold ps-bold-faces)
    (mapcar 'ps-set-face-italic ps-italic-faces)
    (mapcar 'ps-set-face-underline ps-underlined-faces))
  (setq ps-build-face-reference nil))


(defun ps-set-face-bold (face)
  (ps-set-face-attribute face 1))

(defun ps-set-face-italic (face)
  (ps-set-face-attribute face 2))

(defun ps-set-face-underline (face)
  (ps-set-face-attribute face 4))


(defun ps-set-face-attribute (face effect)
  (let ((face-bit (cdr (ps-map-face face))))
    (aset face-bit 0 (logior (aref face-bit 0) effect))))


(defun ps-map-face (face)
  (let* ((face-map (ps-screen-to-bit-face face))
	 (ps-face-bit (cdr (assq (car face-map) ps-print-face-alist))))
    (if ps-face-bit
	;; if face exists, merge both
	(let ((face-bit (cdr face-map)))
	  (aset ps-face-bit 0 (logior (aref ps-face-bit 0) (aref face-bit 0)))
	  (or (aref ps-face-bit 1) (aset ps-face-bit 1 (aref face-bit 1)))
	  (or (aref ps-face-bit 2) (aset ps-face-bit 2 (aref face-bit 2))))
      ;; if face does not exist, insert it
      (setq ps-print-face-alist (cons face-map ps-print-face-alist)))
    face-map))


(defun ps-screen-to-bit-face (face)
  (cons face
	(vector (logior (if (ps-face-bold-p face) 1 0) ; bold
			(if (ps-face-italic-p face) 2 0) ; italic
			(if (ps-face-underlined-p face) 4 0)) ; underline
		(face-foreground face)
		(face-background face))))


(defun ps-mapper (extent list)
  (nconc list (list (list (extent-start-position extent) 'push extent)
		    (list (extent-end-position extent) 'pull extent)))
  nil)

(defun ps-extent-sorter (a b)
  (< (extent-priority a) (extent-priority b)))

(defun ps-print-ensure-fontified (start end)
  (if (and (boundp 'lazy-lock-mode) lazy-lock-mode)
      (if (fboundp 'lazy-lock-fontify-region)
	  (lazy-lock-fontify-region start end) ; the new
	(lazy-lock-fontify-buffer))))	; the old

(defun ps-generate-postscript-with-faces (from to)
  ;; Some initialization...
  (setq ps-current-effect 0)

  ;; Build the reference lists of faces if necessary.
  (if (or ps-always-build-face-reference
	  ps-build-face-reference)
      (progn
	(message "Collecting face information...")
	(ps-build-reference-face-lists)))
  ;; Set the color scale.  We do it here instead of in the defvar so
  ;; that ps-print can be dumped into emacs.  This expression can't be
  ;; evaluated at dump-time because X isn't initialized.
  (setq ps-print-color-scale
	(if ps-print-color-p
	    (float (car (ps-color-values "white")))
	  1.0))
  ;; Generate some PostScript.
  (save-restriction
    (narrow-to-region from to)
    (let ((face 'default)
	  (position to))
      (ps-print-ensure-fontified from to)
      (cond
       ((or (eq ps-print-emacs-type 'lucid)
	    (eq ps-print-emacs-type 'xemacs))
	;; Build the list of extents...
	(let ((a (cons 'dummy nil))
	      record type extent extent-list)
	  (map-extents 'ps-mapper nil from to a)
	  (setq a (sort (cdr a) 'car-less-than-car))

	  (setq extent-list nil)

	  ;; Loop through the extents...
	  (while a
	    (setq record (car a))

	    (setq position (car record))
	    (setq record (cdr record))

	    (setq type (car record))
	    (setq record (cdr record))

	    (setq extent (car record))

	    ;; Plot up to this record.
	    ;; XEmacs 19.12: for some reason, we're getting into a
	    ;; situation in which some of the records have
	    ;; positions less than 'from'.  Since we've narrowed
	    ;; the buffer, this'll generate errors.  This is a
	    ;; hack, but don't call ps-plot-with-face unless from >
	    ;; point-min.
	    (if (and (>= from (point-min))
		     (<= position (point-max)))
		(ps-plot-with-face from position face))

	    (cond
	     ((eq type 'push)
	      (if (extent-face extent)
		  (setq extent-list (sort (cons extent extent-list)
					  'ps-extent-sorter))))

	     ((eq type 'pull)
	      (setq extent-list (sort (delq extent extent-list)
				      'ps-extent-sorter))))

	    (setq face
		  (if extent-list
		      (extent-face (car extent-list))
		    'default))

	    (setq from position)
	    (setq a (cdr a)))))

       ((eq ps-print-emacs-type 'emacs)
	(let ((property-change from)
	      (overlay-change from))
	  (while (< from to)
	    (if (< property-change to)	; Don't search for property change
					; unless previous search succeeded.
		(setq property-change
		      (next-property-change from nil to)))
	    (if (< overlay-change to)	; Don't search for overlay change
					; unless previous search succeeded.
		(setq overlay-change
		      (min (next-overlay-change from) to)))
	    (setq position
		  (min property-change overlay-change))
	    ;; The code below is not quite correct,
	    ;; because a non-nil overlay invisible property
	    ;; which is inactive according to the current value
	    ;; of buffer-invisibility-spec nonetheless overrides
	    ;; a face text property.
	    (setq face
		  (cond ((let ((prop (get-text-property from 'invisible)))
			   ;; Decide whether this invisible property
			   ;; really makes the text invisible.
			   (if (eq buffer-invisibility-spec t)
			       (not (null prop))
			     (or (memq prop buffer-invisibility-spec)
				 (assq prop buffer-invisibility-spec))))
			 nil)
			((get-text-property from 'face))
			(t 'default)))
	    (let ((overlays (overlays-at from))
		  (face-priority -1))	; text-property
	      (while overlays
		(let* ((overlay (car overlays))
		       (overlay-face (overlay-get overlay 'face))
		       (overlay-invisible (overlay-get overlay 'invisible))
		       (overlay-priority (or (overlay-get overlay
							  'priority)
					     0)))
		  (if (and (or overlay-invisible overlay-face)
			   (> overlay-priority face-priority))
		      (setq face (cond ((if (eq buffer-invisibility-spec t)
					    (not (null overlay-invisible))
					  (or (memq overlay-invisible
						    buffer-invisibility-spec)
					      (assq overlay-invisible
						    buffer-invisibility-spec)))
					nil)
				       ((and face overlay-face)))
			    face-priority overlay-priority)))
		(setq overlays (cdr overlays))))
	    ;; Plot up to this record.
	    (ps-plot-with-face from position face)
	    (setq from position)))))
      (ps-plot-with-face from to face))))

(defun ps-generate-postscript (from to)
  (ps-plot-region from to 0 nil))

(defun ps-generate (buffer from to genfunc)
  (save-excursion
    (let ((from (min to from))
	  (to (max to from))
	  ;; This avoids trouble if chars with read-only properties
	  ;; are copied into ps-spool-buffer.
	  (inhibit-read-only t))
      (save-restriction
	(narrow-to-region from to)
	(if ps-razzle-dazzle
	    (message "Formatting...%3d%%" (setq ps-razchunk 0)))
	(set-buffer buffer)
	(setq ps-source-buffer buffer)
	(setq ps-spool-buffer (get-buffer-create ps-spool-buffer-name))
	(ps-init-output-queue)
	(let (safe-marker completed-safely needs-begin-file)
	  (unwind-protect
	      (progn
		(set-buffer ps-spool-buffer)

		;; Get a marker and make it point to the current end of the
		;; buffer,  If an error occurs, we'll delete everything from
		;; the end of this marker onwards.
		(setq safe-marker (make-marker))
		(set-marker safe-marker (point-max))

		(goto-char (point-min))
		(if (looking-at (regexp-quote ps-adobe-tag))
		    nil
		  (setq needs-begin-file t))
		(save-excursion
		  (set-buffer ps-source-buffer)
		  (if needs-begin-file (ps-begin-file))
		  (ps-begin-job)
		  (ps-begin-page))
		(set-buffer ps-source-buffer)
		(funcall genfunc from to)
		(ps-end-page)

		(if (and ps-spool-duplex
			 (= (mod ps-page-count 2) 1))
		    (ps-dummy-page))
		(ps-flush-output)

		;; Back to the PS output buffer to set the page count
		(set-buffer ps-spool-buffer)
		(goto-char (point-max))
		(while (re-search-backward "^/PageCount 0 def$" nil t)
		  (replace-match (format "/PageCount %d def" ps-page-count) t))

		;; Setting this variable tells the unwind form that the
		;; the postscript was generated without error.
		(setq completed-safely t))

	    ;; Unwind form: If some bad mojo occurred while generating
	    ;; postscript, delete all the postscript that was generated.
	    ;; This protects the previously spooled files from getting
	    ;; corrupted.
	    (if (and (markerp safe-marker) (not completed-safely))
		(progn
		  (set-buffer ps-spool-buffer)
		  (delete-region (marker-position safe-marker) (point-max))))))

	(if ps-razzle-dazzle
	    (message "Formatting...done"))))))

(defun ps-do-despool (filename)
  (if (or (not (boundp 'ps-spool-buffer))
	  (not (symbol-value 'ps-spool-buffer)))
      (message "No spooled PostScript to print")
    (ps-end-file)
    (ps-flush-output)
    (if filename
	(save-excursion
	  (if ps-razzle-dazzle
	      (message "Saving..."))
	  (set-buffer ps-spool-buffer)
	  (setq filename (expand-file-name filename))
	  (write-region (point-min) (point-max) filename)
	  (if ps-razzle-dazzle
	      (message "Wrote %s" filename)))
      ;; Else, spool to the printer
      (if ps-razzle-dazzle
	  (message "Printing..."))
      (save-excursion
	(set-buffer ps-spool-buffer)
	(if (and (eq system-type 'ms-dos)
		 (stringp (symbol-value 'dos-ps-printer)))
	    (write-region (point-min) (point-max)
			  (symbol-value 'dos-ps-printer) t 0)
	  (let ((binary-process-input t)) ; for MS-DOS
	    (apply 'call-process-region
		   (point-min) (point-max) ps-lpr-command nil
		   (if (fboundp 'start-process) 0 nil)
		   nil
		   ps-lpr-switches))))
      (if ps-razzle-dazzle
	  (message "Printing...done")))
    (kill-buffer ps-spool-buffer)))

(defun ps-kill-emacs-check ()
  (let (ps-buffer)
    (if (and (setq ps-buffer (get-buffer ps-spool-buffer-name))
	     (buffer-modified-p ps-buffer))
	(if (y-or-n-p "Unprinted PostScript waiting; print now? ")
	    (ps-despool)))
    (if (and (setq ps-buffer (get-buffer ps-spool-buffer-name))
	     (buffer-modified-p ps-buffer))
	(if (yes-or-no-p "Unprinted PostScript waiting; exit anyway? ")
	    nil
	  (error "Unprinted PostScript")))))

(if (fboundp 'add-hook)
    (funcall 'add-hook 'kill-emacs-hook 'ps-kill-emacs-check)
  (if kill-emacs-hook
      (message "Won't override existing kill-emacs-hook")
    (setq kill-emacs-hook 'ps-kill-emacs-check)))

;;; Sample Setup Code:

;; This stuff is for anybody that's brave enough to look this far,
;; and able to figure out how to use it.  It isn't really part of
;; ps-print, but I'll leave it here in hopes it might be useful:

;; WARNING!!! The following code is *sample* code only. Don't use it
;; unless you understand what it does!

(defmacro ps-prsc ()
  `(if (eq ps-print-emacs-type 'emacs) [f22] 'f22))
(defmacro ps-c-prsc ()
  `(if (eq ps-print-emacs-type 'emacs) [C-f22] '(control f22)))
(defmacro ps-s-prsc ()
  `(if (eq ps-print-emacs-type 'emacs) [S-f22] '(shift f22)))

;; A hook to bind to `rmail-mode-hook' to locally bind prsc and set the
;; `ps-left-headers' specially for mail messages.
(defun ps-rmail-mode-hook ()
  (local-set-key (ps-prsc) 'ps-rmail-print-message-from-summary)
  (setq ps-header-lines 3
	ps-left-header
	;; The left headers will display the message's subject, its
	;; author, and the name of the folder it was in.
	'(ps-article-subject ps-article-author buffer-name)))

;; See `ps-gnus-print-article-from-summary'.  This function does the
;; same thing for rmail.
(defun ps-rmail-print-message-from-summary ()
  (interactive)
  (ps-print-message-from-summary 'rmail-summary-buffer "RMAIL"))

;; Used in `ps-rmail-print-article-from-summary',
;; `ps-gnus-print-article-from-summary' and `ps-vm-print-message-from-summary'.
(defun ps-print-message-from-summary (summary-buffer summary-default)
  (let ((ps-buf (or (and (boundp summary-buffer)
			 (symbol-value summary-buffer))
		    summary-default)))
    (and (get-buffer ps-buf)
	 (save-excursion
	   (set-buffer ps-buf)
	   (ps-spool-buffer-with-faces)))))

;; Look in an article or mail message for the Subject: line.  To be
;; placed in `ps-left-headers'.
(defun ps-article-subject ()
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward "^Subject:[ \t]+\\(.*\\)$" nil t)
	(buffer-substring-no-properties (match-beginning 1) (match-end 1))
      "Subject ???")))

;; Look in an article or mail message for the From: line.  Sorta-kinda
;; understands RFC-822 addresses and can pull the real name out where
;; it's provided.  To be placed in `ps-left-headers'.
(defun ps-article-author ()
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward "^From:[ \t]+\\(.*\\)$" nil t)
	(let ((fromstring (buffer-substring-no-properties (match-beginning 1)
							  (match-end 1))))
	  (cond

	   ;; Try first to match addresses that look like
	   ;; thompson@wg2.waii.com (Jim Thompson)
	   ((string-match ".*[ \t]+(\\(.*\\))" fromstring)
	    (substring fromstring (match-beginning 1) (match-end 1)))

	   ;; Next try to match addresses that look like
	   ;; Jim Thompson <thompson@wg2.waii.com>
	   ((string-match "\\(.*\\)[ \t]+<.*>" fromstring)
	    (substring fromstring (match-beginning 1) (match-end 1)))

	   ;; Couldn't find a real name -- show the address instead.
	   (t fromstring)))
      "From ???")))

;; A hook to bind to `gnus-article-prepare-hook'.  This will set the
;; `ps-left-headers' specially for gnus articles.  Unfortunately,
;; `gnus-article-mode-hook' is called only once, the first time the *Article*
;; buffer enters that mode, so it would only work for the first time
;; we ran gnus.  The second time, this hook wouldn't get set up.  The
;; only alternative is `gnus-article-prepare-hook'.
(defun ps-gnus-article-prepare-hook ()
  (setq ps-header-lines 3)
  (setq ps-left-header
	;; The left headers will display the article's subject, its
	;; author, and the newsgroup it was in.
	(list 'ps-article-subject 'ps-article-author 'gnus-newsgroup-name)))

;; A hook to bind to `vm-mode-hook' to locally bind prsc and set the
;; `ps-left-headers' specially for mail messages.
(defun ps-vm-mode-hook ()
  (local-set-key (ps-prsc) 'ps-vm-print-message-from-summary)
  (setq ps-header-lines 3)
  (setq ps-left-header
	;; The left headers will display the message's subject, its
	;; author, and the name of the folder it was in.
	(list 'ps-article-subject 'ps-article-author 'buffer-name)))

;; Every now and then I forget to switch from the *Summary* buffer to
;; the *Article* before hitting prsc, and a nicely formatted list of
;; article subjects shows up at the printer.  This function, bound to
;; prsc for the gnus *Summary* buffer means I don't have to switch
;; buffers first.
;; sb:  Updated for Gnus 5.
(defun ps-gnus-print-article-from-summary ()
  (interactive)
  (ps-print-message-from-summary 'gnus-article-buffer "*Article*"))

;; See `ps-gnus-print-article-from-summary'.  This function does the
;; same thing for vm.
(defun ps-vm-print-message-from-summary ()
  (interactive)
  (ps-print-message-from-summary 'vm-mail-buffer ""))

;; A hook to bind to bind to `gnus-summary-setup-buffer' to locally bind
;; prsc.
(defun ps-gnus-summary-setup ()
  (local-set-key (ps-prsc) 'ps-gnus-print-article-from-summary))

;; Look in an article or mail message for the Subject: line.  To be
;; placed in `ps-left-headers'.
(defun ps-info-file ()
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward "File:[ \t]+\\([^, \t\n]*\\)" nil t)
	(buffer-substring-no-properties (match-beginning 1) (match-end 1))
      "File ???")))

;; Look in an article or mail message for the Subject: line.  To be
;; placed in `ps-left-headers'.
(defun ps-info-node ()
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward "Node:[ \t]+\\([^,\t\n]*\\)" nil t)
	(buffer-substring-no-properties (match-beginning 1) (match-end 1))
      "Node ???")))

(defun ps-info-mode-hook ()
  (setq ps-left-header
	;; The left headers will display the node name and file name.
	(list 'ps-info-node 'ps-info-file)))

;; WARNING! The following function is a *sample* only, and is *not*
;; meant to be used as a whole unless you understand what the effects
;; will be!  (In fact, this is a copy of Jim's setup for ps-print --
;; I'd be very surprised if it was useful to *anybody*, without
;; modification.)

(defun ps-jts-ps-setup ()
  (global-set-key (ps-prsc) 'ps-spool-buffer-with-faces) ;f22 is prsc
  (global-set-key (ps-s-prsc) 'ps-spool-region-with-faces)
  (global-set-key (ps-c-prsc) 'ps-despool)
  (add-hook 'gnus-article-prepare-hook 'ps-gnus-article-prepare-hook)
  (add-hook 'gnus-summary-mode-hook 'ps-gnus-summary-setup)
  (add-hook 'vm-mode-hook 'ps-vm-mode-hook)
  (add-hook 'vm-mode-hooks 'ps-vm-mode-hook)
  (add-hook 'Info-mode-hook 'ps-info-mode-hook)
  (setq ps-spool-duplex t)
  (setq ps-print-color-p nil)
  (setq ps-lpr-command "lpr")
  (setq ps-lpr-switches '("-Jjct,duplex_long"))
  'ps-jts-ps-setup)

;; WARNING! The following function is a *sample* only, and is *not*
;; meant to be used as a whole unless it corresponds to your needs.
;; (In fact, this is a copy of Jack's setup for ps-print --
;; I would not be that surprised if it was useful to *anybody*,
;; without modification.)

(defun ps-jack-setup ()
  (setq ps-print-color-p  nil
	ps-lpr-command    "lpr"
	ps-lpr-switches   (list)

	ps-paper-type        'a4
	ps-landscape-mode    t
	ps-number-of-columns 2

	ps-left-margin   (/ (* 72  1.0) 2.54) ;  1.0 cm
	ps-right-margin  (/ (* 72  1.0) 2.54) ;  1.0 cm
	ps-inter-column  (/ (* 72  1.0) 2.54) ;  1.0 cm
	ps-bottom-margin (/ (* 72  1.5) 2.54) ;  1.5 cm
	ps-top-margin    (/ (* 72  1.5) 2.54) ;  1.5 cm
	ps-header-offset (/ (* 72  1.0) 2.54) ;  1.0 cm
	ps-header-line-pad    .15
	ps-print-header       t
	ps-print-header-frame t
	ps-header-lines       2
	ps-show-n-of-n        t
	ps-spool-duplex       nil

	ps-font-family             'Courier
	ps-font-size               5.5
	ps-header-font-family      'Helvetica
	ps-header-font-size        6
	ps-header-title-font-size  8)
  'ps-jack-setup)

(provide 'ps-print)

;;; ps-print.el ends here
