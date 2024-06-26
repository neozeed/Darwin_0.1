;;; sendmail.el --- mail sending commands for Emacs.

;; Copyright (C) 1985, 86, 92, 93, 94, 95, 96 Free Software Foundation, Inc.

;; Maintainer: FSF
;; Keywords: mail

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

;; This mode provides mail-sending facilities from within Emacs.  It is
;; documented in the Emacs user's manual.

;;; Code:

;;;###autoload
(defvar mail-from-style 'angles "\
*Specifies how \"From:\" fields look.

If `nil', they contain just the return address like:
	king@grassland.com
If `parens', they look like:
	king@grassland.com (Elvis Parsley)
If `angles', they look like:
	Elvis Parsley <king@grassland.com>")

;;;###autoload
(defvar mail-self-blind nil "\
*Non-nil means insert BCC to self in messages to be sent.
This is done when the message is initialized,
so you can remove or alter the BCC field to override the default.")

;;;###autoload
(defvar mail-interactive nil "\
*Non-nil means when sending a message wait for and display errors.
nil means let mailer mail back a message to report errors.")

;;;###autoload
(defvar mail-yank-ignored-headers "^via:\\|^mail-from:\\|^origin:\\|^status:\\|^remailed\\|^received:\\|^message-id:\\|^summary-line:\\|^to:\\|^subject:\\|^in-reply-to:\\|^return-path:" "\
*Delete these headers from old message when it's inserted in a reply.")

;; Useful to set in site-init.el
;;;###autoload
(defvar send-mail-function 'sendmail-send-it "\
Function to call to send the current buffer as mail.
The headers should be delimited by a line whose contents
match the variable `mail-header-separator'.")

;;;###autoload
(defvar mail-header-separator "--text follows this line--" "\
*Line used to separate headers from text in messages being composed.")

;; Set up mail-header-separator for use as a category text property.
(put 'mail-header-separator 'rear-nonsticky '(category))
;;; This was a nice idea, for preventing accidental modification of
;;; the separator.   But I found it also prevented or obstructed
;;; certain deliberate operations, such as copying the separator line
;;; up to the top to send myself a copy of an already sent outgoing message
;;; and other things.  So I turned it off.  --rms.
;;;(put 'mail-header-separator 'read-only t)

;;;###autoload
(defvar mail-archive-file-name nil "\
*Name of file to write all outgoing messages in, or nil for none.
This can be an inbox file or an Rmail file.")

;;;###autoload
(defvar mail-default-reply-to nil
  "*Address to insert as default Reply-to field of outgoing messages.
If nil, it will be initialized from the REPLYTO environment variable
when you first send mail.")

;;;###autoload
(defvar mail-alias-file nil
  "*If non-nil, the name of a file to use instead of `/usr/lib/aliases'.
This file defines aliases to be expanded by the mailer; this is a different
feature from that of defining aliases in `.mailrc' to be expanded in Emacs.
This variable has no effect unless your system uses sendmail as its mailer.")

;;;###autoload
(defvar mail-personal-alias-file "~/.mailrc"
  "*If non-nil, the name of the user's personal mail alias file.
This file typically should be in same format as the `.mailrc' file used by
the `Mail' or `mailx' program.
This file need not actually exist.")

(defvar mail-setup-hook nil
  "Normal hook, run each time a new outgoing mail message is initialized.
The function `mail-setup' runs this hook.")

(defvar mail-aliases t
  "Alist of mail address aliases,
or t meaning should be initialized from your mail aliases file.
\(The file's name is normally `~/.mailrc', but your MAILRC environment
variable can override that name.)
The alias definitions in the file have this form:
    alias ALIAS MEANING")

(defvar mail-alias-modtime nil
  "The modification time of your mail alias file when it was last examined.")

(defvar mail-yank-prefix nil
  "*Prefix insert on lines of yanked message being replied to.
nil means use indentation.")
(defvar mail-indentation-spaces 3
  "*Number of spaces to insert at the beginning of each cited line.
Used by `mail-yank-original' via `mail-indent-citation'.")
(defvar mail-yank-hooks nil
  "Obsolete hook for modifying a citation just inserted in the mail buffer.
Each hook function can find the citation between (point) and (mark t).
And each hook function should leave point and mark around the citation
text as modified.

This is a normal hook, misnamed for historical reasons.
It is semi-obsolete and mail agents should no longer use it.")

(defvar mail-citation-hook nil
  "*Hook for modifying a citation just inserted in the mail buffer.
Each hook function can find the citation between (point) and (mark t).
And each hook function should leave point and mark around the citation
text as modified.

If this hook is entirely empty (nil), a default action is taken
instead of no action.")

(defvar mail-abbrevs-loaded nil)
(defvar mail-mode-map nil)

(autoload 'build-mail-aliases "mailalias"
  "Read mail aliases from user's personal aliases file and set `mail-aliases'."
  nil)

(autoload 'expand-mail-aliases "mailalias"
  "Expand all mail aliases in suitable header fields found between BEG and END.
Suitable header fields are `To', `Cc' and `Bcc' and their `Resent-' variants.
Optional second arg EXCLUDE may be a regular expression defining text to be
removed from alias expansions."
  nil)

;;;###autoload
(defvar mail-signature nil
  "*Text inserted at end of mail buffer when a message is initialized.
If t, it means to insert the contents of the file `mail-signature-file'.")

(defvar mail-signature-file "~/.signature"
  "*File containing the text inserted at end of mail buffer.")

(defvar mail-reply-action nil)
(defvar mail-send-actions nil
  "A list of actions to be performed upon successful sending of a message.")
(put 'mail-reply-action 'permanent-local t)
(put 'mail-send-actions 'permanent-local t)

(defvar mail-default-headers nil
  "*A string containing header lines, to be inserted in outgoing messages.
It is inserted before you edit the message,
so you can edit or delete these lines.")

(defvar mail-bury-selects-summary t
  "*If non-nil, try to show RMAIL summary buffer after returning from mail.
The functions \\[mail-send-on-exit] or \\[mail-dont-send] select
the RMAIL summary buffer before returning, if it exists and this variable
is non-nil.")

;; I find that this happens so often, for innocent reasons,
;; that it is not acceptable to bother the user about it -- rms.
(defvar mail-send-nonascii t
  "*Specify whether to allow sending non-ASCII characters in mail.
If t, that means do allow it.  nil means don't allow it.
`query' means ask the user each time.
Including non-ASCII characters in a mail message can be problematical
for the recipient, who may not know how to decode them properly.")

;; Note: could use /usr/ucb/mail instead of sendmail;
;; options -t, and -v if not interactive.
(defvar mail-mailer-swallows-blank-line
  (if (and (string-match "sparc-sun-sunos\\(\\'\\|[^5]\\)" system-configuration)
	   (file-readable-p "/etc/sendmail.cf")
	   (let ((buffer (get-buffer-create " *temp*")))
	     (unwind-protect
		 (save-excursion
		   (set-buffer buffer)
		   (insert-file-contents "/etc/sendmail.cf")
		   (goto-char (point-min))
		   (let ((case-fold-search nil))
		     (re-search-forward "^OR\\>" nil t)))
	       (kill-buffer buffer))))
      ;; According to RFC822, "The field-name must be composed of printable
      ;; ASCII characters (i.e. characters that have decimal values between
      ;; 33 and 126, except colon)", i.e. any chars except ctl chars,
      ;; space, or colon.
      '(looking-at "[ \t]\\|[][!\"#$%&'()*+,-./0-9;<=>?@A-Z\\\\^_`a-z{|}~]+:"))
  "Set this non-nil if the system's mailer runs the header and body together.
\(This problem exists on Sunos 4 when sendmail is run in remote mode.)
The value should be an expression to test whether the problem will
actually occur.")

(defvar mail-mode-syntax-table nil
  "Syntax table used while in mail mode.")

(if (not mail-mode-syntax-table)
    (progn
     (setq mail-mode-syntax-table (copy-syntax-table text-mode-syntax-table))
     (modify-syntax-entry ?% ". " mail-mode-syntax-table)))

(defvar mail-font-lock-keywords
  (eval-when-compile
    (let* ((cite-chars "[>|}]")
	   (cite-prefix "A-Za-z")
	   (cite-suffix (concat cite-prefix "0-9_.@-`'\"")))
      (list '("^\\(To\\|Newsgroups\\):" . font-lock-function-name-face)
	    '("^\\(B?CC\\|Reply-to\\):" . font-lock-keyword-face)
	    '("^\\(Subject:\\)[ \t]*\\(.+\\)?"
	      (1 font-lock-comment-face) (2 font-lock-type-face nil t))
	    ;; Use EVAL to delay in case `mail-header-separator' gets changed.
	    '(eval .
	      (cons (concat "^" (regexp-quote mail-header-separator) "$")
		    'font-lock-warning-face))
	    ;; Use MATCH-ANCHORED to effectively anchor the regexp left side.
	    `(,cite-chars
	      (,(concat "\\=[ \t]*"
			"\\(\\([" cite-prefix "]+[" cite-suffix "]*\\)?"
			"\\(" cite-chars "[ \t]*\\)\\)+"
			"\\(.*\\)")
	       (beginning-of-line) (end-of-line)
	       (2 font-lock-reference-face nil t)
	       (4 font-lock-comment-face nil t)))
	    '("^\\(X-[A-Za-z0-9-]+\\|In-reply-to\\):.*"
	      . font-lock-string-face))))
  "Additional expressions to highlight in Mail mode.")

(defvar mail-send-hook nil
  "Normal hook run before sending mail, in Mail mode.")

(defun sendmail-sync-aliases ()
  (let ((modtime (nth 5 (file-attributes mail-personal-alias-file))))
    (or (equal mail-alias-modtime modtime)
	(setq mail-alias-modtime modtime
	      mail-aliases t))))

(defun mail-setup (to subject in-reply-to cc replybuffer actions)
  (or mail-default-reply-to
      (setq mail-default-reply-to (getenv "REPLYTO")))
  (sendmail-sync-aliases)
  (if (eq mail-aliases t)
      (progn
	(setq mail-aliases nil)
	(if (file-exists-p mail-personal-alias-file)
	    (build-mail-aliases))))
  ;; Don't leave this around from a previous message.
  (kill-local-variable 'buffer-file-coding-system)
  (kill-local-variable 'enable-multibyte-characters)
  (if current-input-method
      (inactivate-input-method))
  (setq mail-send-actions actions)
  (setq mail-reply-action replybuffer)
  (goto-char (point-min))
  (insert "To: ")
  (save-excursion
    (if to
	;; Here removed code to extract names from within <...>
	;; on the assumption that mail-strip-quoted-names
	;; has been called and has done so.
	(let ((fill-prefix "\t")
	      (address-start (point)))
	  (insert to "\n")
	  (fill-region-as-paragraph address-start (point-max)))
      (newline))
    (if cc
	(let ((fill-prefix "\t")
	      (address-start (progn (insert "CC: ") (point))))
	  (insert cc "\n")
	  (fill-region-as-paragraph address-start (point-max))))
    (if in-reply-to
        (let ((fill-prefix "\t")
	      (fill-column 78)
	      (address-start (point)))
	  (insert "In-reply-to: " in-reply-to "\n")
	  (fill-region-as-paragraph address-start (point-max))))
    (insert "Subject: " (or subject "") "\n")
    (if mail-default-headers
	(insert mail-default-headers))
    (if mail-default-reply-to
	(insert "Reply-to: " mail-default-reply-to "\n"))
    (if mail-self-blind
	(insert "BCC: " user-mail-address "\n"))
    (if mail-archive-file-name
	(insert "FCC: " mail-archive-file-name "\n"))
    (put-text-property (point)
		       (progn
			 (insert mail-header-separator "\n")
			 (1- (point)))
		       'category 'mail-header-separator)
    ;; Insert the signature.  But remember the beginning of the message.
    (if to (setq to (point)))
    (cond ((eq mail-signature t)
	   (if (file-exists-p mail-signature-file)
	       (progn
		 (insert "\n\n-- \n")
		 (insert-file-contents mail-signature-file))))
	  (mail-signature
	   (insert mail-signature)))
    (goto-char (point-max))
    (or (bolp) (newline)))
  (if to (goto-char to))
  (or to subject in-reply-to
      (set-buffer-modified-p nil))
  (run-hooks 'mail-setup-hook))

;;;###autoload
(defun mail-mode ()
  "Major mode for editing mail to be sent.
Like Text Mode but with these additional commands:
C-c C-s  mail-send (send the message)    C-c C-c  mail-send-and-exit
C-c C-f  move to a header field (and create it if there isn't):
	 C-c C-f C-t  move to To:	C-c C-f C-s  move to Subject:
	 C-c C-f C-c  move to CC:	C-c C-f C-b  move to BCC:
	 C-c C-f C-f  move to FCC:
C-c C-t  mail-text (move to beginning of message text).
C-c C-w  mail-signature (insert `mail-signature-file' file).
C-c C-y  mail-yank-original (insert current message, in Rmail).
C-c C-q  mail-fill-yanked-message (fill what was yanked).
C-c C-v  mail-sent-via (add a Sent-via field for each To or CC)."
  (interactive)
  (kill-all-local-variables)
  (make-local-variable 'mail-reply-action)
  (make-local-variable 'mail-send-actions)
  (set-syntax-table mail-mode-syntax-table)
  (use-local-map mail-mode-map)
  (setq local-abbrev-table text-mode-abbrev-table)
  (setq major-mode 'mail-mode)
  (setq mode-name "Mail")
  (setq buffer-offer-save t)
  (make-local-variable 'font-lock-defaults)
  (setq font-lock-defaults '(mail-font-lock-keywords t))
  (make-local-variable 'paragraph-separate)
  (make-local-variable 'paragraph-start)
  (make-local-variable 'normal-auto-fill-function)
  (setq normal-auto-fill-function 'mail-mode-auto-fill)
  (make-local-variable 'fill-paragraph-function)
  (setq fill-paragraph-function 'mail-mode-fill-paragraph)
  (make-local-variable 'adaptive-fill-regexp)
  (setq adaptive-fill-regexp
	(concat "[ \t]*[-a-z0-9A-Z]*>+[ \t]*\\|" adaptive-fill-regexp))
  (make-local-variable 'adaptive-fill-first-line-regexp)
  (setq adaptive-fill-first-line-regexp
	(concat "[ \t]*[-a-z0-9A-Z]*>+[ \t]*\\|" adaptive-fill-first-line-regexp))
  ;; `-- ' precedes the signature.  `-----' appears at the start of the
  ;; lines that delimit forwarded messages.
  ;; Lines containing just >= 3 dashes, perhaps after whitespace,
  ;; are also sometimes used and should be separators.
  (setq paragraph-start (concat (regexp-quote mail-header-separator)
				"$\\|[ \t]*[a-z0-9A-Z]*>+[ \t]*$\\|[ \t]*$\\|"
				page-delimiter))
  (setq paragraph-separate paragraph-start)
  (run-hooks 'text-mode-hook 'mail-mode-hook))

(defun mail-mode-auto-fill ()
  "Carry out Auto Fill for Mail mode.
If within the headers, this makes the new lines into continuation lines."
  (if (< (point)
	 (save-excursion
	   (goto-char (point-min))
	   (if (re-search-forward
		(concat "^" (regexp-quote mail-header-separator) "$")
		nil t)
	       (point)
	     0)))
      (let ((old-line-start (save-excursion (beginning-of-line) (point))))
	(if (do-auto-fill)
	    (save-excursion
	      (beginning-of-line)
	      (while (not (eq (point) old-line-start))
		;; Use insert-before-markers in case we're inserting
		;; before the saved value of point (which is common).
		(insert-before-markers "   ")
		(forward-line -1))
	      t)))
    (do-auto-fill)))

(defun mail-mode-fill-paragraph (arg)
  ;; Do something special only if within the headers.
  (if (< (point)
	 (save-excursion
	   (goto-char (point-min))
	   (if (re-search-forward
		(concat "^" (regexp-quote mail-header-separator) "$")
		nil t)
	       (point)
	     0)))
      (let (beg end fieldname) 
	(re-search-backward "^[-a-zA-Z]+:" nil 'yes)
	(setq beg (point))
	(setq fieldname
	      (downcase (buffer-substring beg (1- (match-end 0)))))
	(forward-line 1)
	;; Find continuation lines and get rid of their continuation markers.
	(while (looking-at "[ \t]")
	  (delete-horizontal-space)
	  (forward-line 1))
	(setq end (point-marker))
	(goto-char beg)
	;; If this field contains addresses,
	;; make sure we can fill after each address.
	(if (member fieldname
		    '("to" "cc" "bcc" "from" "reply-to"
		      "resent-to" "resent-cc" "resent-bcc"
		      "resent-from" "resent-reply-to"))
	    (while (search-forward "," end t)
	      (or (looking-at "[ \t]")
		  (insert " "))))
	(fill-region-as-paragraph beg end)
	;; Mark all lines except the first as continuations.
	(goto-char beg)
	(forward-line 1)
	(while (< (point) end)
	  (insert "  ")
	  (forward-line 1))
	(move-marker end nil)
	t)))

;;; Set up keymap.

(if mail-mode-map
    nil
  (setq mail-mode-map (nconc (make-sparse-keymap) text-mode-map))
  (define-key mail-mode-map "\M-\t" 'mail-complete)
  (define-key mail-mode-map "\C-c?" 'describe-mode)
  (define-key mail-mode-map "\C-c\C-f\C-t" 'mail-to)
  (define-key mail-mode-map "\C-c\C-f\C-b" 'mail-bcc)
  (define-key mail-mode-map "\C-c\C-f\C-f" 'mail-fcc)
  (define-key mail-mode-map "\C-c\C-f\C-c" 'mail-cc)
  (define-key mail-mode-map "\C-c\C-f\C-s" 'mail-subject)
  (define-key mail-mode-map "\C-c\C-f\C-r" 'mail-reply-to)
  (define-key mail-mode-map "\C-c\C-t" 'mail-text)
  (define-key mail-mode-map "\C-c\C-y" 'mail-yank-original)
  (define-key mail-mode-map "\C-c\C-r" 'mail-yank-region)
  (define-key mail-mode-map "\C-c\C-q" 'mail-fill-yanked-message)
  (define-key mail-mode-map "\C-c\C-w" 'mail-signature)
  (define-key mail-mode-map "\C-c\C-v" 'mail-sent-via)
  (define-key mail-mode-map "\C-c\C-c" 'mail-send-and-exit)
  (define-key mail-mode-map "\C-c\C-s" 'mail-send)
  (define-key mail-mode-map "\C-c\C-i" 'mail-attach-file))

(define-key mail-mode-map [menu-bar mail]
  (cons "Mail" (make-sparse-keymap "Mail")))

(define-key mail-mode-map [menu-bar mail fill]
  '("Fill Citation" . mail-fill-yanked-message))

(define-key mail-mode-map [menu-bar mail yank]
  '("Cite Original" . mail-yank-original))

(define-key mail-mode-map [menu-bar mail signature]
  '("Insert Signature" . mail-signature))

(define-key mail-mode-map [menu-bar mail mail-sep]
  '("--"))

(define-key mail-mode-map [menu-bar mail cancel]
  '("Cancel" . mail-dont-send))

(define-key mail-mode-map [menu-bar mail send-stay]
  '("Send, Keep Editing" . mail-send))

(define-key mail-mode-map [menu-bar mail send]
  '("Send Message" . mail-send-and-exit))

(define-key mail-mode-map [menu-bar headers]
  (cons "Headers" (make-sparse-keymap "Move to Header")))

(define-key mail-mode-map [menu-bar headers text]
  '("Text" . mail-text))

(define-key mail-mode-map [menu-bar headers expand-aliases]
  '("Expand Aliases" . expand-mail-aliases))

(define-key mail-mode-map [menu-bar headers sent-via]
  '("Sent Via" . mail-sent-via))

(define-key mail-mode-map [menu-bar headers reply-to]
  '("Reply-To" . mail-reply-to))

(define-key mail-mode-map [menu-bar headers bcc]
  '("Bcc" . mail-bcc))

(define-key mail-mode-map [menu-bar headers fcc]
  '("Fcc" . mail-fcc))

(define-key mail-mode-map [menu-bar headers cc]
  '("Cc" . mail-cc))

(define-key mail-mode-map [menu-bar headers subject]
  '("Subject" . mail-subject))

(define-key mail-mode-map [menu-bar headers to]
  '("To" . mail-to))

;; User-level commands for sending.

(defun mail-send-and-exit (arg)
  "Send message like `mail-send', then, if no errors, exit from mail buffer.
Prefix arg means don't delete this window."
  (interactive "P")
  (mail-send)
  (mail-bury arg))

(defun mail-dont-send (arg)
  "Don't send the message you have been editing.
Prefix arg means don't delete this window."
  (interactive "P")
  (mail-bury arg))

(defun mail-bury (arg)
  "Bury this mail buffer."
  (let ((newbuf (other-buffer (current-buffer))))
    (bury-buffer (current-buffer))
    (if (and (or (window-dedicated-p (frame-selected-window))
		 (assq 'mail-dedicated-frame (frame-parameters)))
	     (not (null (delq (selected-frame) (visible-frame-list)))))
	(delete-frame (selected-frame))
      (let (rmail-flag summary-buffer)
	(and (not arg)
	     (not (one-window-p))
	     (save-excursion
	       (set-buffer (window-buffer (next-window (selected-window) 'not)))
	       (setq rmail-flag (eq major-mode 'rmail-mode))
	       (setq summary-buffer
		     (and mail-bury-selects-summary
			  (boundp 'rmail-summary-buffer)
			  rmail-summary-buffer
			  (buffer-name rmail-summary-buffer)
			  (not (get-buffer-window rmail-summary-buffer))
			  rmail-summary-buffer))))
	(if rmail-flag
	    ;; If the Rmail buffer has a summary, show that.
	    (if summary-buffer (switch-to-buffer summary-buffer)
	      (delete-window))
	  (switch-to-buffer newbuf))))))

(defun mail-send ()
  "Send the message in the current buffer.
If `mail-interactive' is non-nil, wait for success indication
or error messages, and inform user.
Otherwise any failure is reported in a message back to
the user from the mailer."
  (interactive)
  (if (if buffer-file-name
	  (y-or-n-p "Send buffer contents as mail message? ")
	(or (buffer-modified-p)
	    (y-or-n-p "Message already sent; resend? ")))
      (let ((inhibit-read-only t)
	    (opoint (point)))
	(when (and enable-multibyte-characters
		   (not (eq mail-send-nonascii t)))
	  (goto-char (point-min))
	  (skip-chars-forward "\0-\177")
	  (or (= (point) (point-max))
	      (if (eq mail-send-nonascii 'query)
		  (or (y-or-n-p "Message contains non-ASCII characters; send anyway? ")
		      (error "Aborted"))
		(error "Message contains non-ASCII characters"))))
	;; Complain about any invalid line.
	(goto-char (point-min))
	(while (not (looking-at (regexp-quote mail-header-separator)))
	  (unless (looking-at "[ \t]\\|.*:\\|$")
	    (push-mark opoint)
	    (error "Invalid header line (maybe a continuation line lacks initial whitespace)"))
	  (forward-line 1))
	(goto-char opoint)
	(run-hooks 'mail-send-hook)
	(message "Sending...")
	(funcall send-mail-function)
	;; Now perform actions on successful sending.
	(while mail-send-actions
	  (condition-case nil
	      (apply (car (car mail-send-actions))
		     (cdr (car mail-send-actions)))
	    (error))
	  (setq mail-send-actions (cdr mail-send-actions)))
	(message "Sending...done")
	;; If buffer has no file, mark it as unmodified and delete autosave.
	(if (not buffer-file-name)
	    (progn
	      (set-buffer-modified-p nil)
	      (delete-auto-save-file-if-necessary t))))))

;; This does the real work of sending a message via sendmail.
;; It is called via the variable send-mail-function.

;;;###autoload
(defvar sendmail-coding-system nil
  "Coding system to which to encode the mail.")

(defun sendmail-send-it ()
  (require 'mail-utils)
  (let ((errbuf (if mail-interactive
		    (generate-new-buffer " sendmail errors")
		  0))
	(tembuf (generate-new-buffer " sendmail temp"))
	(case-fold-search nil)
	resend-to-addresses
	delimline
	fcc-was-found
	(mailbuf (current-buffer))
	(sendmail-coding-system
	 (if (local-variable-p 'buffer-file-coding-system)
	     buffer-file-coding-system
	   (or sendmail-coding-system
	       default-buffer-file-coding-system
	       'iso-latin-1))))
    (unwind-protect
	(save-excursion
	  (set-buffer tembuf)
	  (erase-buffer)
	  (insert-buffer-substring mailbuf)
	  (goto-char (point-max))
	  ;; require one newline at the end.
	  (or (= (preceding-char) ?\n)
	      (insert ?\n))
	  ;; Change header-delimiter to be what sendmail expects.
	  (goto-char (point-min))
	  (re-search-forward
	    (concat "^" (regexp-quote mail-header-separator) "\n"))
	  (replace-match "\n")
	  (backward-char 1)
	  (setq delimline (point-marker))
	  (sendmail-sync-aliases)
	  (if mail-aliases
	      (expand-mail-aliases (point-min) delimline))
	  (goto-char (point-min))
	  ;; Ignore any blank lines in the header
	  (while (and (re-search-forward "\n\n\n*" delimline t)
		      (< (point) delimline))
	    (replace-match "\n"))
	  (goto-char (point-min))
	  (let ((case-fold-search t))
	    (goto-char (point-min))
	    (while (re-search-forward "^Resent-\\(to\\|cc\\|bcc\\):" delimline t)
	      (setq resend-to-addresses
		    (save-restriction
		      (narrow-to-region (point)
					(save-excursion
					  (end-of-line)
					  (point)))
		      (append (mail-parse-comma-list)
			      resend-to-addresses)))
	      ;; Delete Resent-BCC ourselves
	      (if (save-excursion (beginning-of-line)
				  (looking-at "resent-bcc"))
		  (delete-region (save-excursion (beginning-of-line) (point))
				 (save-excursion (end-of-line) (1+ (point))))))
;;; Apparently this causes a duplicate Sender.
;;;	    ;; If the From is different than current user, insert Sender.
;;;	    (goto-char (point-min))
;;;	    (and (re-search-forward "^From:"  delimline t)
;;;		 (progn
;;;		   (require 'mail-utils)
;;;		   (not (string-equal
;;;			 (mail-strip-quoted-names
;;;			  (save-restriction
;;;			    (narrow-to-region (point-min) delimline)
;;;			    (mail-fetch-field "From")))
;;;			 (user-login-name))))
;;;		 (progn
;;;		   (forward-line 1)
;;;		   (insert "Sender: " (user-login-name) "\n")))
	    ;; Don't send out a blank subject line
	    (goto-char (point-min))
	    (if (re-search-forward "^Subject:\\([ \t]*\n\\)+\\b" delimline t)
		(replace-match "")
	      ;; This one matches a Subject just before the header delimiter.
	      (if (and (re-search-forward "^Subject:\\([ \t]*\n\\)+" delimline t)
		       (= (match-end 0) delimline))
		  (replace-match "")))
	    ;; Put the "From:" field in unless for some odd reason
	    ;; they put one in themselves.
	    (goto-char (point-min))
	    (if (not (re-search-forward "^From:" delimline t))
		(let* ((login user-mail-address)
		       (fullname (user-full-name))
		       (quote-fullname nil))
		  (if (string-match "[\200-\377]" fullname)
		      (setq fullname (mail-quote-printable fullname t)
			    quote-fullname t))
		  (cond ((eq mail-from-style 'angles)
			 (insert "From: " fullname)
			 (let ((fullname-start (+ (point-min) 6))
			       (fullname-end (point-marker)))
			   (goto-char fullname-start)
			   ;; Look for a character that cannot appear unquoted
			   ;; according to RFC 822.
			   (if (or (re-search-forward "[^- !#-'*+/-9=?A-Z^-~]"
						      fullname-end 1)
				   quote-fullname)
			       (progn
				 ;; Quote fullname, escaping specials.
				 (goto-char fullname-start)
				 (insert "\"")
				 (while (re-search-forward "[\"\\]"
							   fullname-end 1)
				   (replace-match "\\\\\\&" t))
				 (insert "\""))))
			 (insert " <" login ">\n"))
			((eq mail-from-style 'parens)
			 (insert "From: " login " (")
			 (let ((fullname-start (point)))
			   (if quote-fullname
			       (insert "\""))
			   (insert fullname)
			   (if quote-fullname
			       (insert "\""))
			   (let ((fullname-end (point-marker)))
			     (goto-char fullname-start)
			     ;; RFC 822 says \ and nonmatching parentheses
			     ;; must be escaped in comments.
			     ;; Escape every instance of ()\ ...
			     (while (re-search-forward "[()\\]" fullname-end 1)
			       (replace-match "\\\\\\&" t))
			     ;; ... then undo escaping of matching parentheses,
			     ;; including matching nested parentheses.
			     (goto-char fullname-start)
			     (while (re-search-forward 
				     "\\(\\=\\|[^\\]\\(\\\\\\\\\\)*\\)\\\\(\\(\\([^\\]\\|\\\\\\\\\\)*\\)\\\\)"
				     fullname-end 1)
			       (replace-match "\\1(\\3)" t)
			       (goto-char fullname-start))))
			 (insert ")\n"))
			((null mail-from-style)
			 (insert "From: " login "\n")))))
	    ;; Insert an extra newline if we need it to work around
	    ;; Sun's bug that swallows newlines.
	    (goto-char (1+ delimline))
	    (if (eval mail-mailer-swallows-blank-line)
		(newline))
	    ;; Find and handle any FCC fields.
	    (goto-char (point-min))
	    (if (re-search-forward "^FCC:" delimline t)
		(progn
		  (setq fcc-was-found t)
		  (mail-do-fcc delimline)))
	    (if mail-interactive
		(save-excursion
		  (set-buffer errbuf)
		  (erase-buffer))))
	  (goto-char (point-min))
	  (if (let ((case-fold-search t))
		(re-search-forward "^To:\\|^cc:\\|^bcc:\\|^resent-to:\
\\|^resent-cc:\\|^resent-bcc:"
				   delimline t))
	      (let ((default-directory "/")
		    (coding-system-for-write sendmail-coding-system))
		(apply 'call-process-region
		       (append (list (point-min) (point-max)
				     (if (boundp 'sendmail-program)
					 sendmail-program
				       "/usr/lib/sendmail")
				     nil errbuf nil "-oi")
			       ;; Always specify who from,
			       ;; since some systems have broken sendmails.
			       (list "-f" (user-login-name))
    ;;;			   ;; Don't say "from root" if running under su.
    ;;;			   (and (equal (user-real-login-name) "root")
    ;;;				(list "-f" (user-login-name)))
			       (and mail-alias-file
				    (list (concat "-oA" mail-alias-file)))
			       (if mail-interactive
				   ;; These mean "report errors to terminal"
				   ;; and "deliver interactively"
				   '("-oep" "-odi")
				 ;; These mean "report errors by mail"
				 ;; and "deliver in background".
				 '("-oem" "-odb"))
			       ;; Get the addresses from the message
			       ;; unless this is a resend.
			       ;; We must not do that for a resend
			       ;; because we would find the original addresses.
			       ;; For a resend, include the specific addresses.
			       (or resend-to-addresses
				   '("-t")))))
	    (or fcc-was-found
		(error "No recipients")))
	  (if mail-interactive
	      (save-excursion
		(set-buffer errbuf)
		(goto-char (point-min))
		(while (re-search-forward "\n\n* *" nil t)
		  (replace-match "; "))
		(if (not (zerop (buffer-size)))
		    (error "Sending...failed to %s"
			   (buffer-substring (point-min) (point-max)))))))
      (kill-buffer tembuf)
      (if (bufferp errbuf)
	  (kill-buffer errbuf)))))

(defun mail-do-fcc (header-end)
  (let (fcc-list
	(rmailbuf (current-buffer))
	(time (current-time))
	(tembuf (generate-new-buffer " rmail output"))
	(case-fold-search t))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "^FCC:[ \t]*" header-end t)
	(setq fcc-list (cons (buffer-substring (point)
					       (progn
						 (end-of-line)
						 (skip-chars-backward " \t")
						 (point)))
			     fcc-list))
	(delete-region (match-beginning 0)
		       (progn (forward-line 1) (point))))
      (set-buffer tembuf)
      (erase-buffer)
      ;; This initial newline is written out if the fcc file already exists.
      (insert "\nFrom " (user-login-name) " "
	      (current-time-string time) "\n")
      ;; Insert the time zone before the year.
      (forward-char -1)
      (forward-word -1)
      (require 'mail-utils)
      (insert (mail-rfc822-time-zone time) " ")
      (goto-char (point-max))
      (insert-buffer-substring rmailbuf)
      ;; Make sure messages are separated.
      (goto-char (point-max))
      (insert ?\n)
      (goto-char 2)
      ;; ``Quote'' "^From " as ">From "
      ;;  (note that this isn't really quoting, as there is no requirement
      ;;   that "^[>]+From " be quoted in the same transparent way.)
      (let ((case-fold-search nil))
	(while (search-forward "\nFrom " nil t)
	  (forward-char -5)
	  (insert ?>)))
      (while fcc-list
	(let* ((buffer (find-buffer-visiting (car fcc-list)))
	       (curbuf (current-buffer))
	       dont-write-the-file
	       buffer-matches-file
	       (beg (point-min)) (end (point-max))
	       (beg2 (save-excursion (goto-char (point-min))
				     (forward-line 2) (point))))
	  (if buffer
	      ;; File is present in a buffer => append to that buffer.
	      (save-excursion
		(set-buffer buffer)
		(setq buffer-matches-file
		      (and (not (buffer-modified-p))
			   (verify-visited-file-modtime buffer)))
		;; Keep the end of the accessible portion at the same place
		;; unless it is the end of the buffer.
		(let ((max (if (/= (1+ (buffer-size)) (point-max))
			       (point-max))))
		  (unwind-protect
		      ;; Code below lifted from rmailout.el
		      ;; function rmail-output-to-rmail-file:
		      (let ((buffer-read-only nil)
			    (msg (and (boundp 'rmail-current-message)
				      rmail-current-message)))
			;; If MSG is non-nil, buffer is in RMAIL mode.
			(if msg
			    (progn
			      (rmail-maybe-set-message-counters)
			      (widen)
			      (narrow-to-region (point-max) (point-max))
			      (insert "\C-l\n0, unseen,,\n*** EOOH ***\n"
				      "Date: " (mail-rfc822-date) "\n")
			      (insert-buffer-substring curbuf beg2 end)
			      (insert "\n\C-_")
			      (goto-char (point-min))
			      (widen)
			      (search-backward "\n\^_")
			      (narrow-to-region (point) (point-max))
			      (rmail-count-new-messages t)
			      (rmail-show-message msg)
			      (setq max nil))
			  ;; Output file not in rmail mode
			  ;; => just insert at the end.
			  (narrow-to-region (point-min) (1+ (buffer-size)))
			  (goto-char (point-max))
			  (insert-buffer-substring curbuf beg end))
			(or buffer-matches-file
			    (progn
			      (if (y-or-n-p (format "Save file %s? "
						    (car fcc-list)))
				  (save-buffer))
			      (setq dont-write-the-file t))))
		    (if max (narrow-to-region (point-min) max))))))
	  ;; Append to the file directly,
	  ;; unless we've already taken care of it.
	  (if (and (not dont-write-the-file)
		   (file-exists-p (car fcc-list))
		   (mail-file-babyl-p (car fcc-list)))
	      ;; If the file is a Babyl file,
	      ;; convert the message to Babyl format.
	      (let ((coding-system-for-write
		     (or rmail-file-coding-system
			 'emacs-mule)))
		(save-excursion
		  (set-buffer (get-buffer-create " mail-temp"))
		  (setq buffer-read-only nil)
		  (erase-buffer)
		  (insert "\C-l\n0, unseen,,\n*** EOOH ***\n"
			  "Date: " (mail-rfc822-date) "\n")
		  (insert-buffer-substring curbuf beg2 end)
		  (insert "\n\C-_")
		  (write-region (point-min) (point-max) (car fcc-list) t)
		  (erase-buffer)))
	    (write-region
	     (1+ (point-min)) (point-max) (car fcc-list) t))
	  (and buffer (not dont-write-the-file)
	       (with-current-buffer buffer
		 (set-visited-file-modtime))))
	(setq fcc-list (cdr fcc-list))))
    (kill-buffer tembuf)))

(defun mail-sent-via ()
  "Make a Sent-via header line from each To or CC header line."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    ;; find the header-separator
    (search-forward (concat "\n" mail-header-separator "\n"))
    (forward-line -1)
    ;; put a marker at the end of the header
    (let ((end (point-marker))
	  (case-fold-search t)
	  to-line)
      (goto-char (point-min))
      ;; search for the To: lines and make Sent-via: lines from them
      ;; search for the next To: line
      (while (re-search-forward "^\\(to\\|cc\\):" end t)
	;; Grab this line plus all its continuations, sans the `to:'.
	(let ((to-line
	       (buffer-substring (point)
				 (progn
				   (if (re-search-forward "^[^ \t\n]" end t)
				       (backward-char 1)
				     (goto-char end))
				   (point)))))
	  ;; Insert a copy, with altered header field name.
	  (insert-before-markers "Sent-via:" to-line))))))

(defun mail-to ()
  "Move point to end of To-field."
  (interactive)
  (expand-abbrev)
  (mail-position-on-field "To"))

(defun mail-subject ()
  "Move point to end of Subject-field."
  (interactive)
  (expand-abbrev)
  (mail-position-on-field "Subject"))

(defun mail-cc ()
  "Move point to end of CC-field.  Create a CC field if none."
  (interactive)
  (expand-abbrev)
  (or (mail-position-on-field "cc" t)
      (progn (mail-position-on-field "to")
	     (insert "\nCC: "))))

(defun mail-bcc ()
  "Move point to end of BCC-field.  Create a BCC field if none."
  (interactive)
  (expand-abbrev)
  (or (mail-position-on-field "bcc" t)
      (progn (mail-position-on-field "to")
	     (insert "\nBCC: "))))

(defun mail-fcc (folder)
  "Add a new FCC field, with file name completion."
  (interactive "FFolder carbon copy: ")
  (expand-abbrev)
  (or (mail-position-on-field "fcc" t)	;Put new field after exiting FCC.
      (mail-position-on-field "to"))
  (insert "\nFCC: " folder))

(defun mail-reply-to ()      
  "Move point to end of Reply-To-field."
  (interactive)
  (expand-abbrev)
  (mail-position-on-field "Reply-To"))

(defun mail-position-on-field (field &optional soft)
  (let (end
	(case-fold-search t))
    (goto-char (point-min))
    (re-search-forward (concat "^" (regexp-quote mail-header-separator) "$"))
    (setq end (match-beginning 0))
    (goto-char (point-min))
    (if (re-search-forward (concat "^" (regexp-quote field) ":") end t)
	(progn
	  (re-search-forward "^[^ \t]" nil 'move)
	  (beginning-of-line)
	  (skip-chars-backward "\n")
	  t)
      (or soft
	  (progn (goto-char end)
		 (insert field ": \n")
		 (skip-chars-backward "\n")))
      nil)))

(defun mail-text ()
  "Move point to beginning of message text."
  (interactive)
  (expand-abbrev)
  (goto-char (point-min))
  (search-forward (concat "\n" mail-header-separator "\n")))

(defun mail-signature (atpoint)
  "Sign letter with contents of the file `mail-signature-file'.
Prefix arg means put contents at point."
  (interactive "P")
  (save-excursion
    (or atpoint
	(goto-char (point-max)))
    (skip-chars-backward " \t\n")
    (end-of-line)
    (or atpoint
	(delete-region (point) (point-max)))
    (insert "\n\n-- \n")
    (insert-file-contents (expand-file-name mail-signature-file))))

(defun mail-fill-yanked-message (&optional justifyp)
  "Fill the paragraphs of a message yanked into this one.
Numeric argument means justify as well."
  (interactive "P")
  (save-excursion
    (goto-char (point-min))
    (search-forward (concat "\n" mail-header-separator "\n") nil t)
    (fill-individual-paragraphs (point)
				(point-max)
				justifyp
				t)))

(defun mail-indent-citation ()
  "Modify text just inserted from a message to be cited.
The inserted text should be the region.
When this function returns, the region is again around the modified text.

Normally, indent each nonblank line `mail-indentation-spaces' spaces.
However, if `mail-yank-prefix' is non-nil, insert that prefix on each line."
  (mail-yank-clear-headers (region-beginning) (region-end))
  (if (null mail-yank-prefix)
      (indent-rigidly (region-beginning) (region-end)
		      mail-indentation-spaces)
    (save-excursion
      (let ((end (set-marker (make-marker) (region-end))))
	(goto-char (region-beginning))
	(while (< (point) end)
	  (insert mail-yank-prefix)
	  (forward-line 1))))))

(defun mail-yank-original (arg)
  "Insert the message being replied to, if any (in rmail).
Puts point after the text and mark before.
Normally, indents each nonblank line ARG spaces (default 3).
However, if `mail-yank-prefix' is non-nil, insert that prefix on each line.

Just \\[universal-argument] as argument means don't indent, insert no prefix,
and don't delete any header fields."
  (interactive "P")
  (if mail-reply-action
      (let ((start (point))
	    (original mail-reply-action))
	(and (consp original) (eq (car original) 'insert-buffer)
	     (setq original (nth 1 original)))
	(if (consp original)
	    (apply (car original) (cdr original))
	  ;; If the original message is in another window in the same frame,
	  ;; delete that window to save screen space.
	  ;; t means don't alter other frames.
	  (delete-windows-on original t)
	  (insert-buffer original))
	(if (consp arg)
	    nil
	  (goto-char start)
	  (let ((mail-indentation-spaces (if arg (prefix-numeric-value arg)
					   mail-indentation-spaces))
		(mark-even-if-inactive t))
	    (if mail-citation-hook
		(run-hooks 'mail-citation-hook)
	      (if mail-yank-hooks
		  (run-hooks 'mail-yank-hooks)
		(mail-indent-citation)))))
	;; This is like exchange-point-and-mark, but doesn't activate the mark.
	;; It is cleaner to avoid activation, even though the command
	;; loop would deactivate the mark because we inserted text.
	(goto-char (prog1 (mark t)
		     (set-marker (mark-marker) (point) (current-buffer))))
	(if (not (eolp)) (insert ?\n)))))

(defun mail-yank-clear-headers (start end)
  (if (< end start)
      (let (temp)
	(setq temp start start end end temp)))
  (if mail-yank-ignored-headers
      (save-excursion
	(goto-char start)
	(if (search-forward "\n\n" end t)
	    (save-restriction
	      (narrow-to-region start (point))
	      (goto-char start)
	      (while (let ((case-fold-search t))
		       (re-search-forward mail-yank-ignored-headers nil t))
		(beginning-of-line)
		(delete-region (point)
			       (progn (re-search-forward "\n[^ \t]")
				      (forward-char -1)
				      (point)))))))))

(defun mail-yank-region (arg)
  "Insert the selected region from the message being replied to.
Puts point after the text and mark before.
Normally, indents each nonblank line ARG spaces (default 3).
However, if `mail-yank-prefix' is non-nil, insert that prefix on each line.

Just \\[universal-argument] as argument means don't indent, insert no prefix,
and don't delete any header fields."
  (interactive "P")
  (and (consp mail-reply-action)
       (eq (car mail-reply-action) 'insert-buffer)
       (let ((buffer (nth 1 mail-reply-action))
	     (start (point)))
	 ;; Insert the citation text.
	 (insert (with-current-buffer buffer
		   (buffer-substring (point) (mark))))
	 (push-mark start)
	 ;; Indent or otherwise annotate the citation text.
	 (if (consp arg)
	     nil
	   (let ((mail-indentation-spaces (if arg (prefix-numeric-value arg)
					    mail-indentation-spaces)))
	     (if mail-citation-hook
		 (run-hooks 'mail-citation-hook)
	       (if mail-yank-hooks
		   (run-hooks 'mail-yank-hooks)
		 (mail-indent-citation))))))))

(defun mail-attach-file (&optional file)
  "Insert a file at the end of the buffer, with separator lines around it."
  (interactive "fAttach file: ")
  (save-excursion
    (goto-char (point-max))
    (or (bolp) (newline))
    (newline)
    (let ((start (point))
	  middle)
      (insert (format "===File %s===" file))
      (insert-char ?= (max 0 (- 60 (current-column))))
      (newline)
      (setq middle (point))
      (insert "============================================================\n")
      (push-mark)
      (goto-char middle)
      (insert-file-contents file)
      (or (bolp) (newline))
      (goto-char start))))

;; Put these commands last, to reduce chance of lossage from quitting
;; in middle of loading the file.

;;;###autoload (add-hook 'same-window-buffer-names "*mail*")

;;;###autoload
(defun mail (&optional noerase to subject in-reply-to cc replybuffer actions)
  "Edit a message to be sent.  Prefix arg means resume editing (don't erase).
When this function returns, the buffer `*mail*' is selected.
The value is t if the message was newly initialized; otherwise, nil.

Optionally, the signature file `mail-signature-file' can be inserted at the
end; see the variable `mail-signature'.

\\<mail-mode-map>
While editing message, type \\[mail-send-and-exit] to send the message and exit.

Various special commands starting with C-c are available in sendmail mode
to move to message header fields:
\\{mail-mode-map}

If `mail-self-blind' is non-nil, a BCC to yourself is inserted
when the message is initialized.

If `mail-default-reply-to' is non-nil, it should be an address (a string);
a Reply-to: field with that address is inserted.

If `mail-archive-file-name' is non-nil, an FCC field with that file name
is inserted.

The normal hook `mail-setup-hook' is run after the message is
initialized.  It can add more default fields to the message.

When calling from a program, the first argument if non-nil says
not to erase the existing contents of the `*mail*' buffer.

The second through fifth arguments,
 TO, SUBJECT, IN-REPLY-TO and CC, specify if non-nil
 the initial contents of those header fields.
 These arguments should not have final newlines.
The sixth argument REPLYBUFFER is a buffer which contains an
 original message being replied to, or else an action
 of the form (FUNCTION . ARGS) which says how to insert the original.
 Or it can be nil, if not replying to anything.
The seventh argument ACTIONS is a list of actions to take
 if/when the message is sent.  Each action looks like (FUNCTION . ARGS);
 when the message is sent, we apply FUNCTION to ARGS.
 This is how Rmail arranges to mark messages `answered'."
  (interactive "P")
;;; This is commented out because I found it was confusing in practice.
;;; It is easy enough to rename *mail* by hand with rename-buffer
;;; if you want to have multiple mail buffers.
;;; And then you can control which messages to save. --rms.
;;;  (let ((index 1)
;;;	buffer)
;;;    ;; If requested, look for a mail buffer that is modified and go to it.
;;;    (if noerase
;;;	(progn
;;;	  (while (and (setq buffer
;;;			    (get-buffer (if (= 1 index) "*mail*"
;;;					  (format "*mail*<%d>" index))))
;;;		      (not (buffer-modified-p buffer)))
;;;	    (setq index (1+ index)))
;;;	  (if buffer (switch-to-buffer buffer)
;;;	    ;; If none exists, start a new message.
;;;	    ;; This will never re-use an existing unmodified mail buffer
;;;	    ;; (since index is not 1 anymore).  Perhaps it should.
;;;	    (setq noerase nil))))
;;;    ;; Unless we found a modified message and are happy, start a new message.
;;;    (if (not noerase)
;;;	(progn
;;;	  ;; Look for existing unmodified mail buffer.
;;;	  (while (and (setq buffer
;;;			    (get-buffer (if (= 1 index) "*mail*"
;;;					  (format "*mail*<%d>" index))))
;;;		      (buffer-modified-p buffer))
;;;	    (setq index (1+ index)))
;;;	  ;; If none, make a new one.
;;;	  (or buffer
;;;	      (setq buffer (generate-new-buffer "*mail*")))
;;;	  ;; Go there and initialize it.
;;;	  (switch-to-buffer buffer)
;;;	  (erase-buffer)
;;;          (setq default-directory (expand-file-name "~/"))
;;;          (auto-save-mode auto-save-default)
;;;          (mail-mode)
;;;          (mail-setup to subject in-reply-to cc replybuffer actions)
;;;	  (if (and buffer-auto-save-file-name
;;;		   (file-exists-p buffer-auto-save-file-name))
;;;	      (message "Auto save file for draft message exists; consider M-x mail-recover"))
;;;          t))
  (pop-to-buffer "*mail*")
  ;; Put the auto-save file in the home dir
  ;; to avoid any danger that it can't be written.
  (if (file-exists-p (expand-file-name "~/"))
      (setq default-directory (expand-file-name "~/")))
  (auto-save-mode auto-save-default)
  (mail-mode)
  ;; Disconnect the buffer from its visited file
  ;; (in case the user has actually visited a file *mail*).
;  (set-visited-file-name nil)
  (let (initialized)
    (and (not noerase)
	 (if buffer-file-name
	     (if (buffer-modified-p)
		 (when (y-or-n-p "Buffer has unsaved changes; reinitialize it and discard them? ")
		   (if (y-or-n-p "Disconnect buffer from visited file? ")
		       (set-visited-file-name nil))
		   t)
	       (when (y-or-n-p "Reinitialize buffer, and disconnect it from the visited file? ")
		 (set-visited-file-name nil)
		 t))
	   ;; A non-file-visiting buffer.
	   (if (buffer-modified-p)
	       (y-or-n-p "Unsent message being composed; erase it? ")
	     t))
	 (let ((inhibit-read-only t))
	   (erase-buffer)
	   (mail-setup to subject in-reply-to cc replybuffer actions)
	   (setq initialized t)))
    (if (and buffer-auto-save-file-name
	     (file-exists-p buffer-auto-save-file-name))
	(message "Auto save file for draft message exists; consider M-x mail-recover"))
    initialized))

(defun mail-recover ()
  "Reread contents of current buffer from its last auto-save file."
  (interactive)
  (let ((file-name (make-auto-save-file-name)))
    (cond ((save-window-excursion
	     (if (not (eq system-type 'vax-vms))
		 (with-output-to-temp-buffer "*Directory*"
		   (buffer-disable-undo standard-output)
		   (let ((default-directory "/"))
		     (call-process
		      "ls" nil standard-output nil "-l" file-name))))
	     (yes-or-no-p (format "Recover auto save file %s? " file-name)))
	   (let ((buffer-read-only nil))
	     (erase-buffer)
	     (insert-file-contents file-name nil)))
	  (t (error "mail-recover cancelled")))))

;;;###autoload
(defun mail-other-window (&optional noerase to subject in-reply-to cc replybuffer sendactions)
  "Like `mail' command, but display mail buffer in another window."
  (interactive "P")
  (let ((pop-up-windows t)
	(special-display-buffer-names nil)
	(special-display-regexps nil)
	(same-window-buffer-names nil)
	(same-window-regexps nil))
    (pop-to-buffer "*mail*"))
  (mail noerase to subject in-reply-to cc replybuffer sendactions))

;;;###autoload
(defun mail-other-frame (&optional noerase to subject in-reply-to cc replybuffer sendactions)
  "Like `mail' command, but display mail buffer in another frame."
  (interactive "P")
  (let ((pop-up-frames t)
	(special-display-buffer-names nil)
	(special-display-regexps nil)
	(same-window-buffer-names nil)
	(same-window-regexps nil))
    (pop-to-buffer "*mail*"))
  (mail noerase to subject in-reply-to cc replybuffer sendactions))

;;; Do not add anything but external entries on this page.

(provide 'sendmail)

;;; sendmail.el ends here
