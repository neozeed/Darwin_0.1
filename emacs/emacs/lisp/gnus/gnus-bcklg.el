;;; gnus-bcklg.el --- backlog functions for Gnus
;; Copyright (C) 1996,97 Free Software Foundation, Inc.

;; Author: Lars Magne Ingebrigtsen <larsi@ifi.uio.no>
;; Keywords: news

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;;; Code:

(eval-when-compile (require 'cl))

(require 'gnus)

;;;
;;; Buffering of read articles.
;;;

(defvar gnus-backlog-buffer " *Gnus Backlog*")
(defvar gnus-backlog-articles nil)
(defvar gnus-backlog-hashtb nil)

(defun gnus-backlog-buffer ()
  "Return the backlog buffer."
  (or (get-buffer gnus-backlog-buffer)
      (save-excursion
	(set-buffer (get-buffer-create gnus-backlog-buffer))
	(buffer-disable-undo (current-buffer))
	(setq buffer-read-only t)
	(gnus-add-current-to-buffer-list)
	(get-buffer gnus-backlog-buffer))))

(defun gnus-backlog-setup ()
  "Initialize backlog variables."
  (unless gnus-backlog-hashtb
    (setq gnus-backlog-hashtb (gnus-make-hashtable 1024))))

(gnus-add-shutdown 'gnus-backlog-shutdown 'gnus)

(defun gnus-backlog-shutdown ()
  "Clear all backlog variables and buffers."
  (when (get-buffer gnus-backlog-buffer)
    (kill-buffer gnus-backlog-buffer))
  (setq gnus-backlog-hashtb nil
	gnus-backlog-articles nil))

(defun gnus-backlog-enter-article (group number buffer)
  (gnus-backlog-setup)
  (let ((ident (intern (concat group ":" (int-to-string number))
		       gnus-backlog-hashtb))
	b)
    (if (memq ident gnus-backlog-articles)
	()				; It's already kept.
      ;; Remove the oldest article, if necessary.
      (and (numberp gnus-keep-backlog)
	   (>= (length gnus-backlog-articles) gnus-keep-backlog)
	   (gnus-backlog-remove-oldest-article))
      (push ident gnus-backlog-articles)
      ;; Insert the new article.
      (save-excursion
	(set-buffer (gnus-backlog-buffer))
	(let (buffer-read-only)
	  (goto-char (point-max))
	  (unless (bolp)
	    (insert "\n"))
	  (setq b (point))
	  (insert-buffer-substring buffer)
	  ;; Tag the beginning of the article with the ident.
	  (gnus-put-text-property b (1+ b) 'gnus-backlog ident))))))

(defun gnus-backlog-remove-oldest-article ()
  (save-excursion
    (set-buffer (gnus-backlog-buffer))
    (goto-char (point-min))
    (if (zerop (buffer-size))
	()				; The buffer is empty.
      (let ((ident (get-text-property (point) 'gnus-backlog))
	    buffer-read-only)
	;; Remove the ident from the list of articles.
	(when ident
	  (setq gnus-backlog-articles (delq ident gnus-backlog-articles)))
	;; Delete the article itself.
	(delete-region
	 (point) (next-single-property-change
		  (1+ (point)) 'gnus-backlog nil (point-max)))))))

(defun gnus-backlog-remove-article (group number)
  "Remove article NUMBER in GROUP from the backlog."
  (when (numberp number)
    (gnus-backlog-setup)
    (let ((ident (intern (concat group ":" (int-to-string number))
			 gnus-backlog-hashtb))
	  beg end)
      (when (memq ident gnus-backlog-articles)
	;; It was in the backlog.
	(save-excursion
	  (set-buffer (gnus-backlog-buffer))
	  (let (buffer-read-only)
	    (when (setq beg (text-property-any
			     (point-min) (point-max) 'gnus-backlog
			     ident))
	      ;; Find the end (i. e., the beginning of the next article).
	      (setq end
		    (next-single-property-change
		     (1+ beg) 'gnus-backlog (current-buffer) (point-max)))
	      (delete-region beg end)
	      ;; Return success.
	      t)))))))

(defun gnus-backlog-request-article (group number buffer)
  (when (numberp number)
    (gnus-backlog-setup)
    (let ((ident (intern (concat group ":" (int-to-string number))
			 gnus-backlog-hashtb))
	  beg end)
      (when (memq ident gnus-backlog-articles)
	;; It was in the backlog.
	(save-excursion
	  (set-buffer (gnus-backlog-buffer))
	  (if (not (setq beg (text-property-any
			      (point-min) (point-max) 'gnus-backlog
			      ident)))
	      ;; It wasn't in the backlog after all.
	      (ignore
	       (setq gnus-backlog-articles (delq ident gnus-backlog-articles)))
	    ;; Find the end (i. e., the beginning of the next article).
	    (setq end
		  (next-single-property-change
		   (1+ beg) 'gnus-backlog (current-buffer) (point-max)))))
	(let ((buffer-read-only nil))
	  (erase-buffer)
	  (insert-buffer-substring gnus-backlog-buffer beg end)
	  t)))))

(provide 'gnus-bcklg)

;;; gnus-bcklg.el ends here
