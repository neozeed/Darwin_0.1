;;; pc-win.el --- setup support for `PC windows' (whatever that is).

;; Copyright (C) 1994, 1996, 1997 Free Software Foundation, Inc.

;; Author: Morten Welinder <terra@diku.dk>
;; Maintainer: FSF

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

;;; Code:

(load "term/internal" nil t)

;; Color translation -- doesn't really need to be fast.
;; Colors listed here do not include the "light-",
;; "medium-" and "dark-" prefixes that are accounted for
;; by `msdos-color-translate', which see below).

(defvar msdos-color-aliases
  '(("snow"		. "white")
    ("ghost white"	. "white")
    ("ghostwhite"	. "white")
    ("white smoke"	. "white")
    ("whitesmoke"	. "white")
    ("gainsboro"	. "white")
    ("floral white"	. "white")
    ("floralwhite"	. "white")
    ("old lace"		. "white")
    ("oldlace"		. "white")
    ("linen"		. "white")
    ("antique white"	. "white")
    ("antiquewhite"	. "white")
    ("papaya whip"	. "white")
    ("papayawhip"	. "white")
    ("blanched almond"	. "white")
    ("blanchedalmond"	. "white")
    ("bisque"		. "white")
    ("peach puff"	. "lightred")
    ("peachpuff"	. "lightred")
    ("navajo white"	. "lightred")
    ("navajowhite"	. "lightred")
    ("moccasin"		. "lightred")
    ("cornsilk"		. "white")
    ("ivory"		. "white")
    ("lemon chiffon"	. "yellow")
    ("lemonchiffon"	. "yellow")
    ("seashell"		. "white")
    ("honeydew"		. "white")
    ("mint cream"	. "white")
    ("mintcream"	. "white")
    ("azure"		. "lightcyan")
    ("alice blue"	. "lightcyan")
    ("aliceblue"	. "lightcyan")
    ("lavender"		. "lightcyan")
    ("lavender blush"	. "lightcyan")
    ("lavenderblush"	. "lightcyan")
    ("misty rose"	. "lightred")
    ("mistyrose"	. "lightred")
    ("aquamarine" 	. "blue")
    ("cadet blue"	. "blue")
    ("cadetblue"	. "blue")
    ("cornflower blue"	. "lightblue")
    ("cornflowerblue"	. "lightblue")
    ("midnight blue"	. "blue")
    ("midnightblue"	. "blue")
    ("navy blue"	. "cyan")
    ("navyblue"		. "cyan")
    ("navy"		. "cyan")
    ("royalblue"	. "blue")
    ("royal blue"	. "blue")
    ("sky blue"		. "lightblue")
    ("skyblue"		. "lightblue")
    ("dodger blue"	. "blue")
    ("dodgerblue"	. "blue")
    ("powder blue"	. "lightblue")
    ("powderblue"	. "lightblue")
    ("slate blue"	. "cyan")
    ("slateblue"	. "cyan")
    ("steel blue"	. "blue")
    ("steelblue"	. "blue")
    ("coral"		. "lightred")
    ("tomato"		. "lightred")
    ("firebrick"	. "red")
    ("gold"		. "yellow")
    ("goldenrod"	. "yellow")
    ("goldenrod yellow"	. "yellow")
    ("goldenrodyellow"	. "yellow")
    ("pale goldenrod"	. "yellow")
    ("palegoldenrod"	. "yellow")
    ("olive green"	. "lightgreen")
    ("olivegreen"	. "lightgreen")
    ("olive drab"	. "green")
    ("olivedrab"	. "green")
    ("forest green"	. "green")
    ("forestgreen"	. "green")
    ("lime green"	. "lightgreen")
    ("limegreen"	. "lightgreen")
    ("sea green"	. "lightcyan")
    ("seagreen"		. "lightcyan")
    ("spring green"	. "green")
    ("springgreen"	. "green")
    ("lawn green"	. "lightgreen")
    ("lawngreen"	. "lightgreen")
    ("chartreuse"	. "yellow")
    ("yellow green"	. "lightgreen")
    ("yellowgreen"	. "lightgreen")
    ("green yellow"	. "lightgreen")
    ("greenyellow"	. "lightgreen")
    ("slate grey"	. "lightgray")
    ("slategrey"	. "lightgray")
    ("slate gray"	. "lightgray")
    ("slategray"	. "lightgray")
    ("dim grey"		. "darkgray")
    ("dimgrey"		. "darkgray")
    ("dim gray"		. "darkgray")
    ("dimgray"		. "darkgray")
    ("light grey"	. "lightgray")
    ("lightgrey"	. "lightgray")
    ("light gray"	. "lightgray")
    ("gray"		. "darkgray")
    ("grey"		. "darkgray")
    ("khaki"		. "green")
    ("maroon"		. "red")
    ("orange"		. "brown")
    ("orchid"		. "brown")
    ("saddle brown"	. "red")
    ("saddlebrown"	. "red")
    ("peru"		. "red")
    ("burlywood"	. "brown")
    ("sandy brown"	. "brown")
    ("sandybrown"	. "brown")
    ("pink"		. "lightred")
    ("hotpink"		. "lightred")
    ("hot pink"		."lightred")
    ("plum"		. "magenta")
    ("indian red"	. "red")
    ("indianred"	. "red")
    ("violet red"	. "magenta")
    ("violetred"	. "magenta")
    ("orange red"	. "red")
    ("orangered"	. "red")
    ("salmon"		.  "lightred")
    ("sienna"		. "lightred")
    ("tan"		. "lightred")
    ("chocolate"	. "brown")
    ("thistle"		. "magenta")
    ("turquoise"	. "lightgreen")
    ("pale turquoise"	. "cyan")
    ("paleturquoise"	. "cyan")
    ("violet"		. "magenta")
    ("blue violet"	. "lightmagenta")
    ("blueviolet"	. "lightmagenta")
    ("wheat"		. "white")
    ("green yellow"	. "yellow")
    ("greenyellow"	. "yellow")
    ("purple"		. "magenta")
    ("rosybrown"	. "brown")
    ("rosy brown"	. "brown")
    ("beige"		. "brown"))
  "List of alternate names for colors.")

