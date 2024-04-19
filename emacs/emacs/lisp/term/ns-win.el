;;; ns-win.el --- parse switches controlling interface with NS window system
;; Copyright (C) 1993 Free Software Foundation, Inc.

;; Author: FSF
;; Keywords: terminals

;;; This file is part of GNU Emacs.
;;;
;;; GNU Emacs is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 2, or (at your option)
;;; any later version.
;;;
;;; GNU Emacs is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Emacs; see the file COPYING.  If not, write to
;;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

;;; Commentary:

;; ns-win.el:  this file is loaded from ../lisp/startup.el when it recognizes
;; that NS windows are to be used.  Command line switches are parsed and those
;; pertaining to NS are processed and removed from the command line.  The
;; NS display is opened and hooks are set for popping up the initial window.

;; startup.el will then examine startup files, and eventually call the hooks
;; which create the first window (s).

;;; Code:

;; An alist of NS options and the function which handles them.  See
;; ../startup.el.

(if (not (eq window-system 'ns))
    (error "%s: Loading ns-win.el but not compiled for OpenStep" (invocation-name)))

(require 'frame)
(require 'mouse)
(require 'ns-scroll-bar)
(require 'ns-menu-bar)
(require 'faces)
(require 'delsel)
(require 'mldrag)

(autoload 'ns-gdb-mode "ns-gdb" "NS gdb is a minor mode which interacts with gdb" t)
(autoload 'reporter-submit-bug-report "reporter" "Submit a bug report via mail." t)

(defvar ns-invocation-args)

(defvar ns-command-line-resources nil)

;;; Font conversion
(defvar ns-convert-font-trait-alist nil
  "Alist (FACE BOLD ITALIC BOLDITALIC) of faces where BOLD, ITALIC,
BOLDITALIC are the faces to use when making FACE bold, italic or
bold-italic. This can be used to either define bold, italic,
bolditalic traits for faces which don't have such traits or to
override the trait chosen by the FontManager.")

;; Handler for switches of the form "-switch value" or "-switch".
(defun ns-handle-switch (switch)
  (let ((aelt (assoc switch command-line-ns-option-alist)))
    (if aelt
	(let ((param (nth 3 aelt))
	      (value (nth 4 aelt)))
	  (if value
	      (setq default-frame-alist
		    (cons (cons param value)
			  default-frame-alist))
	    (setq default-frame-alist
		  (cons (cons param
			      (car ns-invocation-args))
			default-frame-alist)
		  ns-invocation-args (cdr ns-invocation-args)))))))

;; Handler for switches of the form "-switch n"
(defun ns-handle-numeric-switch (switch)
  (let ((aelt (assoc switch command-line-ns-option-alist)))
    (if aelt
	(let ((param (nth 3 aelt)))
	  (setq default-frame-alist
		(cons (cons param
			    (string-to-int (car ns-invocation-args)))
		      default-frame-alist)
		ns-invocation-args
		(cdr ns-invocation-args))))))

;; Make -iconic apply only to the initial frame!
(defun ns-handle-iconic (switch)
  (setq initial-frame-alist
        (cons '(visibility . icon) initial-frame-alist)))

;; Handle the -name option, set the name of
;; the initial frame.
(defun ns-handle-name-switch (switch)
  (or (consp ns-invocation-args)
      (error "%s: missing argument to `%s' option" (invocation-name) switch))
  (setq initial-frame-alist (cons (cons 'name (car ns-invocation-args))
                                  initial-frame-alist)
        ns-invocation-args (cdr ns-invocation-args)))

(defun ns-handle-nxopen (switch)
  (setq unread-command-events (append unread-command-events '(ns-open-file))
        ns-input-file (append ns-input-file (list (car ns-invocation-args)))
        ns-invocation-args (cdr ns-invocation-args)))

(defun ns-handle-nxopentemp (switch)
  (setq unread-command-events (append unread-command-events '(ns-open-temp-file))
        ns-input-file (append ns-input-file (list (car ns-invocation-args)))
        ns-invocation-args (cdr ns-invocation-args)))

(defun ns-ignore-0-arg (switch)
  )
(defun ns-ignore-1-arg (switch)
  (setq ns-invocation-args (cdr ns-invocation-args)))
(defun ns-ignore-2-arg (switch)
  (setq ns-invocation-args (cddr ns-invocation-args)))

(defvar ns-invocation-args nil)

(defvar ns-pop-up-frames 'fresh
  "* Should file opened upon request from the Workspace be opened in a new frame ?
If t, always.  If nil, never.  Otherwise a new frame is opened
unless the current buffer is a scratch buffer.")

(defun ns-handle-args (args)
  "Here the NS-related command line options in ARGS are processed,
before the user's startup file is loaded.  They are copied to
`ns-invocation-args', from which the NS related things are extracted, first
the switch (e.g., \"-fg\") in the following code, and possible values
\(e.g., \"black\") in the option handler code (e.g., ns-handle-switch).
This function returns ARGS minus the arguments that have been processed."
  ;; We use ARGS to accumulate the args that we don't handle here, to return.
  (setq ns-invocation-args args
        args nil)
  (while ns-invocation-args
    (let* ((this-switch (car ns-invocation-args))
	   (orig-this-switch this-switch)
	   completion argval aelt handler)
      (setq ns-invocation-args (cdr ns-invocation-args))
      ;; Check for long options with attached arguments
      ;; and separate out the attached option argument into argval.
      (if (string-match "^--[^=]*=" this-switch)
	  (setq argval (substring this-switch (match-end 0))
		this-switch (substring this-switch 0 (1- (match-end 0)))))
      ;; Complete names of long options.
      (if (string-match "^--" this-switch)
	  (progn
	    (setq completion (try-completion this-switch
                                             command-line-ns-option-alist))
	    (if (eq completion t)
		;; Exact match for long option.
		nil
	      (if (stringp completion)
		  (let ((elt (assoc completion command-line-ns-option-alist)))
		    ;; Check for abbreviated long option.
		    (or elt
			(error "Option `%s' is ambiguous" this-switch))
		    (setq this-switch completion))))))
      (setq aelt (assoc this-switch command-line-ns-option-alist))
      (if aelt (setq handler (nth 2 aelt)))
      (if handler
	  (if argval
	      (let ((ns-invocation-args
		     (cons argval ns-invocation-args)))
		(funcall handler this-switch))
	    (funcall handler this-switch))
	(setq args (cons orig-this-switch args)))))
  (nreverse args))

(defun get-lisp-resource (arg1 arg2)
  (let ((res (ns-get-resource arg1 arg2)))
    (cond
     ((not res) 'unbound)
     ((string-equal (upcase res) "YES")
      t)
     ((string-equal (upcase res) "NO")
      nil)
     (t
      (read res)))))

(defun do-hide-emacs ()
  (interactive)
  (hide-emacs t))

(defun iconify-or-deiconify-frame ()
  "Iconify the selected frame, or deiconify if it's currently an icon."
  (interactive)
  (if (eq (cdr (assq 'visibility (frame-parameters))) t)
      (iconify-frame)
    (make-frame-visible)))

(substitute-key-definition 'suspend-emacs 'iconify-or-deiconify-frame
			   global-map)

;; These tell read-char how to convert
;; these special chars to ASCII.
(put 'backspace 'ascii-character 127)
(put 'delete 'ascii-character 127)
(put 'tab 'ascii-character ?\t)
(put 'S-tab 'ascii-character (logior 16 ?\t))
(put 'linefeed 'ascii-character ?\n)
(put 'clear 'ascii-character 12)
(put 'return 'ascii-character 13)
(put 'escape 'ascii-character ?\e)

;; Map certain keypad keys into ASCII characters
;; that people usually expect.
(define-key function-key-map [backspace] [127])
(define-key function-key-map [delete] [127])
(define-key function-key-map [tab] [?\t])
(define-key function-key-map [S-tab] [25])
(define-key function-key-map [linefeed] [?\n])
(define-key function-key-map [clear] [11])
(define-key function-key-map [return] [13])
(define-key function-key-map [escape] [?\e])
(define-key function-key-map [M-backspace] [?\M-\d])
(define-key function-key-map [M-delete] [?\M-\d])
(define-key function-key-map [M-tab] [?\M-\t])
(define-key function-key-map [M-linefeed] [?\M-\n])
(define-key function-key-map [M-clear] [?\M-\013])
(define-key function-key-map [M-return] [?\M-\015])
(define-key function-key-map [M-escape] [?\M-\e])

;; Nice setting for the cursor key + modifiers
(global-set-key [C-up] 'beginning-of-buffer)
(global-set-key [C-down] 'end-of-buffer)
(global-set-key [C-left] 'beginning-of-line)
(global-set-key [C-right] 'end-of-line)
(global-set-key [S-up] 'scroll-down)
(global-set-key [S-down] 'scroll-up)
(global-set-key [S-left] 'backward-word)
(global-set-key [S-right] 'forward-word)

;; Mouse bindings for ml-drag
(global-set-key [mode-line down-mouse-1] 'mldrag-drag-mode-line)
(global-set-key [vertical-line down-mouse-1] 'mldrag-drag-vertical-line)

;;; Allow shift-clicks to work just like under NS
(defun mouse-extend-region (event)
  "Move point or mark so as to extend region.
This should be bound to a mouse click event type."
  (interactive "e")
  (mouse-minibuffer-check event)
  (let ((posn (event-end event)))
    (if (not (windowp (posn-window posn)))
        (error "Cursor not in text area of window"))
    (select-window (posn-window posn))
    (cond
     ((not (numberp (posn-point posn))))
     ((or (not mark-active) (> (abs (- (posn-point posn) (point)))
                               (abs (- (posn-point posn) (mark)))))
      (let ((point-save (point)))
        (unwind-protect
            (progn
              (goto-char (posn-point posn))
              (push-mark nil t t)
              (or transient-mark-mode
                  (sit-for 1)))
          (goto-char point-save))))
     (t
      (goto-char (posn-point posn))))))

(define-key global-map [S-mouse-1] 'mouse-extend-region)

(defun ns-insert-ascii ()
  "Insert contents of ns-input-ascii."
  (interactive)
  (insert ns-input-ascii)
  (setq ns-input-ascii nil))
 
(defun ns-insert-file ()
  "Insert contents of file ns-input-file like insert-file but with less prompting.
If file is a directory perform a find-file on it."
  (interactive)
  (let ((f))
    (setq f (car ns-input-file))
    (setq ns-input-file (cdr ns-input-file))
    (if (file-directory-p f)
        (find-file f)
      (push-mark (+ (point) (car (cdr (insert-file-contents f))))))))

(defun ns-respond-to-change-font ()
  "Respond to changeFont: event, expecting ns-input-font and\n\
ns-input-fontsize of new font."
  (interactive)
  (modify-frame-parameters (selected-frame)
                           (list (cons 'font ns-input-font)
                                 (cons 'fontsize ns-input-fontsize))))

(defun ns-face-at-pos (pos)
  (let* ((frame (car pos))
         (frame-pos (cdr pos))
         (window (window-at (car frame-pos) (cdr frame-pos) frame))
         (window-pos (coordinates-in-window-p frame-pos window))
         (buffer (window-buffer window))
         (edges (window-edges window)))
    (cond
     ((not window-pos)
      nil)
     ((eq window-pos 'mode-line)
      'modeline)
     ((eq window-pos 'vertical-line)
      'default)
     ((consp window-pos)
      (save-excursion
        (set-buffer buffer)
        (let ((p (car (compute-motion (window-start window)
                                      (cons (nth 0 edges) (nth 1 edges))
                                      (window-end window)
                                      frame-pos
                                      (- (window-width window) 1)
                                      nil
                                      window))))
          (cond
           ((eq p (window-point window))
            'cursor)
           ((and mark-active (< (region-beginning) p) (< p (region-end)))
            'region)
           (t
            (get-char-property p 'face window))))))
     (t
      nil))))

(defun ns-set-foreground-at-mouse ()
  "Set the foreground color at the mouse location to ns-input-color."
  (interactive)
  (let* ((pos (mouse-position))
         (frame (car pos))
         (face (ns-face-at-pos pos)))
    (cond
     ((eq face 'cursor)
      (modify-frame-parameters frame (list (cons 'cursor-color 
                                                 ns-input-color))))
     ((not face)
      (modify-frame-parameters frame (list (cons 'foreground-color
                                                 ns-input-color))))
     (t
      (set-face-foreground face ns-input-color frame)))))
      
(defun ns-set-background-at-mouse ()
  "Set the background color at the mouse location to ns-input-color."
  (interactive)
  (let* ((pos (mouse-position))
         (frame (car pos))
         (face (ns-face-at-pos pos)))
    (cond
     ((eq face 'cursor)
      (modify-frame-parameters frame (list (cons 'cursor-color
                                                 ns-input-color))))
     ((not face)
      (modify-frame-parameters frame (list (cons 'background-color
                                                 ns-input-color))))
     (t
      (set-face-background face ns-input-color frame)))))

(defun ns-save-preferences ()
  "Set all the defaults."
  (interactive)
  (set-resource nil "ShrinkSpace" (number-to-string ns-shrink-space))
  (set-resource nil "CursorBlinkRate"
                (if ns-cursor-blink-rate
                    (number-to-string ns-cursor-blink-rate)
                  "NO"))
  (set-resource nil "AlternateIsMeta" (cond
                                       ((eq t ns-alternate-is-meta) "YES")
                                       ((eq nil ns-alternate-is-meta) "NO")
                                       ((eq 'left ns-alternate-is-meta) "LEFT")
                                       ((eq 'right ns-alternate-is-meta) "RIGHT")
                                       (t nil)))
  (set-resource nil "ISOLatin" (if ns-iso-latin "YES" "NO"))
  (set-resource nil "UseOpenPanel" (if ns-use-open-panel "YES" "NO"))
  (let ((p (frame-parameters)))
    (let ((f (assq 'font p)))
      (if f (set-resource nil "Font" (cdr f))))
    (let ((fs (assq 'fontsize p)))
      (if fs (set-resource nil "FontSize" (number-to-string (cdr fs)))))
    (let ((fgc (assq 'foreground-color p)))
      (if fgc (set-resource nil "Foreground" (cdr fgc))))
    (let ((bgc (assq 'background-color p)))
      (if bgc (set-resource nil "Background" (cdr bgc))))
    (let ((under (assq 'underline p)))
      (if under (set-resource nil "Underline" (if (cdr under) "YES" "NO"))))
    (let ((ibw (assq 'internal-border-width p)))
      (if ibw (set-resource nil "InternalBorderWidth"
                            (number-to-string (cdr ibw)))))
    (let ((vsb (assq 'vertical-scroll-bars p)))
      (if vsb (set-resource nil "VerticalScrollBars"
                            (if (cdr vsb) "YES" "NO"))))
    (let ((buf (assq 'buffered p)))
      (if buf (set-resource nil "Buffered"
                            (if (cdr buf) "YES" "NO"))))
    (let ((ar (assq 'auto-raise p)))
      (if ar (set-resource nil "AutoRaise"
                            (if (cdr ar) "YES" "NO"))))
    (let ((mbl (assq 'menu-bar-lines p)))
      (if mbl (set-resource nil "Menus"
                            (if (cdr mbl) "YES" "NO"))))
    (let ((al (assq 'auto-lower p)))
      (if al (set-resource nil "AutoLower"
                            (if (cdr al) "YES" "NO"))))
    (let ((height (assq 'height p)))
      (if height (set-resource nil "Height"
                               (number-to-string (cdr height)))))
    (let ((width (assq 'width p)))
      (if width (set-resource nil "Width"
                              (number-to-string (cdr width)))))
    (let ((top (assq 'top p)))
      (if top (set-resource nil "Top"
                            (number-to-string (cdr top)))))
    (let ((left (assq 'left p)))
      (if left (set-resource nil "Left"
                             (number-to-string (cdr left)))))
    (let ((it (assq 'icon-type p)))
      (if it (set-resource nil "IconType"
                  (if (symbolp (cdr it)) (symbol-name (cdr it)) (cdr it)))))
    (let ((ct (assq 'cursor-type p)))
      (if ct (set-resource nil "CursorType"
                  (if (symbolp (cdr ct)) (symbol-name (cdr ct)) (cdr ct)))))
    (let ((cc (assq 'cursor-color p)))
      (if cc (set-resource nil "CursorColor" (cdr cc))))
    (let ((sbw (assq 'scroll-bar-width p)))
      (if sbw (set-resource nil "ScrollBarWidth" (cdr sbw))))
    )
  (let ((fl (face-list)))
    (while (consp fl)
      (or (eq 'default (car fl))
          ;; dont save Default* since it causes all created faces to
          ;; inherit it's values.  The properties of the default face
          ;; have already been saved from the frame-parameters anyway.
          (let* ((name (capitalize (symbol-name (car fl))))
                 (font (face-font (car fl)))
                 (fontsize (face-fontsize (car fl)))
                 (foreground (face-foreground (car fl)))
                 (background (face-background (car fl)))
                 (underline (face-underline-p (car fl)))
                 (stipple (face-stipple (car fl))))
            (set-resource nil (concat name "Font")
                          (if font font nil))
            (set-resource nil (concat name "FontSize")
                          (if fontsize (number-to-string fontsize) nil))
            (set-resource nil (concat name "Foreground")
                          (if foreground foreground nil))
            (set-resource nil (concat name "Background")
                          (if background background nil))
            (set-resource nil (concat name "Underline")
                          (if underline "YES" nil))
            (and stipple
                 (or (stringp stipple)
                     (setq stipple (prin1-to-string stipple))))
            (set-resource nil (concat name "Stipple")
                          (if stipple stipple nil))))
      (setq fl (cdr fl))))
  ;; stipple is not yet saved in frame-parameters
  (let ((stipple (face-stipple 'default t)))
    (and stipple
         (or (stringp stipple)
             (setq stipple (prin1-to-string stipple))))
    (set-resource nil "Stipple" (if stipple stipple nil))))
  
(defun ns-find-file ()
  "Do a find-file with the ns-input-file as argument."
  (interactive)
  (let ((f) (file) (bufwin1) (bufwin2))
    (setq f (file-truename (car ns-input-file)))
    (setq ns-input-file (cdr ns-input-file))
    (setq file (find-file-noselect f))
    (setq bufwin1 (get-buffer-window file 'visible))
    (setq bufwin2 (get-buffer-window "*scratch*" 'visibile))
    (cond
     (bufwin1
      (select-frame (window-frame bufwin1))
      (raise-frame (window-frame bufwin1))
      (select-window bufwin1))
     ((and (eq ns-pop-up-frames 'fresh) bufwin2)
      (hide-emacs 'activate)
      (select-frame (window-frame bufwin2))
      (raise-frame (window-frame bufwin2))
      (select-window bufwin2)
      (find-file f))
     (ns-pop-up-frames
      (hide-emacs 'activate)
      (let ((pop-up-frames t)) (pop-to-buffer file nil)))
     (t
      (hide-emacs 'activate)
      (find-file f)))))


(defvar ns-select-overlay nil
  "Overlay used to highlight areas in files requested by NS apps.")
(make-variable-buffer-local 'ns-select-overlay)

(defun ns-open-file-select-line ()
  "Brings up a buffer containing file ns-input-file,\n\
and highlights lines indicated by ns-input-line."
  (interactive)
  (ns-find-file)
  (cond
   ((and ns-input-line (buffer-modified-p))
    (if ns-select-overlay
        (setq ns-select-overlay (delete-overlay ns-select-overlay)))
    (deactivate-mark)
    (goto-line (if (consp ns-input-line)
                   (min (car ns-input-line) (cdr ns-input-line))
                 ns-input-line)))
   (ns-input-line
    (if (not ns-select-overlay)
        (overlay-put (setq ns-select-overlay (make-overlay (point-min) (point-min)))
                     'face 'highlight))
    (let ((beg (save-excursion
                 (goto-line (if (consp ns-input-line)
                                (min (car ns-input-line) (cdr ns-input-line))
                              ns-input-line))
                 (point)))
          (end (save-excursion
                 (goto-line (+ 1 (if (consp ns-input-line)
                                     (max (car ns-input-line) (cdr ns-input-line))
                                   ns-input-line)))
                 (point))))
      (move-overlay ns-select-overlay beg end)
      (deactivate-mark)
      (goto-char beg)))
   (t
    (if ns-select-overlay
        (setq ns-select-overlay (delete-overlay ns-select-overlay))))))

(defun ns-unselect-line ()
  "Removes any NS highlight a buffer may contain."
  (if ns-select-overlay
      (setq ns-select-overlay (delete-overlay ns-select-overlay))))

(add-hook 'first-change-hook 'ns-unselect-line)



;; Special NeXTSTEP generated events are converted to function keys.  Here
;; are the bindings for them.
(define-key global-map [ns-power-off]
  '(lambda () (interactive) (save-buffers-kill-emacs t)))
(define-key global-map [ns-open-file] 'ns-find-file)
(define-key global-map [ns-open-temp-file] [ns-open-file])
(define-key global-map [ns-drag-file] 'ns-insert-file)
(define-key global-map [ns-drag-color] 'ns-set-foreground-at-mouse)
(define-key global-map [ns-drag-ascii] 'ns-insert-ascii)
(define-key global-map [S-ns-drag-color] 'ns-set-background-at-mouse)
(define-key global-map [ns-change-font] 'ns-respond-to-change-font)
(define-key global-map [ns-open-file-line] 'ns-open-file-select-line)

(setq system-key-alist
      (list
       (cons (logior (lsh 0 16)   1) 'ns-power-off)
       (cons (logior (lsh 0 16)   2) 'ns-open-file)
       (cons (logior (lsh 0 16)   3) 'ns-open-temp-file)
       (cons (logior (lsh 0 16)   4) 'ns-drag-file)
       (cons (logior (lsh 0 16)   5) 'ns-drag-color)
       (cons (logior (lsh 0 16)   6) 'ns-drag-ascii)
       (cons (logior (lsh 0 16)   7) 'ns-change-font)
       (cons (logior (lsh 0 16)   8) 'ns-open-file-line)
       (cons (logior (lsh 0 16)   9) 'ns-change-gdb)
       (cons (logior (lsh 1 16)  32) 'f1)
       (cons (logior (lsh 1 16)  33) 'f2)
       (cons (logior (lsh 1 16)  34) 'f3)
       (cons (logior (lsh 1 16)  35) 'f4)
       (cons (logior (lsh 1 16)  36) 'f5)
       (cons (logior (lsh 1 16)  37) 'f6)
       (cons (logior (lsh 1 16)  38) 'f7)
       (cons (logior (lsh 1 16)  39) 'f8)
       (cons (logior (lsh 1 16)  40) 'f9)
       (cons (logior (lsh 1 16)  41) 'f10)
       (cons (logior (lsh 1 16)  42) 'f11)
       (cons (logior (lsh 1 16)  43) 'f12)
       (cons (logior (lsh 1 16)  44) 'kp-insert)
       (cons (logior (lsh 1 16)  45) 'kp-delete)
       (cons (logior (lsh 1 16)  46) 'kp-home)
       (cons (logior (lsh 1 16)  47) 'kp-end)
       (cons (logior (lsh 1 16)  48) 'kp-prior)
       (cons (logior (lsh 1 16)  49) 'kp-next)
       (cons (logior (lsh 1 16)  50) 'print-screen)
       (cons (logior (lsh 1 16)  51) 'scroll-lock)
       (cons (logior (lsh 1 16)  52) 'pause)
       (cons (logior (lsh 1 16)  53) 'system)
       (cons (logior (lsh 1 16)  54) 'break)
       (cons (logior (lsh 1 16)  56) 'please-tell-carl-what-this-key-is-called-56)
       (cons (logior (lsh 1 16)  61) 'please-tell-carl-what-this-key-is-called-61)
       (cons (logior (lsh 1 16)  62) 'please-tell-carl-what-this-key-is-called-62)
       (cons (logior (lsh 1 16)  63) 'please-tell-carl-what-this-key-is-called-63)
       (cons (logior (lsh 1 16)  64) 'please-tell-carl-what-this-key-is-called-64)
       (cons (logior (lsh 1 16)  69) 'please-tell-carl-what-this-key-is-called-69)
       (cons (logior (lsh 1 16)  70) 'please-tell-carl-what-this-key-is-called-70)
       (cons (logior (lsh 1 16)  71) 'please-tell-carl-what-this-key-is-called-71)
       (cons (logior (lsh 1 16)  72) 'please-tell-carl-what-this-key-is-called-72)
       (cons (logior (lsh 1 16)  73) 'please-tell-carl-what-this-key-is-called-73)
       (cons (logior (lsh 2 16)   3) 'kp-enter)
       (cons (logior (lsh 2 16)   9) 'kp-tab)
       (cons (logior (lsh 2 16)  28) 'kp-quit)
       (cons (logior (lsh 2 16)  35) 'kp-hash)
       (cons (logior (lsh 2 16)  42) 'kp-multiply)
       (cons (logior (lsh 2 16)  43) 'kp-add)
       (cons (logior (lsh 2 16)  44) 'kp-separator)
       (cons (logior (lsh 2 16)  45) 'kp-subtract)
       (cons (logior (lsh 2 16)  46) 'kp-decimal)
       (cons (logior (lsh 2 16)  47) 'kp-divide)
       (cons (logior (lsh 2 16)  48) 'kp-0)
       (cons (logior (lsh 2 16)  49) 'kp-1)
       (cons (logior (lsh 2 16)  50) 'kp-2)
       (cons (logior (lsh 2 16)  51) 'kp-3)
       (cons (logior (lsh 2 16)  52) 'kp-4)
       (cons (logior (lsh 2 16)  53) 'kp-5)
       (cons (logior (lsh 2 16)  54) 'kp-6)
       (cons (logior (lsh 2 16)  55) 'kp-7)
       (cons (logior (lsh 2 16)  56) 'kp-8)
       (cons (logior (lsh 2 16)  57) 'kp-9)
       (cons (logior (lsh 2 16)  60) 'kp-less)
       (cons (logior (lsh 2 16)  61) 'kp-equal)
       (cons (logior (lsh 2 16)  62) 'kp-more)
       (cons (logior (lsh 2 16)  64) 'kp-at)
       (cons (logior (lsh 2 16)  92) 'kp-backslash)
       (cons (logior (lsh 2 16)  96) 'kp-backtick)
       (cons (logior (lsh 2 16) 124) 'kp-bar)
       (cons (logior (lsh 2 16) 126) 'kp-tilde)
       (cons (logior (lsh 2 16) 157) 'kp-mu)
       (cons (logior (lsh 2 16) 165) 'kp-yen)
       (cons (logior (lsh 2 16) 167) 'kp-paragraph)
       (cons (logior (lsh 2 16) 172) 'left)
       (cons (logior (lsh 2 16) 173) 'up)
       (cons (logior (lsh 2 16) 174) 'right)
       (cons (logior (lsh 2 16) 175) 'down)
       (cons (logior (lsh 2 16) 176) 'kp-ring)
       (cons (logior (lsh 2 16) 201) 'kp-square)
       (cons (logior (lsh 2 16) 204) 'kp-cube)
       (cons (logior (lsh 3 16)   8) 'backspace)
       (cons (logior (lsh 3 16)   9) 'tab)
       (cons (logior (lsh 3 16)  10) 'linefeed)
       (cons (logior (lsh 3 16)  11) 'clear)
       (cons (logior (lsh 3 16)  13) 'return)
       (cons (logior (lsh 3 16)  18) 'pause)
       (cons (logior (lsh 3 16)  25) 'S-tab)
       (cons (logior (lsh 3 16)  27) 'escape)
       (cons (logior (lsh 3 16) 127) 'delete)
       ))


(defun undefine-key (keymap key)
  (if (lookup-key keymap key t)
      (define-key keymap key 'undefined)))

;;; Do the actual NS Windows setup here; the above code just defines
;;; functions and variables that we use now.

(setq command-line-args (ns-handle-args command-line-args))

(ns-open-connection (system-name) nil t)

(let ((services (ns-list-services)))
  (while services
    (if (eq (caar services) 'undefined)
	(ns-define-service (cdar services))
      (define-key global-map (vector (caar services))
	(ns-define-service (cdar services)))
      )
    (setq services (cdr services))))

;; Here are some NeXTSTEP like binding for command key sequences.
(define-key global-map [?\s-'] 'next-multiframe-window)
(define-key global-map [?\s--] 'center-line)
(define-key global-map [?\s-:] 'ispell)
(define-key global-map [?\s-\;] 'ispell-next)
(define-key global-map [?\s-?] 'info)
(define-key global-map [?\s-^] 'kill-some-buffers)
(define-key global-map [?\s-&] 'kill-this-buffer)
(define-key global-map [?\s-C] 'ns-popup-color-panel)
(define-key global-map [?\s-D] 'dired)
(define-key global-map [?\s-E] 'edit-abbrevs)
(define-key global-map [?\s-L] 'shell-command)
(define-key global-map [?\s-M] 'manual-entry)
(define-key global-map [?\s-S] 'write-file)
(define-key global-map [?\s-a] 'mark-whole-buffer)
(define-key global-map [?\s-c] 'kill-ring-save)
(define-key global-map [?\s-d] 'isearch-repeat-backward)
(define-key global-map [?\s-e] 'isearch-yank-kill)
(define-key global-map [?\s-f] 'isearch-forward)
(define-key global-map [?\s-g] 'isearch-repeat-forward)
(define-key global-map [?\s-h] 'do-hide-emacs)
(define-key global-map [?\s-j] 'exchange-point-and-mark)
(define-key global-map [?\s-k] 'kill-this-buffer)
(define-key global-map [?\s-l] 'goto-line)
(define-key global-map [?\s-m] 'iconify-frame)
(define-key global-map [?\s-n] 'new-frame)
(define-key global-map [?\s-o] 'find-file-other-frame)
(define-key global-map [?\s-p] 'print-buffer)
(define-key global-map [?\s-q] 'save-buffers-kill-emacs)
(define-key global-map [?\s-s] 'save-buffer)
(define-key global-map [?\s-t] 'ns-popup-font-panel)
(define-key global-map [?\s-u] 'revert-buffer)
(define-key global-map [?\s-v] 'yank)
(define-key global-map [?\s-w] 'delete-frame)
(define-key global-map [?\s-x] 'kill-region)
(define-key global-map [?\s-z] 'undo)
(define-key global-map [?\s-|] 'shell-command-on-region)
(define-key global-map [s-kp-bar] 'shell-command-on-region)

(define-key global-map [kp-home] 'beginning-of-buffer)
(define-key global-map [kp-end] 'end-of-buffer)
(define-key global-map [kp-prior] 'scroll-down)
(define-key global-map [kp-next] 'scroll-up)

(let ((keys (ns-list-command-keys)))
  (while keys
    (define-key global-map (vector (caar keys))
      (lookup-key global-map (vconcat '[menu-bar] (cdar keys))))
    (setq keys (cdr keys))))

(x-reset-menu)

(if (and (eq (get-lisp-resource nil "NXAutoLaunch") t)
         (eq (get-lisp-resource nil "HideOnAutoLaunch") t))
     (add-hook 'after-init-hook 'do-hide-emacs))

(setq frame-creation-function 'x-create-frame-with-faces)

(if (eq (get-lisp-resource nil "Reverse") t)
    (setq default-frame-alist (cons '(reverse . t) default-frame-alist)))

(menu-bar-mode (if (get-lisp-resource nil "Menus") 1 -1))


(defconst ns-version "6.0beta1")
;; remember to change version number in man/ns-emacs.texi
(defun ns-submit-bug-report ()
   "Submit via mail a bug report on emacs 19 for OpenStep/Rhapsody."
   (interactive)
   (let ((frame-parameters (frame-parameters))
         (server-vendor (ns-server-vendor))
         (server-version (ns-server-version)))
     (reporter-submit-bug-report
      "Scott Bender <emacs@harmony-ds.com>>"
      ;;"Christian Limpach <chris@nice.ch>"
      ;;"Carl Edman <cedman@princeton.edu>"
      (concat "Emacs for OpenStep/Rhapsody " ns-version)
      '(ns-use-open-panel ns-iso-latin ns-shrink-space
        ns-cursor-blink-rate ns-alternate-is-meta data-directory
        frame-parameters window-system window-system-version server-vendor
        server-version system-configuration-options))))

(add-hook 'before-make-frame-hook
          '(lambda ()
             (let ((left (cdr (assq 'left (frame-parameters))))
                   (top (cdr (assq 'top (frame-parameters)))))
               (cond
                ((or (assq 'top parameters) (assq 'left parameters)))
                ((or (not left) (not top)))
                (t
                 (setq parameters (cons (cons 'left (+ left 25))
                                        (cons (cons 'top (+ top 25))
                                              parameters))))))))


(cond
 (ns-iso-latin
  (require 'iso-syntax)
  (standard-display-8bit 160 255))
 (t
  (require 'ns-syntax)
  (let ((l 128))
    (while (< l 160)
      (define-key global-map (vector l) 'self-insert-command)
      (setq l (+ l 1))))
  (standard-display-8bit 128 255)))


(defun ns-win-suspend-error ()
  (error "Suspending an emacs running under NS makes no sense"))
(add-hook 'suspend-hook 'ns-win-suspend-error)

;(require 'select)
;(setq interprogram-cut-function 'select-text
;      interprogram-paste-function 'cut-buffer-or-selection-value)

;;;; Pasteboard support
(defun ns-get-pasteboard ()
  "Returns the value of the pasteboard."
  (ns-get-cut-buffer-internal 'PRIMARY))

(defun ns-set-pasteboard (string)
  "Store STRING into the NS server's pasteboard."
  ;; Check the data type of STRING.
  (substring string 0 0)
  (ns-store-cut-buffer-internal 'PRIMARY string))

;;; We keep track of the last text selected here, so we can check the
;;; current selection against it, and avoid passing back our own text
;;; from ns-pasteboard-value.
(defvar ns-last-selected-text nil)

;;; Put TEXT, a string, on the pasteboard.
(defun ns-select-text (text &optional push)
  ;; Don't send the pasteboard too much text.
  ;; It becomes slow, and if really big it causes errors.
  (ns-set-pasteboard text)
  (setq ns-last-selected-text text))

;;; Return the value of the current NS selection.  For compatibility
;;; with older NS applications, this checks cut buffer 0 before
;;; retrieving the value of the primary selection.
(defun ns-pasteboard-value ()
  (let (text)
    
    ;; Consult the selection, then the cut buffer.  Treat empty strings
    ;; as if they were unset.
    (or text (setq text (ns-get-pasteboard)))
    (if (string= text "") (setq text nil))
    
    (cond
     ((not text) nil)
     ((eq text ns-last-selected-text) nil)
     ((string= text ns-last-selected-text)
      ;; Record the newer string, so subsequent calls can use the `eq' test.
      (setq ns-last-selected-text text)
      nil)
     (t
      (setq ns-last-selected-text text)))))

(setq interprogram-cut-function 'ns-select-text
      interprogram-paste-function 'ns-pasteboard-value)

;;; Return the decoded geometry specification
(defun ns-parse-geometry (geom)
  "Parse an NS-style geometry string STRING.
Returns an alist of the form ((top . TOP), (left . LEFT) ... ).
The properties returned may include `top', `left', `height', and `width'."
  (if (string-match "\\([0-9]+\\)\\( \\([0-9]+\\)\\( \\([0-9]+\\)\\( \\([0-9]+\\) ?\\)?\\)?\\)?"
                    geom)
      (apply 'append
             (list
              (list (cons 'top (string-to-int (match-string 1 geom))))
              (if (match-string 3 geom)
                  (list (cons 'left (string-to-int (match-string 3 geom)))))
              (if (match-string 5 geom)
                  (list (cons 'height (string-to-int (match-string 5 geom)))))
              (if (match-string 7 geom)
                  (list (cons 'width (string-to-int (match-string 7 geom)))))))
    '()))

;;
;; Available colors
;;

(defvar x-colors (ns-list-colors)
  "The list of colors defined in non-PANTONE color files.")
(defvar colors x-colors
  "The list of colors defined in non-PANTONE color files.")

(defun x-defined-colors (&optional frame)
  "Return a list of colors supported for a particular frame.
The argument FRAME specifies which frame to try.
The value may be different for frames on different NS displays."
  (or frame (setq frame (selected-frame)))
  (let ((all-colors x-colors)
	(this-color nil)
	(defined-colors nil))
    (while all-colors
      (setq this-color (car all-colors)
	    all-colors (cdr all-colors))
      (and (face-color-supported-p frame this-color t)
	   (setq defined-colors (cons this-color defined-colors))))
    defined-colors))
(defalias 'ns-defined-colors 'x-defined-colors)

(setq transient-mark-mode t
      highlight-nonselected-windows nil
      delete-selection-mode t
      search-highlight t
      split-window-keep-point t
      mouse-copy-selection nil
      query-replace-highlight t)

;; Don't show the frame name; that's redundant with NS.
(setq-default mode-line-buffer-identification '("Emacs: %12b"))

;; Set NS-style frame and icon titles
(setq frame-title-format t
      icon-title-format t)

;; Setup font upgrade path for user supplied default fonts
(setq ns-convert-font-trait-alist
      (list (list (ns-get-resource nil "Font")
                  (ns-get-resource nil "BoldFont")
                  (ns-get-resource nil "ItalicFont")
                  (ns-get-resource nil "Bold-ItalicFont"))))

;;; ns-win.el ends here

