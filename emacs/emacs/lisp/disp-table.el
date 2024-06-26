;;; disp-table.el --- functions for dealing with char tables.

;; Copyright (C) 1987, 1994, 1995 Free Software Foundation, Inc.

;; Author: Erik Naggum <erik@naggum.no>
;; Based on a previous version by Howard Gayle
;; Maintainer: FSF
;; Keywords: i18n

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

(put 'display-table 'char-table-extra-slots 6)

;;;###autoload
(defun make-display-table ()
  "Return a new, empty display table."
  (make-char-table 'display-table nil))

(or standard-display-table
    (setq standard-display-table (make-display-table)))

;;; Display-table slot names.  The property value says which slot.

(put 'truncation 'display-table-slot 0)
(put 'wrap 'display-table-slot 1)
(put 'escape 'display-table-slot 2)
(put 'control 'display-table-slot 3)
(put 'selective-display 'display-table-slot 4)
(put 'vertical-border 'display-table-slot 5)

;;;###autoload
(defun display-table-slot (display-table slot)
  "Return the value of the extra slot in DISPLAY-TABLE named SLOT.
SLOT may be a number from 0 to 5 inclusive, or a slot name (symbol).
Valid symbols are `truncation', `wrap', `escape', `control',
`selective-display', and `vertical-border'."
  (let ((slot-number
	 (if (numberp slot) slot
	   (or (get slot 'display-table-slot)
	       (error "Invalid display-table slot name: %s" slot)))))
    (char-table-extra-slot display-table slot-number)))

;;;###autoload
(defun set-display-table-slot (display-table slot value)
  "Set the value of the extra slot in DISPLAY-TABLE named SLOT to VALUE.
SLOT may be a number from 0 to 5 inclusive, or a name (symbol).
Valid symbols are `truncation', `wrap', `escape', `control',
`selective-display', and `vertical-border'."
  (let ((slot-number
	 (if (numberp slot) slot
	   (or (get slot 'display-table-slot)
	       (error "Invalid display-table slot name: %s" slot)))))
    (set-char-table-extra-slot display-table slot-number value)))

;;;###autoload
(defun describe-display-table (dt)
  "Describe the display table DT in a help buffer."
  (with-output-to-temp-buffer "*Help*"
    (princ "\nTruncation glyph: ")
    (prin1 (display-table-slot dt 'truncation))
    (princ "\nWrap glyph: ")
    (prin1 (display-table-slot dt 'wrap))
    (princ "\nEscape glyph: ")
    (prin1 (display-table-slot dt 'escape))
    (princ "\nCtrl glyph: ")
    (prin1 (display-table-slot dt 'control))
    (princ "\nSelective display glyph sequence: ")
    (prin1 (display-table-slot dt 'selective-display))
    (princ "\nVertical window border glyph: ")
    (prin1 (display-table-slot dt 'vertical-border))
    (princ "\nCharacter display glyph sequences:\n")
    (save-excursion
      (set-buffer standard-output)
      (let ((vector (make-vector 256 nil))
	    (i 0))
	(while (< i 256)
	  (aset vector i (aref dt i))
	  (setq i (1+ i)))
	(describe-vector vector))
      (help-mode))
    (print-help-return-message)))

;;;###autoload
(defun describe-current-display-table ()
  "Describe the display table in use in the selected window and buffer."
  (interactive)
  (let ((disptab (or (window-display-table (selected-window))
		     buffer-display-table
		     standard-display-table)))
    (if disptab
	(describe-display-table disptab)
      (message "No display table"))))

;;;###autoload
(defun standard-display-8bit (l h)
  "Display characters in the range L to H literally."
  (while (<= l h)
    (if (and (>= l ?\ ) (< l 127))
	(aset standard-display-table l nil)
      (aset standard-display-table l (vector l)))
    (setq l (1+ l))))

;;;###autoload
(defun standard-display-default (l h)
  "Display characters in the range L to H using the default notation."
  (while (<= l h)
    (if (and (>= l ?\ ) (< l 127))
	(aset standard-display-table l nil)
      (aset standard-display-table l nil))
    (setq l (1+ l))))

;; This function does NOT take terminal-dependent escape sequences.
;; For that, you need to go through create-glyph.  Use one of the
;; other functions below, or roll your own.
;;;###autoload
(defun standard-display-ascii (c s)
  "Display character C using printable string S."
  (aset standard-display-table c (vconcat s)))

;;;###autoload
(defun standard-display-g1 (c sc)
  "Display character C as character SC in the g1 character set.
This function assumes that your terminal uses the SO/SI characters;
it is meaningless for an X frame."
  (if window-system
      (error "Cannot use string glyphs in a windowing system"))
  (aset standard-display-table c
	(vector (create-glyph (concat "\016" (char-to-string sc) "\017")))))

;;;###autoload
(defun standard-display-graphic (c gc)
  "Display character C as character GC in graphics character set.
This function assumes VT100-compatible escapes; it is meaningless for an
X frame."
  (if window-system
      (error "Cannot use string glyphs in a windowing system"))
  (aset standard-display-table c
	(vector (create-glyph (concat "\e(0" (char-to-string gc) "\e(B")))))

;;;###autoload
(defun standard-display-underline (c uc)
  "Display character C as character UC plus underlining."
  (if window-system (require 'faces))
  (aset standard-display-table c
	(vector 
	 (if window-system
	     (logior uc (lsh (face-id (internal-find-face 'underline)) 8))
	   (create-glyph (concat "\e[4m" (char-to-string uc) "\e[m"))))))

;; Allocate a glyph code to display by sending STRING to the terminal.
;;;###autoload
(defun create-glyph (string)
  (if (= (length glyph-table) 65536)
      (error "No free glyph codes remain"))
  ;; Don't use slots that correspond to ASCII characters.
  (if (= (length glyph-table) 32)
      (setq glyph-table (vconcat glyph-table (make-vector 224 nil))))
  (setq glyph-table (vconcat glyph-table (list string)))
  (1- (length glyph-table)))

;;;###autoload
(defun standard-display-european (arg &optional auto)
  "Toggle display of European characters encoded with ISO 8859.
When enabled, characters in the range of 160 to 255 display not
as octal escapes, but as accented characters.  Codes 146 and 160
display as apostrophe and space, even though they are not the ASCII
codes for apostrophe and space.

With prefix argument, enable European character display iff arg is positive.

Normally, this function turns off `enable-multibyte-characters'
for all Emacs buffers, because users who call this function
probably want to edit European characters in single-byte mode.

However, if the optional argument AUTO is non-nil, this function
does not alter `enable-multibyte-characters'.
AUTO also specifies, in this case, the coding system for terminal output."
  (interactive "P")
  (if (or (<= (prefix-numeric-value arg) 0)
	  (and (null arg)
	       (char-table-p standard-display-table)
	       ;; Test 161, because 160 displays as a space.
	       (equal (aref standard-display-table 161) [161])))
      (progn
	(standard-display-default 160 255)
	(unless (eq window-system 'x)
	  (set-terminal-coding-system nil)))
    ;; If the user does this explicitly,
    ;; turn off multibyte chars for more compatibility.
    (or auto
	(setq-default enable-multibyte-characters nil))
    (standard-display-8bit 160 255)
    (unless (or noninteractive (eq window-system 'x))
      ;; Send those codes literally to a non-X terminal.
      ;; If AUTO is nil, we are using single-byte characters,
      ;; so it doesn't matter which one we use.
      (set-terminal-coding-system
       (cond ((eq auto t) 'latin-1)
	     ((symbolp auto) (or auto 'latin-1))
	     ((stringp auto) (intern auto)))))
    ;; Make non-line-break space display as a plain space.
    ;; Most X fonts do the wrong thing for code 160.
    (aset standard-display-table 160 [32])
    ;; Most Windows programs send out apostrophe's as \222.  Most X fonts
    ;; don't contain a character at that position.  Map it to the ASCII
    ;; apostrophe.
    (aset standard-display-table 146 [39])
    ))

(provide 'disp-table)

;;; disp-table.el ends here
