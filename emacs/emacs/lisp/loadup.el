;;; loadup.el --- load up standardly loaded Lisp files for Emacs.

;; Copyright (C) 1985, 1986, 1992, 1994 Free Software Foundation, Inc.

;; Maintainer: FSF
;; Keywords: internal

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

;; This is loaded into a bare Emacs to make a dumpable one.

;;; Code:

(message "Using load-path %s" load-path)

;;; We don't want to have any undo records in the dumped Emacs.
(buffer-disable-undo "*scratch*")

(load "subr")

;; We specify .el in case someone compiled version.el by mistake.
(load "version.el")

(load "byte-run")
(load "map-ynp")
(load "widget")
(load "custom")
(load "cus-start")
(load "international/mule")
(load "international/mule-conf.el") ;Don't get confused if someone compiled this by mistake.
(load "bindings")
(setq load-source-file-function 'load-with-code-conversion)
(load "simple")
(load "help")
(load "files")
(load "format")
;; Any Emacs Lisp source file (*.el) loaded here after can contain
;; multilingual text.
(load "international/mule-cmds")
(load "case-table")
(load "international/characters")
(let ((set-case-syntax-set-multibyte t))
  (load "international/latin-1")
  (load "international/latin-2")
  (load "international/latin-3")
  (load "international/latin-4")
  (load "international/latin-5"))
;; Load langauge specific files.
(load "language/chinese")
(load "language/cyrillic")
(load "language/indian")
(load "language/devanagari")		; This should be loaded after indian.
(load "language/english")
(load "language/ethiopic")
(load "language/european")
(load "language/greek")
(load "language/hebrew")
(load "language/japanese")
(load "language/korean")
(load "language/lao")
(load "language/thai")
(load "language/tibetan")
(load "language/vietnamese")
(load "language/misc-lang")
(load "indent")
(load "isearch")
(load "window")
(load "frame")
(load "faces")
(if (fboundp 'frame-face-alist)
    (progn
      (load "facemenu")))
(if (fboundp 'track-mouse)
    (progn
      (load "mouse")
      (load "scroll-bar")
      (load "select")))
(load "menu-bar")
(load "paths.el")  ;Don't get confused if someone compiled paths by mistake.
(load "startup")
(load "emacs-lisp/lisp")
(load "textmodes/page")
(load "register")
(load "textmodes/paragraphs")
(load "emacs-lisp/lisp-mode")
(load "textmodes/text-mode")
(load "textmodes/fill")
(garbage-collect)
(load "replace")
(if (eq system-type 'vax-vms)
    (progn
      (load "vmsproc")))
(load "abbrev")
(load "buff-menu")
(if (eq system-type 'vax-vms)
    (progn
      (load "vms-patch")))
(if (eq system-type 'windows-nt)
    (progn
      (load "ls-lisp")
      (load "disp-table") ; needed to setup ibm-pc char set, see internal.el
      (load "dos-w32")
      (load "w32-fns")))
(if (eq system-type 'ms-dos)
    (progn
      (load "ls-lisp")
      (load "dos-w32")
      (load "dos-fns")
      (load "disp-table"))) ; needed to setup ibm-pc char set, see internal.el
(if (fboundp 'atan)	; preload some constants and 
    (progn		; floating pt. functions if we have float support.
      (load "float-sup")))
(garbage-collect)
(load "loaddefs.el")  ;Don't get confused if someone compiled this by mistake.

(garbage-collect)
(load "vc-hooks")
(load "ediff-hook")

;If you want additional libraries to be preloaded and their
;doc strings kept in the DOC file rather than in core,
;you may load them with a "site-load.el" file.
;But you must also cause them to be scanned when the DOC file
;is generated.  For VMS, you must edit ../vms/makedoc.com.
;For other systems, you must edit ../src/Makefile.in.
(if (load "site-load" t)
    (garbage-collect))

(if (fboundp 'x-popup-menu)
    (precompute-menubar-bindings))
;; Turn on recording of which commands get rebound,
;; for the sake of the next call to precompute-menubar-bindings.
(setq define-key-rebound-commands nil)

;; Determine which last version number to use
;; based on the executables that now exist.
(if (and (or (equal (nth 3 command-line-args) "dump")
	     (equal (nth 4 command-line-args) "dump"))
	 (not (eq system-type 'ms-dos)))
    (let* ((base (concat "emacs-" emacs-version "."))
	   (files (file-name-all-completions base default-directory))
	   (versions (mapcar (function (lambda (name)
					 (string-to-int (substring name (length base)))))
			     files)))
      (setq emacs-version (format "%s.%d"
				  emacs-version
				  (if versions
				      (1+ (apply 'max versions))
				    1)))))

;; Note: all compiled Lisp files loaded above this point
;; must be among the ones parsed by make-docfile
;; to construct DOC.  Any that are not processed
;; for DOC will not have doc strings in the dumped Emacs.

(message "Finding pointers to doc strings...")
(if (or (equal (nth 3 command-line-args) "dump")
	(equal (nth 4 command-line-args) "dump"))
    (let ((name emacs-version))
      (while (string-match "[^-+_.a-zA-Z0-9]+" name)
	(setq name (concat (downcase (substring name 0 (match-beginning 0)))
			   "-"
			   (substring name (match-end 0)))))
      (if (memq system-type '(ms-dos windows-nt))
	  (setq name (expand-file-name
		      (if (fboundp 'x-create-frame) "DOC-X" "DOC") "../etc"))
	(setq name (concat (expand-file-name "../etc/DOC-") name))
	(if (file-exists-p name)
	    (delete-file name))
	(copy-file (expand-file-name "../etc/DOC") name t))
      (Snarf-documentation (file-name-nondirectory name)))
    (Snarf-documentation "DOC"))
(message "Finding pointers to doc strings...done")

;Note: You can cause additional libraries to be preloaded
;by writing a site-init.el that loads them.
;See also "site-load" above.
(load "site-init" t)
(setq current-load-list nil)
(garbage-collect)

;;; At this point, we're ready to resume undo recording for scratch.
(buffer-enable-undo "*scratch*")

(if (or (equal (nth 3 command-line-args) "dump")
	(equal (nth 4 command-line-args) "dump"))
    (if (eq system-type 'vax-vms)
	(progn 
	  (message "Dumping data as file temacs.dump")
	  (dump-emacs "temacs.dump" "temacs")
	  (kill-emacs))
      (let ((name (concat "emacs-" emacs-version)))
	(while (string-match "[^-+_.a-zA-Z0-9]+" name)
	  (setq name (concat (downcase (substring name 0 (match-beginning 0)))
			     "-"
			     (substring name (match-end 0)))))
	(if (eq system-type 'ms-dos)
	    (message "Dumping under the name emacs")
	  (message "Dumping under names emacs and %s" name)))
      (condition-case ()
	  (delete-file "emacs")
	(file-error nil))
      ;; We used to dump under the name xemacs, but that occasionally
      ;; confused people installing Emacs (they'd install the file
      ;; under the name `xemacs'), and it's inconsistent with every
      ;; other GNU product's build process.
      (dump-emacs "emacs" "temacs")
      (message "%d pure bytes used" pure-bytes-used)
      ;; Recompute NAME now, so that it isn't set when we dump.
      (if (not (memq system-type '(ms-dos windows-nt)))
	  (let ((name (concat "emacs-" emacs-version)))
	    (while (string-match "[^-+_.a-zA-Z0-9]+" name)
	      (setq name (concat (downcase (substring name 0 (match-beginning 0)))
				 "-"
				 (substring name (match-end 0)))))
	    (add-name-to-file "emacs" name t)))
      (kill-emacs)))

;; Avoid error if user loads some more libraries now.
(setq purify-flag nil)

;; For machines with CANNOT_DUMP defined in config.h,
;; this file must be loaded each time Emacs is run.
;; So run the startup code now.

(or (equal (nth 3 command-line-args) "dump")
    (equal (nth 4 command-line-args) "dump")
    (progn
      ;; Avoid loading loadup.el a second time!
      (setq command-line-args (cdr (cdr command-line-args)))
      (eval top-level)))

;;; loadup.el ends here