(defun msdos-color-translate (name)
  (setq name (downcase name))
  (let* ((len (length name))
	 (val (- (length x-colors)
		 (length (member name x-colors))))
	 (try))
    (if (or (< val 0) (>= val (length x-colors))) (setq val nil))
    (or val
	(and (setq try (cdr (assoc name msdos-color-aliases)))
	     (msdos-color-translate try))
	(and (> len 5)
	     (string= "light" (substring name 0 5))
	     (setq try (msdos-color-translate (substring name 5)))
	     (logior try 8))
	(and (> len 6)
	     (string= "light " (substring name 0 6))
	     (setq try (msdos-color-translate (substring name 6)))
	     (logior try 8))
	(and (> len 4)
	     (string= "pale" (substring name 0 4))
	     (setq try (msdos-color-translate (substring name 4)))
	     (logior try 8))
	(and (> len 5)
	     (string= "pale " (substring name 0 5))
	     (setq try (msdos-color-translate (substring name 5)))
	     (logior try 8))
	(and (> len 6)
	     (string= "medium" (substring name 0 6))
	     (msdos-color-translate (substring name 6)))
	(and (> len 7)
	     (string= "medium " (substring name 0 7))
	     (msdos-color-translate (substring name 7)))
	(and (> len 4)
	     (or (string= "dark" (substring name 0 4))
		 (string= "deep" (substring name 0 4)))
	     (msdos-color-translate (substring name 4)))
	(and (> len 5)
	     (or (string= "dark " (substring name 0 5))
		 (string= "deep " (substring name 0 5)))
	     (msdos-color-translate (substring name 5)))
	(and (> len 4) ;; gray shades: gray0 to gray100
	     (save-match-data
	       (and
		(string-match "gr[ae]y[0-9]" name)
		(string-match "[0-9]+\\'" name)
		(let ((num (string-to-int
			    (substring name (match-beginning 0)))))
		  (msdos-color-translate
		   (cond
		    ((> num 90) "white")
		    ((> num 50) "lightgray")
		    ((> num 10) "darkgray")
		    (t "black")))))))
	(and (> len 1) ;; purple1 to purple4 and the like
	     (save-match-data
	       (and
		(string-match "[1-4]\\'" name)
		(msdos-color-translate
		 (substring name 0 (match-beginning 0)))))))))
