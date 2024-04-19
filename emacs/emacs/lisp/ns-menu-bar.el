;;; ns-menu-bar.el --- define a default menu bar for NS users

;; Author: Carl Edman
;; Keywords: internal
;; Maintainer: Christian Limpach <chris@nice.ch>

;; Copyright (C) 1993 Free Software Foundation, Inc.

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
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

;;; Code:

(require 'cl)
(require 'ispell)

(require 'menu-bar)
;; restore the menu-bar from before menu-bar.el
(if (featurep 'menu-bar)
    (progn
      (setq menu-bar-update-hook
            (delq 'menu-bar-update-buffers menu-bar-update-hook))
      (define-key global-map [menu-bar] nil)
      (if (boundp 'ns-original-menu-bar)
          (define-key global-map [menu-bar] ns-original-menu-bar))
      (makunbound 'ns-original-menu-bar)
      (makunbound 'menu-bar-help-menu)
      (makunbound 'menu-bar-search-menu)
      (makunbound 'menu-bar-edit-menu)
      (makunbound 'menu-bar-tools-menu)
      (makunbound 'menu-bar-files-menu)
      (makunbound 'menu-bar-file-menu)
      (makunbound 'yank-menu)
      (and (= yank-menu-length 20)
           (makunbound 'yank-menu-length))
      (fmakunbound 'clipboard-yank)
      (fmakunbound 'clipboard-kill-ring-save)
      (fmakunbound 'clipboard-kill-region)
      (fmakunbound 'menu-bar-enable-clipboard)
      (fmakunbound 'menu-bar-update-buffers)
      ))
      
;; Don't clobber an existing menu-bar keymap, to preserve any menu-bar key
;; definitions made in loaddefs.el.
(or (lookup-key global-map [menu-bar])
    (define-key global-map [menu-bar] (make-sparse-keymap "menu-bar")))

(cond ((eq system-type 'apple-openstep)
      (setq menu-bar-final-items '(buffers windows services hide-app quit))
)
      ((setq menu-bar-final-items '(buffers windows services)))
)

(cond ((eq system-type 'apple-openstep)
      (define-key global-map [menu-bar quit] '("Quit" . save-buffers-kill-emacs))
      (define-key global-map [menu-bar hide-app] '("Hide" . do-hide-emacs))
))

(define-key global-map [menu-bar services] (cons "Services" (make-sparse-keymap "Services")))
(define-key global-map [menu-bar windows] (make-sparse-keymap "Windows"))
(define-key global-map [menu-bar buffers] (make-sparse-keymap "Buffers"))

(defvar menu-bar-tools-menu (make-sparse-keymap "Tools"))
(define-key global-map [menu-bar tools] (cons "Tools" menu-bar-tools-menu))

(defvar menu-bar-search-menu (make-sparse-keymap "Search"))
(define-key global-map [menu-bar search] (cons "Search" menu-bar-search-menu))

(defvar menu-bar-edit-menu (make-sparse-keymap "Edit"))
(define-key global-map [menu-bar edit] (cons "Edit" menu-bar-edit-menu))

(defvar menu-bar-files-menu (make-sparse-keymap "File"))
(define-key global-map [menu-bar files] (cons "File" menu-bar-files-menu))
;; This alias is for compatibility with 19.28 and before.
(defvar menu-bar-file-menu menu-bar-files-menu)

(defvar menu-bar-help-menu (make-sparse-keymap "Info"))
(define-key global-map [menu-bar help-menu] (cons "Info" menu-bar-help-menu))

(define-key menu-bar-tools-menu [calendar] '("Display Calendar" . calendar))
(define-key menu-bar-tools-menu [rmail] '("Read Mail" . rmail))
(define-key menu-bar-tools-menu [gnus] '("Read Net News" . gnus))

(define-key menu-bar-tools-menu [vc]
  (cons "Version Control" vc-menu-map))

(define-key menu-bar-tools-menu [epatch]
  (cons "Apply Patch" menu-bar-epatch-menu))
(define-key menu-bar-tools-menu [ediff-merge]
  (cons "Merge" menu-bar-ediff-merge-menu))
(define-key menu-bar-tools-menu [compare]
  (cons "Compare" menu-bar-ediff-menu))

(define-key menu-bar-tools-menu [ps-print-region]
  '("Postscript Print Region" . ps-print-region-with-faces))
(define-key menu-bar-tools-menu [ps-print-buffer]
  '("Postscript Print Buffer" . ps-print-buffer-with-faces))
(define-key menu-bar-tools-menu [print-region]
  '("Print Region" . print-region))
(define-key menu-bar-tools-menu [print-buffer]
  '("Print Buffer" . print-buffer))
;(define-key menu-bar-user-menu [gomoku] '("Gomoku" . gomoku))
;(define-key menu-bar-user-menu [hanoi] '("Hanoi" . hanoi))
;(define-key menu-bar-user-menu [doktor] '("Doctor" . doctor))

(cond ((eq system-type 'apple-rhapsody)
      (define-key menu-bar-files-menu [quit] 
	'("Quit" . save-buffers-kill-emacs))
))
(define-key menu-bar-files-menu [one-window]
  '("One Window" . delete-other-windows))
(define-key menu-bar-files-menu [split-window]
  '("Split Window" . split-window-vertically))
(define-key menu-bar-files-menu [kill-buffer]
  '("Kill Current Buffer" . kill-this-buffer))
(define-key menu-bar-files-menu [insert-file]
  '("Insert File..." . insert-file))
(define-key menu-bar-files-menu [revert-buffer]
  '("Revert Buffer" . revert-buffer))
(define-key menu-bar-files-menu [write-file]
  '("Save Buffer As..." . write-file))
(define-key menu-bar-files-menu [save-buffer] '("Save Buffer" . save-buffer))
(define-key menu-bar-files-menu [dired] '("Open Directory..." . dired))
(define-key menu-bar-files-menu [open-file]
  '("Open File..." . find-file-other-frame))

(define-key menu-bar-search-menu [query-replace-regexp]
  '("Query Replace Regexp..." . query-replace-regexp))
(define-key menu-bar-search-menu [query-replace]
  '("Query Replace..." . query-replace))
(define-key menu-bar-search-menu [find-tag]
  '("Find Tag..." . find-tag))
(define-key menu-bar-search-menu [bookmark]
  (cons "Bookmarks" menu-bar-bookmark-map))

(define-key menu-bar-search-menu [repeat-regexp-back]
  '("Repeat Regexp Backwards" . nonincremental-repeat-re-search-backward))
(define-key menu-bar-search-menu [repeat-search-back]
  '("Repeat Backwards" . nonincremental-repeat-search-backward))
(define-key menu-bar-search-menu [repeat-regexp-fwd]
  '("Repeat Regexp" . nonincremental-repeat-re-search-forward))
(define-key menu-bar-search-menu [repeat-search-fwd]
  '("Repeat Search" . nonincremental-repeat-search-forward))

(define-key menu-bar-search-menu [re-search-backward]
  '("Regexp Search Backwards..." . nonincremental-re-search-backward))
(define-key menu-bar-search-menu [search-backward]
  '("Search Backwards..." . nonincremental-search-backward))
(define-key menu-bar-search-menu [re-search-forward]
  '("Regexp Search..." . nonincremental-re-search-forward))
(define-key menu-bar-search-menu [search-forward]
  '("Search..." . nonincremental-search-forward))

(if (fboundp 'start-process)
    (define-key menu-bar-edit-menu [spell] '("Spell" . ispell-menu-map)))
(define-key menu-bar-edit-menu [fill] '("Fill" . fill-region))
(define-key menu-bar-edit-menu [props] (cons "Text Properties" facemenu-menu))
(define-key menu-bar-edit-menu [clear] '("Clear" . delete-region))

(defvar yank-menu (make-sparse-keymap "Select and Paste"))
(define-key menu-bar-edit-menu [select-paste]
  (cons "Select and Paste" yank-menu))
(define-key menu-bar-edit-menu [paste] '("Paste" . yank))
(define-key menu-bar-edit-menu [copy] '("Copy" . menu-bar-kill-ring-save))
(define-key menu-bar-edit-menu [cut] '("Cut" . kill-region))
(define-key menu-bar-edit-menu [undo] '("Undo" . undo))

(cond ((eq system-type 'apple-rhapsody)
      (define-key menu-bar-help-menu [hide-app] '("Hide Emacs" . do-hide-emacs))
))
(define-key menu-bar-help-menu [emacs-version]
  '("Show Version" . emacs-version))
(define-key menu-bar-help-menu [ns-bug-report]
  '("Report OpenStep/Rhapsody bug..." . ns-submit-bug-report))
(define-key menu-bar-help-menu [report-emacs-bug]
  '("Report General Emacs bug..." . report-emacs-bug))
(define-key menu-bar-help-menu [finder-by-keyword]
  '("Find Lisp Packages..." . finder-by-keyword))
(define-key menu-bar-help-menu [emacs-tutorial]
  '("Emacs Tutorial" . help-with-tutorial))
(define-key menu-bar-help-menu [emacs-faq]
  '("Emacs FAQ" . view-emacs-FAQ))
(define-key menu-bar-help-menu [emacs-news]
  '("Emacs News" . view-emacs-news))
(define-key menu-bar-help-menu [man]
  '("Man..." . manual-entry))
(define-key menu-bar-help-menu [describe-variable]
  '("Describe Variable..." . describe-variable))
(define-key menu-bar-help-menu [describe-function]
  '("Describe Function..." . describe-function))
(define-key menu-bar-help-menu [describe-key]
  '("Describe Key..." . describe-key))
(define-key menu-bar-help-menu [list-keybindings]
  '("List Keybindings" . describe-bindings))
(define-key menu-bar-help-menu [command-apropos]
  '("Command Apropos..." . command-apropos))
(define-key menu-bar-help-menu [describe-mode]
  '("Describe Mode" . describe-mode))
(define-key menu-bar-help-menu [save-preferences]
  '("Save Preferences" . ns-save-preferences))
(define-key menu-bar-help-menu [info-ns]
  '("Info about Emacs for NS" . info-ns-emacs))
(define-key menu-bar-help-menu [info] '("Browse Manuals" . info))

(defun info-ns-emacs ()         ; for the menubar as well
  "Jump to ns-emacs info item."
  (interactive)
  (info "ns-emacs"))

(defvar yank-menu-length 43
  "*Maximum length to display in the yank-menu.")

(defun menu-bar-update-yank-menu (string old)
  (let* ((front (car (cdr yank-menu)))
	 ;; build menu-string
	 ;; replace newlines by dots
	 ;; and shorten the string to yank-menu-length
	 (menu-string (if (<= (length string) (* 4 yank-menu-length))
			  string
			(concat
			 (substring string 0 (* 2 yank-menu-length))
			 (substring string (- (* 2 yank-menu-length))))))
	 (menu-string (let ((res menu-string) (pos -1))
			(while (setq pos (string-match "\n" res (1+ pos)))
			  (setq res (replace-match "." nil t res)))
			(if (string-match "\\.*$" res)
			    (setq res (replace-match "" nil t res)))))
         (menu-string (if (<= (length menu-string) yank-menu-length)
                          menu-string
                        (concat
                         (substring menu-string 0 (/ yank-menu-length 2))
                         "..."
                         (substring menu-string (- (/ yank-menu-length 2)))))))
    ;; Don't let the menu string be all dashes
    ;; because that has a special meaning in a menu.
    (if (string-match "\\`-+\\'" menu-string)
	(setq menu-string (concat menu-string " ")))
    ;; If we're supposed to be extending an existing string, and that
    ;; string really is at the front of the menu, then update it in place.
    (if (and old (or (eq old (car front))
		     (string= old (car front))))
	(progn
	  (setcar front string)
	  (setcar (cdr front) menu-string))
      (setcdr yank-menu
	      (cons
	       (cons string (cons menu-string 'menu-bar-select-yank))
	       (cdr yank-menu)))))
  (if (> (length (cdr yank-menu)) kill-ring-max)
      (setcdr (nthcdr kill-ring-max yank-menu) '("Select and Paste"))))

(defun menu-bar-select-yank ()
  (interactive "*")
  (push-mark (point))
  (insert last-command-event))

(defvar menu-bar-buffers-menu-list-buffers-entry nil)

(defun menu-bar-update-buffers ()
  ;; If user discards the Buffers item, play along.
  (and (lookup-key (current-global-map) [menu-bar buffers])
       (let* ((buffers (buffer-list))
              buffers-menu)
         ;; If requested, list only the N most recently selected buffers.
         (if (and (integerp buffers-menu-max-size)
                  (> buffers-menu-max-size 1))
             (if (> (length buffers) buffers-menu-max-size)
                 (setcdr (nthcdr buffers-menu-max-size buffers) nil)))
    
         ;; Make the menu of buffers proper.
         (setq buffers-menu
               (cons "Select Buffer"
		     (let* ((buffer-list
			     (mapcar 'list buffers))
			    tail
			    (menu-bar-update-buffers-maxbuf 0)
			    (maxlen 0)
			    alist
			    head)
		       ;; Put into each element of buffer-list
		       ;; the name for actual display,
		       ;; perhaps truncated in the middle.
		       (setq tail buffer-list)
		       (while tail
			 (let ((name (buffer-name (car (car tail)))))
			   (setcdr (car tail)
				   (if (> (length name) 27)
				       (concat (substring name 0 12)
					       "..."
					       (substring name -12))
				     name)))
			 (setq tail (cdr tail)))
		       ;; Compute the maximum length of any name.
		       (setq tail buffer-list)
		       (while tail
			 (or (eq ?\ (aref (cdr (car tail)) 0))
			     (setq menu-bar-update-buffers-maxbuf
				   (max menu-bar-update-buffers-maxbuf
					(length (cdr (car tail))))))
			 (setq tail (cdr tail)))
		       ;; Set ALIST to an alist of the form
		       ;; ITEM-STRING . BUFFER
		       (setq tail buffer-list)
		       (while tail
			 (let ((elt (car tail)))
			   (or (eq ?\ (aref (cdr elt) 0))
			       (setq alist (cons
					    (menu-bar-update-buffers-1 elt)
					    alist)))
			   (and alist (> (length (car (car alist))) maxlen)
				(setq maxlen (length (car (car alist))))))
			 (setq tail (cdr tail)))
		       (setq alist (nreverse alist))
		       ;; Make the menu item for list-buffers
		       ;; or reuse the one we already have.
		       ;; The advantage in reusing one
		       ;; is that it already has the keyboard equivalent
		       ;; cached, so we save the time to look that up again.
		       (or menu-bar-buffers-menu-list-buffers-entry
			   (setq menu-bar-buffers-menu-list-buffers-entry
				 (cons
				  'list-buffers
				  (cons
				   ""
				   'list-buffers))))
		       ;; Update the item string for menu's new width.
		       (setcar (cdr menu-bar-buffers-menu-list-buffers-entry)
			       (concat (make-string (max (- (/ maxlen 2) 8) 0)
						    ?\ )
				       "List All Buffers"))
		       ;; Now make the actual list of items,
		       ;; ending with the list-buffers item.
		       (nconc (mapcar '(lambda (pair)
					 ;; This is somewhat risque, to use
					 ;; the buffer name itself as the event
					 ;; type to define, but it works.
					 ;; It would not work to use the buffer
					 ;; since a buffer as an event has its
					 ;; own meaning.
					 (nconc (list (buffer-name (cdr pair))
						      (car pair)
						      (cons nil nil))
						'menu-bar-select-buffer))
				      alist)
			      (list menu-bar-buffers-menu-list-buffers-entry)))))
         (if buffers-menu
             (setq buffers-menu (cons 'keymap buffers-menu)))
         (define-key (current-global-map) [menu-bar buffers]
           (cons "Buffers" (or buffers-menu 'undefined))))))

(add-hook 'menu-bar-update-fab-hook 'menu-bar-update-buffers)

(defun menu-bar-select-frame ()
  (interactive)
  (make-frame-visible last-command-event)
  (raise-frame last-command-event)
  (select-frame last-command-event))

(defun menu-bar-update-frames ()
  ;; If user discard the Windows item, play along.
  (and (lookup-key (current-global-map) [menu-bar windows])
       (let ((frames (frame-list))
             (frames-menu (make-sparse-keymap "Select Frame")))
         (define-key frames-menu [popup-color-panel]
           '("Colors..." . ns-popup-color-panel))
         (define-key frames-menu [popup-font-panel]
           '("Font Panel..." . ns-popup-font-panel))
         (setcdr frames-menu
                 (nconc
                  (mapcar '(lambda (frame)
                             (nconc (list frame
                                          (cdr (assq 'name (frame-parameters frame)))
                                          (cons nil nil))
                                    'menu-bar-select-frame))
                          frames)
                  (cdr frames-menu)))
         (define-key frames-menu [arrange-all-frames]
           '("Arrange All Frames" . ns-arrange-all-frames))
         (define-key frames-menu [arrange-visible-frames]
           '("Arrange Visible Frames" . ns-arrange-visible-frames))
         ;; Don't use delete-frame as event name
         ;; because that is a special event.
         (define-key frames-menu [delete-this-frame]
           '("Delete Frame" . delete-frame))
         (define-key frames-menu [new-frame] '("New Frame" . new-frame))
         (define-key (current-global-map) [menu-bar windows]
           (cons "Windows" frames-menu)))))

(add-hook 'menu-bar-update-fab-hook 'menu-bar-update-frames)

(defun menu-bar-update-frames-and-buffers ()
  (if (frame-or-buffer-changed-p)
      (run-hooks 'menu-bar-update-fab-hook)))

(add-hook 'menu-bar-update-hook 'menu-bar-update-frames-and-buffers)

(menu-bar-update-frames-and-buffers)

;; ns-arrange functions contributed
;; by Eberhard Mandler <mandler@dbag.ulm.DaimlerBenz.COM>
(defun ns-arrange-all-frames ()
  "Arranges all frames according to topline"
  (interactive)
  (ns-arrange-frames t))

(defun ns-arrange-visible-frames ()
  "Arranges all visible frames according to topline"
  (interactive)
  (ns-arrange-frames nil))

(defun ns-arrange-frames ( vis)
  (let ((frame (next-frame))
	(end-frame (selected-frame))
	(inc-x 20)                      ;relative position of frames
	(inc-y 22)
	(x-pos 100)                     ;start position
	(y-pos 40)
	(done nil))
    (while (not done)                   ;cycle through all frames
      (if (not (or vis (eq (frame-visible-p frame) t)))
	(setq x-pos x-pos); do nothing; true case
	(set-frame-position frame x-pos y-pos)
	(setq x-pos (+ x-pos inc-x))
	(setq y-pos (+ y-pos inc-y))
	(raise-frame frame))
      (select-frame frame)
      (setq frame (next-frame))
      (setq done (equal frame end-frame)))
    (set-frame-position end-frame x-pos y-pos)
    (raise-frame frame)
    (select-frame frame)))


;;; Set up a menu bar menu for the minibuffer.
(mapcar
 (function
  (lambda (map)
    (define-key map [menu-bar minibuf]
      (cons "Minibuf" (make-sparse-keymap "Minibuf")))))
 (list minibuffer-local-ns-map
       minibuffer-local-must-match-map
       minibuffer-local-isearch-map
       minibuffer-local-map
       minibuffer-local-completion-map))

(mapcar
 (function
  (lambda (map)
    (define-key map [menu-bar minibuf ?\?]
      '("List Completions" . minibuffer-completion-help))
    (define-key map [menu-bar minibuf space]
      '("Complete Word" . minibuffer-complete-word))
    (define-key map [menu-bar minibuf tab]
      '("Complete" . minibuffer-complete))
    ))
 (list minibuffer-local-must-match-map
       minibuffer-local-completion-map))

(mapcar
 (function
  (lambda (map)
    (define-key map [menu-bar minibuf quit]
      '("Quit" . keyboard-escape-quit))
    (define-key map [menu-bar minibuf return]
      '("Enter" . exit-minibuffer))
    ))
 (list minibuffer-local-ns-map
       minibuffer-local-must-match-map
       minibuffer-local-isearch-map
       minibuffer-local-map
       minibuffer-local-completion-map))

(defconst ns-proto-call-service
  '((arg)
    (interactive "p")
    (let* ((in-string (if mark-active
                          (buffer-substring (region-beginning) (region-end))))
           (out-string (ns-perform-service service in-string)))
      (cond
       ((and out-string (or (not in-string)
                            (not (string= in-string out-string))))
        (if mark-active (delete-region (region-beginning) (region-end)))
        (insert-string out-string)
        (setq deactivate-mark nil))))))
  
(defun ns-define-service (path)
  (let ((mapping [menu-bar services])
        (service (mapconcat 'identity path "/"))
        (name (intern
               (mapconcat '(lambda (s) (if (= s 32) "-" (char-to-string s)))
                          (mapconcat 'identity (cons "ns-service" path) "-")
                          ""))))
    (eval (append (list 'defun name)
                  (subst service 'service ns-proto-call-service)))
    (cond
     ((lookup-key global-map mapping)
      (while (cdr path)
        (setq mapping (vconcat mapping (list (intern (car path)))))
        (if (not (keymapp (lookup-key global-map mapping)))
            (define-key global-map mapping
              (cons (car path) (make-sparse-keymap (car path)))))
        (setq path (cdr path)))
      (setq mapping (vconcat mapping (list (intern (car path)))))
      (define-key global-map mapping (cons (car path) name))))
    name))

(provide 'ns-menu-bar)

;;;; ns-menu-bar.el ends here
