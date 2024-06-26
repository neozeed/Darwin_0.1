;;; gnus-ems.el --- functions for making Gnus work under different Emacsen
;; Copyright (C) 1995,96,97 Free Software Foundation, Inc.

;; Author: Lars Magne Ingebrigtsen <larsi@ifi.uio.no>
;; Keywords: news

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

;;; Code:

(eval-when-compile (require 'cl))

;;; Function aliases later to be redefined for XEmacs usage.

(defvar gnus-xemacs (string-match "XEmacs\\|Lucid" emacs-version)
  "Non-nil if running under XEmacs.")

(defvar gnus-mouse-2 [mouse-2])
(defvar gnus-down-mouse-2 [down-mouse-2])

(eval-and-compile
  (autoload 'gnus-xmas-define "gnus-xmas")
  (autoload 'gnus-xmas-redefine "gnus-xmas")
  (autoload 'appt-select-lowest-window "appt.el"))

(or (fboundp 'mail-file-babyl-p)
    (fset 'mail-file-babyl-p 'rmail-file-p))

;;; Mule functions.

(defun gnus-mule-cite-add-face (number prefix face)
  ;; At line NUMBER, ignore PREFIX and add FACE to the rest of the line.
  (when face
    (let ((inhibit-point-motion-hooks t)
	  from to)
      (goto-line number)
      (if (boundp 'MULE)
	  (forward-char (chars-in-string prefix))
	(forward-char (length prefix)))
      (skip-chars-forward " \t")
      (setq from (point))
      (end-of-line 1)
      (skip-chars-backward " \t")
      (setq to (point))
      (when (< from to)
	(gnus-overlay-put (gnus-make-overlay from to) 'face face)))))

(defun gnus-mule-max-width-function (el max-width)
  (` (let* ((val (eval (, el)))
	    (valstr (if (numberp val)
			(int-to-string val) val)))
       (if (> (length valstr) (, max-width))
	   (truncate-string valstr (, max-width))
	 valstr))))

(eval-and-compile
  (if (string-match "XEmacs\\|Lucid" emacs-version)
      nil

    (defvar gnus-mouse-face-prop 'mouse-face
      "Property used for highlighting mouse regions.")

    (defvar gnus-article-x-face-command
      "{ echo '/* Width=48, Height=48 */'; uncompface; } | icontopbm | xv -quit -"
      "String or function to be executed to display an X-Face header.
If it is a string, the command will be executed in a sub-shell
asynchronously.	 The compressed face will be piped to this command."))

  (cond
   ((string-match "XEmacs\\|Lucid" emacs-version)
    (gnus-xmas-define))

   ((or (not (boundp 'emacs-minor-version))
	(< emacs-minor-version 30))
    ;; Remove the `intangible' prop.
    (let ((props (and (boundp 'gnus-hidden-properties)
		      gnus-hidden-properties)))
      (while (and props (not (eq (car (cdr props)) 'intangible)))
	(setq props (cdr props)))
      (when props
	(setcdr props (cdr (cdr (cdr props))))))
    (unless (fboundp 'buffer-substring-no-properties)
      (defun buffer-substring-no-properties (beg end)
	(format "%s" (buffer-substring beg end)))))

   ((boundp 'MULE)
    (provide 'gnusutil))))

(eval-and-compile
  (cond
   ((not window-system)
    (defun gnus-dummy-func (&rest args))
    (let ((funcs '(mouse-set-point set-face-foreground
				   set-face-background x-popup-menu)))
      (while funcs
	(unless (fboundp (car funcs))
	  (fset (car funcs) 'gnus-dummy-func))
	(setq funcs (cdr funcs))))))
  (unless (fboundp 'file-regular-p)
    (defun file-regular-p (file)
      (and (not (file-directory-p file))
	   (not (file-symlink-p file))
	   (file-exists-p file))))
  (unless (fboundp 'face-list)
    (defun face-list (&rest args))))

(eval-and-compile
  (let ((case-fold-search t))
    (cond
     ((string-match "windows-nt\\|os/2\\|emx" (format "%s" system-type))
      (setq nnheader-file-name-translation-alist
	    (append nnheader-file-name-translation-alist
		    '((?: . ?_)
		      (?+ . ?-))))))))

(defvar gnus-tmp-unread)
(defvar gnus-tmp-replied)
(defvar gnus-tmp-score-char)
(defvar gnus-tmp-indentation)
(defvar gnus-tmp-opening-bracket)
(defvar gnus-tmp-lines)
(defvar gnus-tmp-name)
(defvar gnus-tmp-closing-bracket)
(defvar gnus-tmp-subject-or-nil)

(defun gnus-ems-redefine ()
  (cond
   ((string-match "XEmacs\\|Lucid" emacs-version)
    (gnus-xmas-redefine))

   ((featurep 'mule)
    ;; Mule and new Emacs definitions

    ;; [Note] Now there are three kinds of mule implementations,
    ;; original MULE, XEmacs/mule and beta version of Emacs including
    ;; some mule features. Unfortunately these API are different. In
    ;; particular, Emacs (including original MULE) and XEmacs are
    ;; quite different.
    ;; Predicates to check are following:
    ;; (boundp 'MULE) is t only if MULE (original; anything older than
    ;;                     Mule 2.3) is running.
    ;; (featurep 'mule) is t when every mule variants are running.

    ;; These implementations may be able to share between original
    ;; MULE and beta version of new Emacs. In addition, it is able to
    ;; detect XEmacs/mule by (featurep 'mule) and to check variable
    ;; `emacs-version'. In this case, implementation for XEmacs/mule
    ;; may be able to share between XEmacs and XEmacs/mule.

    (defalias 'gnus-truncate-string 'truncate-string)

    (defvar gnus-summary-display-table nil
      "Display table used in summary mode buffers.")
    (fset 'gnus-cite-add-face 'gnus-mule-cite-add-face)
    (fset 'gnus-max-width-function 'gnus-mule-max-width-function)
    (fset 'gnus-summary-set-display-table 'ignore)

    (when (boundp 'gnus-check-before-posting)
      (setq gnus-check-before-posting
	    (delq 'long-lines
		  (delq 'control-chars gnus-check-before-posting))))

    (defun gnus-summary-line-format-spec ()
      (insert gnus-tmp-unread gnus-tmp-replied
	      gnus-tmp-score-char gnus-tmp-indentation)
      (put-text-property
       (point)
       (progn
	 (insert
	  gnus-tmp-opening-bracket
	  (format "%4d: %-20s"
		  gnus-tmp-lines
		  (if (> (length gnus-tmp-name) 20)
		      (truncate-string gnus-tmp-name 20)
		    gnus-tmp-name))
	  gnus-tmp-closing-bracket)
	 (point))
       gnus-mouse-face-prop gnus-mouse-face)
      (insert " " gnus-tmp-subject-or-nil "\n"))
    )))

(defun gnus-region-active-p ()
  "Say whether the region is active."
  (and (boundp 'transient-mark-mode)
       transient-mark-mode
       (boundp 'mark-active)
       mark-active))

(provide 'gnus-ems)

;; Local Variables:
;; byte-compile-warnings: '(redefine callargs)
;; End:

;;; gnus-ems.el ends here