;; ---------------------------------------------------------------------------
;; We want to delay setting frame parameters until the faces are setup
(defvar default-frame-alist nil)
(modify-frame-parameters terminal-frame default-frame-alist)

(defun msdos-bg-mode (&optional frame)
  (let* ((frame (or frame (selected-frame)))
	 (params (frame-parameters frame))
	 (bg (cdr (assq 'background-color params))))
    (if (member bg '("black" "blue" "darkgray" "green"))
	'dark
      'light)))

(defun msdos-face-setup ()
  (modify-frame-parameters terminal-frame default-frame-alist)

  (modify-frame-parameters terminal-frame
			   (list (cons 'background-mode
				       (msdos-bg-mode terminal-frame))
				 (cons 'display-type 'color)))
  (face-set-after-frame-default terminal-frame)

  (set-face-foreground 'bold "yellow" terminal-frame)
  (set-face-foreground 'italic "red" terminal-frame)
  (set-face-foreground 'bold-italic "lightred" terminal-frame)
  (set-face-foreground 'underline "white" terminal-frame)

  (make-face 'msdos-menu-active-face)
  (make-face 'msdos-menu-passive-face)
  (make-face 'msdos-menu-select-face)
  (set-face-foreground 'msdos-menu-active-face "white" terminal-frame)
  (set-face-foreground 'msdos-menu-passive-face "lightgray" terminal-frame)
  (set-face-background 'msdos-menu-active-face "blue" terminal-frame)
  (set-face-background 'msdos-menu-passive-face "blue" terminal-frame)
  (set-face-background 'msdos-menu-select-face "red" terminal-frame))

;; We have only one font, so...
(add-hook 'before-init-hook 'msdos-face-setup)

;; We create frames as if we were a terminal, but with a twist.
(defun make-msdos-frame (&optional parameters)
  (let* ((parms
	  (append initial-frame-alist default-frame-alist parameters nil))
	 (frame (make-terminal-frame parms)))
    (modify-frame-parameters frame
			     (list (cons 'background-mode
					 (msdos-bg-mode frame))
				   (cons 'display-type 'color)))
    frame))

(setq frame-creation-function 'make-msdos-frame)

;; ---------------------------------------------------------------------------
;; More or less useful imitations of certain X-functions.  A lot of the
;; values returned are questionable, but usually only the form of the
;; returned value matters.  Also, by the way, recall that `ignore' is
;; a useful function for returning 'nil regardless of argument.

;; From src/xfns.c
(defun x-display-color-p (&optional display) 't)
(defun x-list-fonts (pattern &optional face frame maximum width)
  (if (and (numberp width) (= width 1))
      (list "default")
    (list "no-such-font")))
(defun x-color-defined-p (color) (numberp (msdos-color-translate color)))
(defun x-display-pixel-width (&optional frame) (frame-width frame))
(defun x-display-pixel-height (&optional frame) (frame-height frame))
(defun x-display-planes (&optional frame) 4) ; 3 for background, actually
(defun x-display-color-cells (&optional frame) 16) ; ???
(defun x-server-max-request-size (&optional frame) 1000000) ; ???
(defun x-server-vendor (&optional frame) t "GNU")
(defun x-server-version (&optional frame) '(1 0 0))
(defun x-display-screens (&optional frame) 1)
(defun x-display-mm-height (&optional frame) 200) ; Guess the size of my
(defun x-display-mm-width (&optional frame) 253)  ; monitor, MW...
(defun x-display-backing-store (&optional frame) 'not-useful)
(defun x-display-visual-class (&optional frame) 'static-color)
(fset 'x-display-save-under 'ignore)
(fset 'x-get-resource 'ignore)

;; From lisp/term/x-win.el
(setq x-display-name "pc")
(setq split-window-keep-point t)
(defvar x-colors '("black"
		   "blue"
		   "green"
		   "cyan"
		   "red"
		   "magenta"
		   "brown"
		   "lightgray"
		   "darkgray"
		   "lightblue"
		   "lightgreen"
		   "lightcyan"
		   "lightred"
		   "lightmagenta"
		   "yellow"
		   "white")
  "The list of colors available on a PC display under MS-DOS.")
(defun x-defined-colors (&optional frame)
  "Return a list of colors supported for a particular frame.
The argument FRAME specifies which frame to try.
The value may be different for frames on different X displays."
  x-colors)

;; From lisp/term/win32-win.el
;
;;;; Selections and cut buffers
;
;;; We keep track of the last text selected here, so we can check the
;;; current selection against it, and avoid passing back our own text
;;; from x-cut-buffer-or-selection-value.
(defvar x-last-selected-text nil)

(defvar x-select-enable-clipboard t
  "Non-nil means cutting and pasting uses the clipboard.
This is in addition to the primary selection.")

(defun x-select-text (text &optional push)
  (if x-select-enable-clipboard 
      (win16-set-clipboard-data text))
  (setq x-last-selected-text text))
    
;;; Return the value of the current selection.
;;; Consult the selection, then the cut buffer.  Treat empty strings
;;; as if they were unset.
(defun x-get-selection-value ()
  (if x-select-enable-clipboard 
      (let (text)
	;; Don't die if x-get-selection signals an error.
	(condition-case c
	    (setq text (win16-get-clipboard-data))
	  (error (message "win16-get-clipboard-data:%s" c)))
	(if (string= text "") (setq text nil))
	(cond
	 ((not text) nil)
	 ((eq text x-last-selected-text) nil)
	 ((string= text x-last-selected-text)
	  ;; Record the newer string, so subsequent calls can use the 'eq' test.
	  (setq x-last-selected-text text)
	  nil)
	 (t
	  (setq x-last-selected-text text))))))

;;; Arrange for the kill and yank functions to set and check the clipboard.
(setq interprogram-cut-function 'x-select-text)
(setq interprogram-paste-function 'x-get-selection-value)

;; From lisp/faces.el: we only have one font, so always return
;; it, no matter which variety they've asked for.
(defun x-frob-font-slant (font which)
  font)

;; From src/fontset.c:
(fset 'query-fontset 'ignore)

;; From lisp/term/x-win.el: make iconify-or-deiconify-frame a no-op.
(fset 'iconify-or-deiconify-frame 'ignore)

;; From lisp/frame.el
(fset 'set-default-font 'ignore)
(fset 'set-mouse-color 'ignore)		; We cannot, I think.
(fset 'set-cursor-color 'ignore)	; Hardware determined by char under.
(fset 'set-border-color 'ignore)	; Not useful.
;; ---------------------------------------------------------------------------
;; Handle the X-like command line parameters "-fg" and "-bg"
(defun msdos-handle-args (args)
  (let ((rest nil))
    (while args
      (let ((this (car args)))
	(setq args (cdr args))
	(cond ((or (string= this "-fg") (string= this "-foreground"))
	       (if args
		   (setq default-frame-alist
			 (cons (cons 'foreground-color (car args))
			       default-frame-alist)
			 args (cdr args))))
	      ((or (string= this "-bg") (string= this "-background"))
	       (if args
		   (setq default-frame-alist
			 (cons (cons 'background-color (car args))
			       default-frame-alist)
			 args (cdr args))))
	      (t (setq rest (cons this rest))))))
    (nreverse rest)))

(setq command-line-args (msdos-handle-args command-line-args))
;; ---------------------------------------------------------------------------

;;; pc-win.el ends here
