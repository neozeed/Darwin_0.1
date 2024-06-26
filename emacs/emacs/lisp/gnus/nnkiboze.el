;;; nnkiboze.el --- select virtual news access for Gnus
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

;; The other access methods (nntp, nnspool, etc) are general news
;; access methods.  This module relies on Gnus and can't be used
;; separately.

;;; Code:

(require 'nntp)
(require 'nnheader)
(require 'gnus)
(require 'gnus-score)
(require 'nnoo)
(eval-when-compile (require 'cl))

(nnoo-declare nnkiboze)
(defvoo nnkiboze-directory (nnheader-concat gnus-directory "kiboze/")
  "nnkiboze will put its files in this directory.")

(defvoo nnkiboze-level 9
  "The maximum level to be searched for articles.")

(defvoo nnkiboze-remove-read-articles t
  "If non-nil, nnkiboze will remove read articles from the kiboze group.")

(defvoo nnkiboze-ephemeral nil
  "If non-nil, don't store any data anywhere.")

(defvoo nnkiboze-scores nil
  "Score rules for generating the nnkiboze group.")

(defvoo nnkiboze-regexp nil
  "Regexp for matching component groups.")



(defconst nnkiboze-version "nnkiboze 1.0")

(defvoo nnkiboze-current-group nil)
(defvoo nnkiboze-status-string "")

(defvoo nnkiboze-headers nil)



;;; Interface functions.

(nnoo-define-basics nnkiboze)

(deffoo nnkiboze-retrieve-headers (articles &optional group server fetch-old)
  (nnkiboze-possibly-change-group group)
  (unless gnus-nov-is-evil
    (if (stringp (car articles))
	'headers
      (let ((nov (nnkiboze-nov-file-name)))
	(when (file-exists-p nov)
	  (save-excursion
	    (set-buffer nntp-server-buffer)
	    (erase-buffer)
	    (nnheader-insert-file-contents nov)
	    (nnheader-nov-delete-outside-range
	     (car articles) (car (last articles)))
	    'nov))))))

(deffoo nnkiboze-request-article (article &optional newsgroup server buffer)
  (nnkiboze-possibly-change-group newsgroup)
  (if (not (numberp article))
      ;; This is a real kludge.  It might not work at times, but it
      ;; does no harm I think.  The only alternative is to offer no
      ;; article fetching by message-id at all.
      (nntp-request-article article newsgroup gnus-nntp-server buffer)
    (let* ((header (gnus-summary-article-header article))
	   (xref (mail-header-xref header)))
      (unless xref
	(error "nnkiboze: No xref"))
      (unless (string-match " \\([^ ]+\\):\\([0-9]+\\)" xref)
	(error "nnkiboze: Malformed xref"))
      (gnus-request-article (string-to-int (match-string 2 xref))
			    (match-string 1 xref)
			    buffer))))

(deffoo nnkiboze-request-scan (&optional group server)
  (nnkiboze-generate-group (concat "nnkiboze:" group)))

(deffoo nnkiboze-request-group (group &optional server dont-check)
  "Make GROUP the current newsgroup."
  (nnkiboze-possibly-change-group group)
  (if dont-check
      t
    (let ((nov-file (nnkiboze-nov-file-name))
	  beg end total)
      (save-excursion
	(set-buffer nntp-server-buffer)
	(erase-buffer)
	(if (not (file-exists-p nov-file))
	    (nnheader-report 'nnkiboze "Can't select group %s" group)
	  (nnheader-insert-file-contents nov-file)
	  (if (zerop (buffer-size))
	      (nnheader-insert "211 0 0 0 %s\n" group)
	    (goto-char (point-min))
	    (when (looking-at "[0-9]+")
	      (setq beg (read (current-buffer))))
	    (goto-char (point-max))
	    (when (re-search-backward "^[0-9]" nil t)
	      (setq end (read (current-buffer))))
	    (setq total (count-lines (point-min) (point-max)))
	    (nnheader-insert "211 %d %d %d %s\n" total beg end group)))))))

(deffoo nnkiboze-close-group (group &optional server)
  (nnkiboze-possibly-change-group group)
  ;; Remove NOV lines of articles that are marked as read.
  (when (and (file-exists-p (nnkiboze-nov-file-name))
	     nnkiboze-remove-read-articles)
    (nnheader-temp-write (nnkiboze-nov-file-name)
      (let ((cur (current-buffer)))
	(nnheader-insert-file-contents (nnkiboze-nov-file-name))
	(goto-char (point-min))
	(while (not (eobp))
	  (if (not (gnus-article-read-p (read cur)))
	      (forward-line 1)
	    (gnus-delete-line))))))
  (setq nnkiboze-current-group nil))

(deffoo nnkiboze-open-server (server &optional defs)
  (unless (assq 'nnkiboze-regexp defs)
    (push `(nnkiboze-regexp ,server)
	  defs))
  (nnoo-change-server 'nnkiboze server defs))

(deffoo nnkiboze-request-delete-group (group &optional force server)
  (nnkiboze-possibly-change-group group)
  (when force
     (let ((files (list (nnkiboze-nov-file-name)
			(concat nnkiboze-directory group ".newsrc")
			(nnkiboze-score-file group))))
       (while files
	 (and (file-exists-p (car files))
	      (file-writable-p (car files))
	      (delete-file (car files)))
	 (setq files (cdr files)))))
  (setq nnkiboze-current-group nil))

(nnoo-define-skeleton nnkiboze)


;;; Internal functions.

(defun nnkiboze-possibly-change-group (group)
  (setq nnkiboze-current-group group))

(defun nnkiboze-prefixed-name (group)
  (gnus-group-prefixed-name group '(nnkiboze "")))

;;;###autoload
(defun nnkiboze-generate-groups ()
  "Usage: emacs -batch -l nnkiboze -f nnkiboze-generate-groups
Finds out what articles are to be part of the nnkiboze groups."
  (interactive)
  (let ((nnmail-spool-file nil)
	(gnus-use-dribble-file nil)
	(gnus-read-active-file t)
	(gnus-expert-user t))
    (gnus))
  (let* ((gnus-newsrc-alist (gnus-copy-sequence gnus-newsrc-alist))
	 (newsrc (cdr gnus-newsrc-alist))
	 gnus-newsrc-hashtb info)
    (gnus-make-hashtable-from-newsrc-alist)
    ;; We have copied all the newsrc alist info over to local copies
    ;; so that we can mess all we want with these lists.
    (while (setq info (pop newsrc))
      (when (string-match "nnkiboze" (gnus-info-group info))
	;; For each kiboze group, we call this function to generate
	;; it.
	(nnkiboze-generate-group (gnus-info-group info))))))

(defun nnkiboze-score-file (group)
  (list (expand-file-name
	 (concat (file-name-as-directory gnus-kill-files-directory)
		 (nnheader-translate-file-chars
		  (concat (nnkiboze-prefixed-name nnkiboze-current-group)
			  "." gnus-score-file-suffix))))))

(defun nnkiboze-generate-group (group)
  (let* ((info (nth 2 (gnus-gethash group gnus-newsrc-hashtb)))
	 (newsrc-file (concat nnkiboze-directory group ".newsrc"))
	 (nov-file (concat nnkiboze-directory group ".nov"))
	 method nnkiboze-newsrc gname newsrc active
	 ginfo lowest glevel orig-info nov-buffer
	 ;; Bind various things to nil to make group entry faster.
	 (gnus-expert-user t)
	 (gnus-large-newsgroup nil)
	 (gnus-score-find-score-files-function 'nnkiboze-score-file)
	 (gnus-verbose (min gnus-verbose 3))
 	 gnus-select-group-hook gnus-summary-prepare-hook
	 gnus-thread-sort-functions gnus-show-threads
	 gnus-visual gnus-suppress-duplicates)
    (unless info
      (error "No such group: %s" group))
    ;; Load the kiboze newsrc file for this group.
    (when (file-exists-p newsrc-file)
      (load newsrc-file))
    (nnheader-temp-write nov-file
      (when (file-exists-p nov-file)
	(insert-file-contents nov-file))
      (setq nov-buffer (current-buffer))
      ;; Go through the active hashtb and add new all groups that match the
      ;; kiboze regexp.
      (mapatoms
       (lambda (group)
	 (and (string-match nnkiboze-regexp
			    (setq gname (symbol-name group))) ; Match
	      (not (assoc gname nnkiboze-newsrc)) ; It isn't registered
	      (numberp (car (symbol-value group))) ; It is active
	      (or (> nnkiboze-level 7)
		  (and (setq glevel (nth 1 (nth 2 (gnus-gethash
						   gname gnus-newsrc-hashtb))))
		       (>= nnkiboze-level glevel)))
	      (not (string-match "^nnkiboze:" gname)) ; Exclude kibozes
	      (push (cons gname (1- (car (symbol-value group))))
		    nnkiboze-newsrc)))
       gnus-active-hashtb)
      ;; `newsrc' is set to the list of groups that possibly are
      ;; component groups to this kiboze group.  This list has elements
      ;; on the form `(GROUP . NUMBER)', where NUMBER is the highest
      ;; number that has been kibozed in GROUP in this kiboze group.
      (setq newsrc nnkiboze-newsrc)
      (while newsrc
	(if (not (setq active (gnus-gethash
			       (caar newsrc) gnus-active-hashtb)))
	    ;; This group isn't active after all, so we remove it from
	    ;; the list of component groups.
	    (setq nnkiboze-newsrc (delq (car newsrc) nnkiboze-newsrc))
	  (setq lowest (cdar newsrc))
	  ;; Ok, we have a valid component group, so we jump to it.
	  (switch-to-buffer gnus-group-buffer)
	  (gnus-group-jump-to-group (caar newsrc))
	  (gnus-message 3 "nnkiboze: Checking %s..." (caar newsrc))
	  (setq ginfo (gnus-get-info (gnus-group-group-name))
		orig-info (gnus-copy-sequence ginfo))
	  (unwind-protect
	      (progn
		;; We set all list of article marks to nil.  Since we operate
		;; on copies of the real lists, we can destroy anything we
		;; want here.
		(when (nth 3 ginfo)
		  (setcar (nthcdr 3 ginfo) nil))
		;; We set the list of read articles to be what we expect for
		;; this kiboze group -- either nil or `(1 . LOWEST)'.
		(when ginfo
		  (setcar (nthcdr 2 ginfo)
			  (and (not (= lowest 1)) (cons 1 lowest))))
		(when (and (or (not ginfo)
			       (> (length (gnus-list-of-unread-articles
					   (car ginfo)))
				  0))
			   (progn
			     (gnus-group-select-group nil)
			     (eq major-mode 'gnus-summary-mode)))
		  ;; We are now in the group where we want to be.
		  (setq method (gnus-find-method-for-group
				gnus-newsgroup-name))
		  (when (eq method gnus-select-method)
		    (setq method nil))
		  ;; We go through the list of scored articles.
		  (while gnus-newsgroup-scored
		    (when (> (caar gnus-newsgroup-scored) lowest)
		      ;; If it has a good score, then we enter this article
		      ;; into the kiboze group.
		      (nnkiboze-enter-nov
		       nov-buffer
		       (gnus-summary-article-header
			(caar gnus-newsgroup-scored))
		       gnus-newsgroup-name))
		    (setq gnus-newsgroup-scored (cdr gnus-newsgroup-scored)))
		  ;; That's it.  We exit this group.
		  (gnus-summary-exit-no-update)))
	    ;; Restore the proper info.
	    (when ginfo
	      (setcdr ginfo (cdr orig-info)))))
	(setcdr (car newsrc) (car active))
	(gnus-message 3 "nnkiboze: Checking %s...done" (caar newsrc))
	(setq newsrc (cdr newsrc))))
    ;; We save the kiboze newsrc for this group.
    (nnheader-temp-write newsrc-file
      (insert "(setq nnkiboze-newsrc '")
      (gnus-prin1 nnkiboze-newsrc)
      (insert ")\n"))
    t))

(defun nnkiboze-enter-nov (buffer header group)
  (save-excursion
    (set-buffer buffer)
    (goto-char (point-max))
    (let ((xref (mail-header-xref header))
	  (prefix (gnus-group-real-prefix group))
	  (oheader (copy-sequence header))
	  (first t)
	  article)
      (if (zerop (forward-line -1))
	  (progn
	    (setq article (1+ (read (current-buffer))))
	    (forward-line 1))
	(setq article 1))
      (mail-header-set-number oheader article)
      (nnheader-insert-nov oheader)
      (search-backward "\t" nil t 2)
      (if (re-search-forward " [^ ]+:[0-9]+" nil t)
	  (goto-char (match-beginning 0))
	(forward-char 1))
      ;; The first Xref has to be the group this article
      ;; really came for - this is the article nnkiboze
      ;; will request when it is asked for the article.
      (insert group ":"
	      (int-to-string (mail-header-number header)) " ")
      (while (re-search-forward " [^ ]+:[0-9]+" nil t)
	(goto-char (1+ (match-beginning 0)))
	(insert prefix)))))

(defun nnkiboze-nov-file-name ()
  (concat (file-name-as-directory nnkiboze-directory)
	  (nnheader-translate-file-chars
	   (concat (nnkiboze-prefixed-name nnkiboze-current-group) ".nov"))))

(provide 'nnkiboze)

;;; nnkiboze.el ends here
