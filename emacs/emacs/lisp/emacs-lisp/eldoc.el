;;; eldoc.el --- show function arglist or variable docstring in echo area

;; Copyright (C) 1996, 1997 Free Software Foundation, Inc.

;; Author: Noah Friedman <friedman@prep.ai.mit.edu>
;; Maintainer: friedman@prep.ai.mit.edu
;; Keywords: extensions
;; Created: 1995-10-06

;; $Id: eldoc.el,v 1.1.1.1 1997/09/28 00:29:23 wsanchez Exp $

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

;; This program was inspired by the behavior of the "mouse documentation
;; window" on many Lisp Machine systems; as you type a function's symbol
;; name as part of a sexp, it will print the argument list for that
;; function.  Behavior is not identical; for example, you need not actually
;; type the function name, you need only move point around in a sexp that
;; calls it.  Also, if point is over a documented variable, it will print
;; the one-line documentation for that variable instead, to remind you of
;; that variable's meaning.

;; One useful way to enable this minor mode is to put the following in your
;; .emacs:
;;
;;      (autoload 'turn-on-eldoc-mode "eldoc" nil t)
;;      (add-hook 'emacs-lisp-mode-hook 'turn-on-eldoc-mode)
;;      (add-hook 'lisp-interaction-mode-hook 'turn-on-eldoc-mode)
;;      (add-hook 'ielm-mode-hook 'turn-on-eldoc-mode)

;;; Code:

;; Use idle timers if available in the version of emacs running.
;; Please don't change this to use `require'; this package works as-is in
;; XEmacs (which doesn't have timer.el as of 19.14), and I would like to
;; maintain compatibility with that since I must use it sometimes.  --Noah
(or (featurep 'timer)
    (load "timer" t))

(defgroup eldoc nil
  "Show function arglist or variable docstring in echo area."
  :group 'extensions)

;;;###autoload
(defcustom eldoc-mode nil
  "*If non-nil, show the defined parameters for the elisp function near point.

For the emacs lisp function at the beginning of the sexp which point is
within, show the defined parameters for the function in the echo area.
This information is extracted directly from the function or macro if it is
in pure lisp.  If the emacs function is a subr, the parameters are obtained
from the documentation string if possible.

If point is over a documented variable, print that variable's docstring
instead.

This variable is buffer-local."
  :type 'boolean
  :group 'eldoc)
(make-variable-buffer-local 'eldoc-mode)

(defcustom eldoc-idle-delay 0.50
  "*Number of seconds of idle time to wait before printing.
If user input arrives before this interval of time has elapsed after the
last input, no documentation will be printed.

If this variable is set to 0, no idle time is required."
  :type 'number
  :group 'eldoc)

(defcustom eldoc-minor-mode-string " ElDoc"
  "*String to display in mode line when Eldoc Mode is enabled."
  :type 'string
  :group 'eldoc)

;; Put this minor mode on the global minor-mode-alist.
(or (assq 'eldoc-mode (default-value 'minor-mode-alist))
    (setq-default minor-mode-alist
                  (append (default-value 'minor-mode-alist)
                          '((eldoc-mode eldoc-minor-mode-string)))))

(defcustom eldoc-argument-case 'upcase
  "Case to display argument names of functions, as a symbol.
This has two preferred values: `upcase' or `downcase'.
Actually, any name of a function which takes a string as an argument and
returns another string is acceptable."
  :type '(choice (const upcase) (const downcase))
  :group 'eldoc)

;; No user options below here.

;; Commands after which it is appropriate to print in the echo area.
;; Eldoc does not try to print function arglists, etc. after just any command,
;; because some commands print their own messages in the echo area and these
;; functions would instantly overwrite them.  But self-insert-command as well
;; as most motion commands are good candidates.
;; This variable contains an obarray of symbols; do not manipulate it
;; directly.  Instead, use `eldoc-add-command' and `eldoc-remove-command'.
(defvar eldoc-message-commands nil)

;; This is used by eldoc-add-command to initialize eldoc-message-commands
;; as an obarray.
;; It should probably never be necessary to do so, but if you
;; choose to increase the number of buckets, you must do so before loading
;; this file since the obarray is initialized at load time.
;; Remember to keep it a prime number to improve hash performance.
(defvar eldoc-message-commands-table-size 31)

;; Bookkeeping; the car contains the last symbol read from the buffer.
;; The cdr contains the string last displayed in the echo area, so it can
;; be printed again if necessary without reconsing.
(defvar eldoc-last-data (cons nil nil))
(defvar eldoc-last-message nil)

;; Idle timers are supported in Emacs 19.31 and later.
(defvar eldoc-use-idle-timer-p (fboundp 'run-with-idle-timer))

;; eldoc's timer object, if using idle timers
(defvar eldoc-timer nil)

;; idle time delay currently in use by timer.
;; This is used to determine if eldoc-idle-delay is changed by the user.
(defvar eldoc-current-idle-delay eldoc-idle-delay)


;;;###autoload
(defun eldoc-mode (&optional prefix)
  "*Enable or disable eldoc mode.
See documentation for the variable of the same name for more details.

If called interactively with no prefix argument, toggle current condition
of the mode.
If called with a positive or negative prefix argument, enable or disable
the mode, respectively."
  (interactive "P")
  (setq eldoc-last-message nil)
  (cond (eldoc-use-idle-timer-p
         (add-hook 'post-command-hook 'eldoc-schedule-timer)
         (add-hook 'pre-command-hook 'eldoc-pre-command-refresh-echo-area))
        (t
         ;; Use post-command-idle-hook if defined, otherwise use
         ;; post-command-hook.  The former is only proper to use in Emacs
         ;; 19.30; that is the first version in which it appeared, but it
         ;; was obsolesced by idle timers in Emacs 19.31.
         (add-hook (if (boundp 'post-command-idle-hook)
                  'post-command-idle-hook
                'post-command-hook)
              'eldoc-print-current-symbol-info)
         ;; quick and dirty hack for seeing if this is XEmacs
         (and (fboundp 'display-message)
              (add-hook 'pre-command-hook
                        'eldoc-pre-command-refresh-echo-area))))
  (setq eldoc-mode (if prefix
                       (>= (prefix-numeric-value prefix) 0)
                     (not eldoc-mode)))
  (and (interactive-p)
       (if eldoc-mode
           (message "eldoc-mode is enabled")
         (message "eldoc-mode is disabled")))
  eldoc-mode)

;;;###autoload
(defun turn-on-eldoc-mode ()
  "Unequivocally turn on eldoc-mode (see variable documentation)."
  (interactive)
  (eldoc-mode 1))

;; Idle timers are part of Emacs 19.31 and later.
(defun eldoc-schedule-timer ()
  (or (and eldoc-timer
           (memq eldoc-timer timer-idle-list))
      (setq eldoc-timer
            (run-with-idle-timer eldoc-idle-delay t
                                 'eldoc-print-current-symbol-info)))

  ;; If user has changed the idle delay, update the timer.
  (cond ((not (= eldoc-idle-delay eldoc-current-idle-delay))
         (setq eldoc-current-idle-delay eldoc-idle-delay)
         (timer-set-idle-time eldoc-timer eldoc-idle-delay t))))

;; This function goes on pre-command-hook for XEmacs or when using idle
;; timers in Emacs.  Motion commands clear the echo area for some reason,
;; which make eldoc messages flicker or disappear just before motion
;; begins.  This function reprints the last eldoc message immediately
;; before the next command executes, which does away with the flicker.
;; This doesn't seem to be required for Emacs 19.28 and earlier.
(defun eldoc-pre-command-refresh-echo-area ()
  (and eldoc-last-message
       (if (eldoc-display-message-no-interference-p)
           (eldoc-message eldoc-last-message)
         (setq eldoc-last-message nil))))

(defun eldoc-message (&rest args)
  (let ((omessage eldoc-last-message))
    (cond ((eq (car args) eldoc-last-message))
          ((or (null args)
               (null (car args)))
           (setq eldoc-last-message nil))
          (t
           (setq eldoc-last-message (apply 'format args))))
    ;; In emacs 19.29 and later, and XEmacs 19.13 and later, all messages
    ;; are recorded in a log.  Do not put eldoc messages in that log since
    ;; they are Legion.
    (if (fboundp 'display-message)
        ;; XEmacs 19.13 way of preventing log messages.
        (if eldoc-last-message
            (display-message 'no-log eldoc-last-message)
          (and omessage
               (clear-message 'no-log)))
      (let ((message-log-max nil))
        (if eldoc-last-message
            (message "%s" eldoc-last-message)
          (and omessage
               (message nil))))))
  eldoc-last-message)


(defun eldoc-print-current-symbol-info ()
  (and (eldoc-display-message-p)
       (let ((current-symbol (eldoc-current-symbol))
             (current-fnsym  (eldoc-fnsym-in-current-sexp)))
         (or (cond ((eq current-symbol current-fnsym)
                    (or (eldoc-print-fnsym-args current-fnsym)
                        (eldoc-print-var-docstring current-symbol)))
                   (t
                    (or (eldoc-print-var-docstring current-symbol)
                        (eldoc-print-fnsym-args current-fnsym))))
             (eldoc-message nil)))))

;; Decide whether now is a good time to display a message.
(defun eldoc-display-message-p ()
  (and (eldoc-display-message-no-interference-p)
       (cond (eldoc-use-idle-timer-p
              ;; If this-command is non-nil while running via an idle
              ;; timer, we're still in the middle of executing a command,
              ;; e.g. a query-replace where it would be annoying to
              ;; overwrite the echo area.
              (and (not this-command)
                   (symbolp last-command)
                   (intern-soft (symbol-name last-command)
                                eldoc-message-commands)))
             (t
              ;; If we don't have idle timers, this function is
              ;; running on post-command-hook directly; that means the
              ;; user's last command is still on `this-command', and we
              ;; must wait briefly for input to see whether to do display.
              (and (symbolp this-command)
                   (intern-soft (symbol-name this-command)
                                eldoc-message-commands)
                   (sit-for eldoc-idle-delay))))))

(defun eldoc-display-message-no-interference-p ()
  (and eldoc-mode
       (not executing-kbd-macro)
       ;; Having this mode operate in an active minibuffer/echo area causes
       ;; interference with what's going on there.
       (not cursor-in-echo-area)
       (not (eq (selected-window) (minibuffer-window)))))

(defun eldoc-print-fnsym-args (sym)
  (interactive)
  (let ((args nil))
    (cond ((not (and sym
                     (symbolp sym)
                     (fboundp sym))))
          ((eq sym (car eldoc-last-data))
           (setq args (cdr eldoc-last-data)))
          ((subrp (eldoc-symbol-function sym))
           (setq args (or (eldoc-function-argstring-from-docstring sym)
                          (eldoc-docstring-first-line (documentation sym t))))
           (setcar eldoc-last-data sym)
           (setcdr eldoc-last-data args))
          (t
           (setq args (eldoc-function-argstring sym))
           (setcar eldoc-last-data sym)
           (setcdr eldoc-last-data args)))
    (and args
         (eldoc-message "%s: %s" sym args))))

(defun eldoc-fnsym-in-current-sexp ()
  (let ((p (point)))
    (eldoc-beginning-of-sexp)
    (prog1
        ;; Don't do anything if current word is inside a string.
        (if (= (or (char-after (1- (point))) 0) ?\")
            nil
          (eldoc-current-symbol))
      (goto-char p))))

(defun eldoc-beginning-of-sexp ()
  (let ((parse-sexp-ignore-comments t))
    (condition-case err
        (while (progn
                 (forward-sexp -1)
                 (or (= (or (char-after (1- (point)))) ?\")
                     (> (point) (point-min)))))
      (error nil))))

;; returns nil unless current word is an interned symbol.
(defun eldoc-current-symbol ()
  (let ((c (char-after (point))))
    (and c
         (memq (char-syntax c) '(?w ?_))
         (intern-soft (current-word)))))

;; Do indirect function resolution if possible.
(defun eldoc-symbol-function (fsym)
  (let ((defn (and (fboundp fsym)
                   (symbol-function fsym))))
    (and (symbolp defn)
         (condition-case err
             (setq defn (indirect-function fsym))
           (error (setq defn nil))))
    defn))

(defun eldoc-function-argstring (fn)
  (let* ((prelim-def (eldoc-symbol-function fn))
         (def (if (eq (car-safe prelim-def) 'macro)
                  (cdr prelim-def)
                prelim-def))
         (arglist (cond ((null def) nil)
                        ((byte-code-function-p def)
                         (if (fboundp 'compiled-function-arglist)
                             (funcall 'compiled-function-arglist def)
                           (aref def 0)))
                        ((eq (car-safe def) 'lambda)
                         (nth 1 def))
                        (t t))))
    (eldoc-function-argstring-format arglist)))

(defun eldoc-function-argstring-format (arglist)
  (cond ((not (listp arglist))
         (setq arglist nil))
        ((symbolp (car arglist))
         (setq arglist
               (mapcar (function (lambda (s)
                                   (if (memq s '(&optional &rest))
                                       (symbol-name s)
                                     (funcall eldoc-argument-case
                                              (symbol-name s)))))
                       arglist)))
        ((stringp (car arglist))
         (setq arglist
               (mapcar (function (lambda (s)
                                   (if (member s '("&optional" "&rest"))
                                       s
                                     (funcall eldoc-argument-case s))))
                       arglist))))
  (concat "(" (mapconcat 'identity arglist " ") ")"))


(defun eldoc-print-var-docstring (sym)
  (eldoc-print-docstring sym (documentation-property
                              sym 'variable-documentation t)))

;; Print the brief (one-line) documentation string for the symbol.
(defun eldoc-print-docstring (symbol doc)
  (and doc
       (eldoc-message "%s" (eldoc-docstring-message symbol doc))))

;; If the entire line cannot fit in the echo area, the variable name may be
;; truncated or eliminated entirely from the output to make room.
;; Any leading `*' in the docstring (which indicates the variable is a user
;; option) is not printed."
(defun eldoc-docstring-message (symbol doc)
  (and doc
       (let ((name (symbol-name symbol)))
         (setq doc (eldoc-docstring-first-line doc))
         (save-match-data
           (let* ((doclen (+ (length name) (length ": ") (length doc)))
                  ;; Subtract 1 from window width since emacs seems not to
                  ;; write any chars to the last column, at least for some
                  ;; terminal types.
                  (strip (- doclen (1- (window-width (minibuffer-window))))))
             (cond ((> strip 0)
                    (let* ((len (length name)))
                      (cond ((>= strip len)
                             (format "%s" doc))
                            (t
                             ;;(setq name (substring name 0 (- len strip)))
                             ;;
                             ;; Show the end of the partial variable name,
                             ;; rather than the beginning, since the former
                             ;; is more likely to be unique given package
                             ;; namespace conventions.
                             (setq name (substring name strip))
                             (format "%s: %s" name doc)))))
                   (t
                    (format "%s: %s" symbol doc))))))))

(defun eldoc-docstring-first-line (doc)
  (save-match-data
    (and (string-match "\n" doc)
         (setq doc (substring doc 0 (match-beginning 0))))
    (and (string-match "^\\*" doc)
         (setq doc (substring doc 1))))
  doc)


;; Alist of predicate/action pairs.
;; Each member of the list is a sublist consisting of a predicate function
;; used to determine if the arglist for a function can be found using a
;; certain pattern, and a function which returns the actual arglist from
;; that docstring.
;;
;; The order in this table is significant, since later predicates may be
;; more general than earlier ones.
;;
;; Compiler note for Emacs/XEmacs versions which support dynamic loading:
;; these functions will be compiled to bytecode, but can't be lazy-loaded
;; even if you set byte-compile-dynamic; to do that would require making
;; them named top-level defuns, which is not particularly desirable either.
(defvar eldoc-function-argstring-from-docstring-method-table
  (list
   ;; Try first searching for args starting with symbol name.
   ;; This is to avoid matching parenthetical remarks in e.g. sit-for.
   (list (function (lambda (doc fn)
                     (string-match (format "^(%s[^\n)]*)$" fn) doc)))
         (function (lambda (doc)
                     ;; end does not include trailing ")" sequence.
                     (let ((end (- (match-end 0) 1)))
                       (if (string-match " +" doc (match-beginning 0))
                           (substring doc (match-end 0) end)
                         "")))))

   ;; Try again not requiring this symbol name in the docstring.
   ;; This will be the case when looking up aliases.
   (list (function (lambda (doc fn)
                     ;; save-restriction has a pathological docstring in
                     ;; Emacs/XEmacs 19.
                     (and (not (eq fn 'save-restriction))
                          (string-match "^([^\n)]+)$" doc))))
         (function (lambda (doc)
                     ;; end does not include trailing ")" sequence.
                     (let ((end (- (match-end 0) 1)))
                       (and (string-match " +" doc (match-beginning 0))
                            (substring doc (match-end 0) end))))))

   ;; Emacs subr docstring style:
   ;;   (fn arg1 arg2 ...): description...
   (list (function (lambda (doc fn)
                     (string-match "^([^\n)]+):" doc)))
         (function (lambda (doc)
                     ;; end does not include trailing "):" sequence.
                     (let ((end (- (match-end 0) 2)))
                       (and (string-match " +" doc (match-beginning 0))
                            (substring doc (match-end 0) end))))))

   ;; XEmacs subr docstring style:
   ;;   "arguments: (arg1 arg2 ...)
   (list (function (lambda (doc fn)
                     (string-match "^arguments: (\\([^\n)]+\\))" doc)))
         (function (lambda (doc)
                     ;; also skip leading paren, but the first word is
                     ;; actually an argument, not the function name.
                     (substring doc (match-beginning 1) (match-end 1)))))

   ;; This finds the argstring for `condition-case'.  Any others?
   (list (function (lambda (doc fn)
                     (string-match
                      (format "^Usage looks like \\((%s[^\n)]*)\\)\\.$" fn)
                      doc)))
         (function (lambda (doc)
                     ;; end does not include trailing ")" sequence.
                     (let ((end (- (match-end 1) 1)))
                       (and (string-match " +" doc (match-beginning 1))
                            (substring doc (match-end 0) end))))))

   ;; This finds the argstring for `setq-default'.  Any others?
   (list (function (lambda (doc fn)
                     (string-match (format "^[ \t]+\\((%s[^\n)]*)\\)$" fn)
                                   doc)))
         (function (lambda (doc)
                     ;; end does not include trailing ")" sequence.
                     (let ((end (- (match-end 1) 1)))
                       (and (string-match " +" doc (match-beginning 1))
                            (substring doc (match-end 0) end))))))

   ;; This finds the argstring for `start-process'.  Any others?
   (list (function (lambda (doc fn)
                     (string-match "^Args are +\\([^\n]+\\)$" doc)))
         (function (lambda (doc)
                     (substring doc (match-beginning 1) (match-end 1)))))

   ;; These common subrs don't have arglists in their docstrings.  So cheat.
   (list (function (lambda (doc fn)
                     (memq fn '(and or list + -))))
         (function (lambda (doc)
                     ;; The value nil is a placeholder; otherwise, the
                     ;; following string may be compiled as a docstring,
                     ;; and not a return value for the function.
                     ;; In interpreted lisp form they are
                     ;; indistinguishable; it only matters for compiled
                     ;; forms.
                     nil
                     "&rest args")))
   ))

(defun eldoc-function-argstring-from-docstring (fn)
  (let ((docstring (documentation fn 'raw))
        (table eldoc-function-argstring-from-docstring-method-table)
        (doc nil)
        (doclist nil))
    (save-match-data
      (while table
        (cond ((funcall (car (car table)) docstring fn)
               (setq doc (funcall (car (cdr (car table))) docstring))
               (setq table nil))
              (t
               (setq table (cdr table)))))

      (cond ((not (stringp doc))
             nil)
            ((string-match "&" doc)
             (let ((p 0)
                   (l (length doc)))
               (while (< p l)
                 (cond ((string-match "[ \t\n]+" doc p)
                        (setq doclist
                              (cons (substring doc p (match-beginning 0))
                                    doclist))
                        (setq p (match-end 0)))
                       (t
                        (setq doclist (cons (substring doc p) doclist))
                        (setq p l))))
               (eldoc-function-argstring-format (nreverse doclist))))
            (t
             (concat "(" (funcall eldoc-argument-case doc) ")"))))))


;; When point is in a sexp, the function args are not reprinted in the echo
;; area after every possible interactive command because some of them print
;; their own messages in the echo area; the eldoc functions would instantly
;; overwrite them unless it is more restrained.
;; These functions do display-command table management.

(defun eldoc-add-command (&rest cmds)
  (or eldoc-message-commands
      (setq eldoc-message-commands
            (make-vector eldoc-message-commands-table-size 0)))

  (let (name sym)
    (while cmds
      (setq name (car cmds))
      (setq cmds (cdr cmds))

      (cond ((symbolp name)
             (setq sym name)
             (setq name (symbol-name sym)))
            ((stringp name)
             (setq sym (intern-soft name))))

      (and (symbolp sym)
           (fboundp sym)
           (set (intern name eldoc-message-commands) t)))))

(defun eldoc-add-command-completions (&rest names)
  (while names
      (apply 'eldoc-add-command
             (all-completions (car names) obarray 'fboundp))
      (setq names (cdr names))))

(defun eldoc-remove-command (&rest cmds)
  (let (name)
    (while cmds
      (setq name (car cmds))
      (setq cmds (cdr cmds))

      (and (symbolp name)
           (setq name (symbol-name name)))

      (if (fboundp 'unintern)
          (unintern name eldoc-message-commands)
        (let ((s (intern-soft name eldoc-message-commands)))
          (and s
               (makunbound s)))))))

(defun eldoc-remove-command-completions (&rest names)
  (while names
    (apply 'eldoc-remove-command
           (all-completions (car names) eldoc-message-commands))
    (setq names (cdr names))))

;; Prime the command list.
(eldoc-add-command-completions
 "backward-" "beginning-of-" "delete-other-windows" "delete-window"
 "end-of-" "forward-" "indent-for-tab-command" "goto-" "mouse-set-point"
 "next-" "other-window" "previous-" "recenter" "scroll-"
 "self-insert-command" "split-window-"
 "up-list" "down-list")

(provide 'eldoc)

;;; eldoc.el ends here
