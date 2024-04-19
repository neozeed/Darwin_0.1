;;; encoded-kb.el --- Handler to input multibyte characters encoded somehow

;; Copyright (C) 1995 Electrotechnical Laboratory, JAPAN.
;; Licensed to the Free Software Foundation.

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

(defvar encoded-kbd-mode nil
  "Non-nil if in Encoded-kbd minor mode.")
(put 'encoded-kbd-mode 'permanent-local t)

(or (assq 'encoded-kbd-mode minor-mode-alist)
    (setq minor-mode-alist
	  (cons '(encoded-kbd-mode " Encoded-kbd") minor-mode-alist)))

(defvar encoded-kbd-mode-map
  (let ((map (make-sparse-keymap))
	(i 128))
    (define-key map "\e" 'encoded-kbd-iso2022-esc-prefix)
    (while (< i 256)
      (define-key map (vector i) 'encoded-kbd-handle-8bit)
      (setq i (1+ i)))
    map)
  "Keymap for Encoded-kbd minor mode.")

(or (assq 'encoded-kbd-mode minor-mode-map-alist)
    (setq minor-mode-map-alist
	  (cons (cons 'encoded-kbd-mode encoded-kbd-mode-map)
		minor-mode-map-alist)))

;; Subsidiary keymaps for handling ISO2022 escape sequences.

(defvar encoded-kbd-iso2022-esc-map
  (let ((map (make-sparse-keymap)))
    (define-key map "$" 'encoded-kbd-iso2022-esc-dollar-prefix)
    (define-key map "(" 'encoded-kbd-iso2022-designation-prefix)
    (define-key map ")" 'encoded-kbd-iso2022-designation-prefix)
    (define-key map "," 'encoded-kbd-iso2022-designation-prefix)
    (define-key map "-" 'encoded-kbd-iso2022-designation-prefix)
    map)
  "Keymap for handling ESC code in Encoded-kbd mode.")
(fset 'encoded-kbd-iso2022-esc-prefix encoded-kbd-iso2022-esc-map)

(defvar encoded-kbd-iso2022-esc-dollar-map
  (let ((map (make-sparse-keymap)))
    (define-key map "(" 'encoded-kbd-iso2022-designation-prefix)
    (define-key map ")" 'encoded-kbd-iso2022-designation-prefix)
    (define-key map "," 'encoded-kbd-iso2022-designation-prefix)
    (define-key map "-" 'encoded-kbd-iso2022-designation-prefix)
    (define-key map "@" 'encoded-kbd-iso2022-designation)
    (define-key map "A" 'encoded-kbd-iso2022-designation)
    (define-key map "B" 'encoded-kbd-iso2022-designation)
    map)
  "Keymap for handling ESC $ sequence in Encoded-kbd mode.")
(fset 'encoded-kbd-iso2022-esc-dollar-prefix
      encoded-kbd-iso2022-esc-dollar-map)

(defvar encoded-kbd-iso2022-designation-map
  (let ((map (make-sparse-keymap))
	(l charset-list))
    (while l
      (define-key map
	(char-to-string (charset-iso-final-char (car l)))
	'encoded-kbd-iso2022-designation)
      (setq l (cdr l)))
    map)
  "Keymap for handling ISO2022 designation sequence in Encoded-kbd mode.")
(fset 'encoded-kbd-iso2022-designation-prefix
      encoded-kbd-iso2022-designation-map)

(defvar encoded-kbd-iso2022-non-ascii-map
  (let ((map (make-keymap))
	(i 32))
    (while (< i 128)
      (define-key map (char-to-string i) 'encoded-kbd-self-insert-iso2022-7bit)
      (setq i (1+ i)))
    (define-key map "\e" 'encoded-kbd-iso2022-esc-prefix)
    (setq i 160)
    (while (< i 256)
      (define-key map (vector i) 'encoded-kbd-handle-8bit)
      (setq i (1+ i)))
    map)
  "Keymap for handling non-ASCII character set in Encoded-kbd mode.")

;; One of the symbols `sjis', `iso2022-7', `iso2022-8', or `big5' to
;; denote what kind of coding-system we are now handling in
;; Encoded-kbd mode.
(defvar encoded-kbd-coding nil)

;; Keep information of designation state of ISO2022 encoding.  This is
;; a vector of character sets currently designated to each graphic
;; registers (0..3).

(defvar encoded-kbd-iso2022-designations nil)
(put 'encoded-kbd-iso2022-designations 'permanent-local t)

;; Keep information of invocation state of ISO2022 encoding.  This is
;; a vector of graphic register numbers currently invoked to each
;; graphic plane (0..1), the third element is a single shifted graphic
;; register number.

(defvar encoded-kbd-iso2022-invocations nil)
(put 'encoded-kbd-iso2022-invocations 'permanent-local t)

(defun encoded-kbd-iso2022-designation ()
  "Do ISO2022 designation according to the curren key in Encoded-kbd mode.
The following key sequence may cause multilingual text insertion."
  (interactive)
  (let ((key-seq (this-command-keys))
	(prev-g0-charset (aref encoded-kbd-iso2022-designations
			       (aref encoded-kbd-iso2022-invocations 0)))
	intermediate-char final-char
	reg dimension chars charset)
    (if (= (length key-seq) 4)
	;; ESC $ <intermediate-char> <final-char>
	(setq intermediate-char (aref key-seq 2)
	      dimension 2
	      chars (if (< intermediate-char ?,) 94 96)
	      final-char (aref key-seq 3)
	      reg (mod intermediate-char 4))
      (if (= (aref key-seq 1) ?$)
	  ;; ESC $ <final-char>
	  (setq dimension 2
		chars 94
		final-char (aref key-seq 2)
		reg 0)
	;; ESC <intermediate-char> <final-char>
	(setq intermediate-char (aref key-seq 1)
	      dimension 1
	      chars (if (< intermediate-char ?,) 94 96)
	      final-char (aref key-seq 2)
	      reg (mod intermediate-char 4))))
    (if (setq charset (iso-charset dimension chars final-char))
	(aset encoded-kbd-iso2022-designations reg charset)
      (error "Character set of DIMENSION %s, CHARS %s, FINAL-CHAR `%c' is not supported"
	     dimension chars final-char))

    (if (memq (aref encoded-kbd-iso2022-designations
		    (aref encoded-kbd-iso2022-invocations 0))
	      '(ascii latin-jisx0201))
	;; Graphic plane 0 (0x20..0x7f) is for ASCII.  We don't have
	;; to handle characters in this range specially.
	(if (not (memq prev-g0-charset '(ascii latin-jisx0201)))
	    ;; We must exit recusive edit now.
	    (throw 'exit nil))
      ;; Graphic plane 0 is for non-ASCII.
      (if (memq prev-g0-charset '(ascii latin-jisx0201))
	  ;; We must handle kyes specially.
	  (let ((overriding-local-map encoded-kbd-iso2022-non-ascii-map))
	    (recursive-edit))))))

(defun encoded-kbd-handle-8bit ()
  "Handle an 8-bit character enterned in Encoded-kbd mode."
  (interactive)
  (cond ((eq encoded-kbd-coding 'iso2022-7)
	 (error "Can't handle the character code %d" last-command-char))

	((eq encoded-kbd-coding 'iso2022-8)
	 (cond ((= last-command-char ?\216)
		(aset encoded-kbd-iso2022-invocations 2 2))

	       ((= last-command-char ?\217)
		(aset encoded-kbd-iso2022-invocations 2 3))

	       ((> last-command-char ?\240)
		(encoded-kbd-self-insert-iso2022-8bit))

	       (t
		(error "Can't handle the character code %d"
		       last-command-char))))

	((eq encoded-kbd-coding 'sjis)
	 (encoded-kbd-self-insert-sjis))

	(t
	 (encoded-kbd-self-insert-big5))))

(defun encoded-kbd-self-insert-iso2022-7bit ()
  (interactive)
  (let* ((charset (aref encoded-kbd-iso2022-designations
			(or (aref encoded-kbd-iso2022-invocations 2)
			    (aref encoded-kbd-iso2022-invocations 0))))
	 (last-command-char
	  (if (= (charset-dimension charset) 1)
	      (make-char charset last-command-char)
	    (make-char charset last-command-char (read-char-exclusive)))))
    (self-insert-command 1)
    (aset encoded-kbd-iso2022-invocations 2 nil)
    ))

(defun encoded-kbd-self-insert-iso2022-8bit ()
  (interactive)
  (let* ((charset (aref encoded-kbd-iso2022-designations
			(or (aref encoded-kbd-iso2022-invocations 2)
			    (aref encoded-kbd-iso2022-invocations 1))))
	 (last-command-char
	  (if (= (charset-dimension charset) 1)
	      (make-char charset last-command-char)
	    (make-char charset last-command-char (read-char-exclusive)))))
    (self-insert-command 1)
    (aset encoded-kbd-iso2022-invocations 2 nil)
    ))

(defun encoded-kbd-self-insert-sjis ()
  (interactive)
  (let ((last-command-char
	 (if (or (< last-command-char ?\xA0) (>= last-command-char ?\xE0))
	     (decode-sjis-char (+ (ash last-command-char 8)
				  (read-char-exclusive)))
	   (make-char 'latin-jisx0201 last-command-char))))
    (self-insert-command 1)))

(defun encoded-kbd-self-insert-big5 ()
  (interactive)
  (let ((last-command-char
	 (decode-big5-char (+ (ash last-command-char 8)
			      (read-char-exclusive)))))
    (self-insert-command 1)))

;; Input mode at the time Encoded-kbd mode is turned on is saved here.
(defvar saved-input-mode nil)

;;;###autoload
(defun encoded-kbd-mode (&optional arg)
  "Toggle Encoded-kbd minor mode.
With arg, turn Encoded-kbd mode on if and only if arg is positive.

You should not turn this mode on manually, instead use the command
`set-keyboard-coding-system' which turns on or off this mode
automatically.

In Encoded-kbd mode, a text sent from keyboard is accepted
as a multilingual text encoded in a coding system set by
`set-keyboard-coding-system'."
  (if encoded-kbd-mode
      ;; We must at first reset input-mode to the original.
      (apply 'set-input-mode saved-input-mode))
  (setq encoded-kbd-mode
	(if (null arg) (null encoded-kbd-mode)
	  (> (prefix-numeric-value arg) 0)))
  (if encoded-kbd-mode
      (let ((coding (keyboard-coding-system)))
	(setq saved-input-mode  (current-input-mode))
	(cond ((null coding)
	       (setq encoded-kbd-mode nil) 
	       (error "No coding system for keyboard input is set"))

	      ((= (coding-system-type coding) 1) ; SJIS
	       (set-input-mode
		(nth 0 saved-input-mode) (nth 1 saved-input-mode)
		'use-8th-bit (nth 3 saved-input-mode))	
	       (setq encoded-kbd-coding 'sjis))

	      ((= (coding-system-type coding) 2) ; ISO2022
	       (if (aref (coding-system-flags coding) 7) ; 7-bit only
		   (setq encoded-kbd-coding 'iso2022-7)
		 (set-input-mode
		  (nth 0 saved-input-mode) (nth 1 saved-input-mode)
		  'use-8th-bit (nth 3 saved-input-mode))	
		 (setq encoded-kbd-coding 'iso2022-8))
	       (setq encoded-kbd-iso2022-designations (make-vector 4 nil))
	       (let ((flags (coding-system-flags coding))
		     (i 0))
		 (while (< i 4)
		   (if (charsetp (aref flags i))
		       (aset encoded-kbd-iso2022-designations i
			     (aref flags i))
		     (if (charsetp (car-safe (aref flags i)))
		       (aset encoded-kbd-iso2022-designations i
			     (car (aref flags i)))))
		   (setq i (1+ i))))
	       (setq encoded-kbd-iso2022-invocations (make-vector 3 nil))
	       (aset encoded-kbd-iso2022-invocations 0 0)
	       (aset encoded-kbd-iso2022-invocations 1 1))

	      ((= (coding-system-type coding) 3) ; BIG5
	       (set-input-mode
		(nth 0 saved-input-mode) (nth 1 saved-input-mode)
		'use-8th-bit (nth 3 saved-input-mode))	
	       (setq encoded-kbd-coding 'big5))

	      (t
	       (setq encoded-kbd-mode nil)
	       (error "Coding-system `%s' is not supported in Encoded-kbd mode"
		      (keyboard-coding-system))))
	(run-hooks 'encoded-kbd-mode-hook))))

;;; encoded-kb.el ends here
