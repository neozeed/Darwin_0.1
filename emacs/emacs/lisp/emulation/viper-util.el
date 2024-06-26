;;; viper-util.el --- Utilities used by viper.el

;; Copyright (C) 1994, 1995, 1996, 1997 Free Software Foundation, Inc.

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


;; Code

;; Compiler pacifier
(defvar viper-overriding-map)
(defvar pm-color-alist)
(defvar zmacs-region-stays)
(defvar viper-minibuffer-current-face)
(defvar viper-minibuffer-insert-face)
(defvar viper-minibuffer-vi-face)
(defvar viper-minibuffer-emacs-face)
(defvar viper-replace-overlay-face)
(defvar viper-fast-keyseq-timeout)
(defvar ex-unix-type-shell)
(defvar ex-unix-type-shell-options)
(defvar viper-ex-tmp-buf-name)
(defvar viper-syntax-preference)

(require 'cl)
(require 'ring)

(if noninteractive
    (eval-when-compile
      (let ((load-path (cons (expand-file-name ".") load-path)))
	(or (featurep 'viper-init)
	    (load "viper-init.el" nil nil 'nosuffix))
	)))
;; end pacifier

(require 'viper-init)


;; A fix for NeXT Step
;; Should go away, when NS people fix the design flaw, which leaves the
;; two x-* functions undefined.
(if (and (not (fboundp 'x-display-color-p)) (fboundp 'ns-display-color-p))
    (fset 'x-display-color-p (symbol-function 'ns-display-color-p)))
(if (and (not (fboundp 'x-color-defined-p)) (fboundp 'ns-color-defined-p))
      (fset 'x-color-defined-p (symbol-function 'ns-color-defined-p)))


;;; XEmacs support


(if viper-xemacs-p
    (progn
      (fset 'viper-read-event (symbol-function 'next-command-event))
      (fset 'viper-make-overlay (symbol-function 'make-extent))
      (fset 'viper-overlay-start (symbol-function 'extent-start-position))
      (fset 'viper-overlay-end (symbol-function 'extent-end-position))
      (fset 'viper-overlay-put (symbol-function 'set-extent-property))
      (fset 'viper-overlay-p (symbol-function 'extentp))
      (fset 'viper-overlay-get (symbol-function 'extent-property))
      (fset 'viper-move-overlay (symbol-function 'set-extent-endpoints))
      (if (viper-window-display-p)
	  (fset 'viper-iconify (symbol-function 'iconify-frame)))
      (cond ((viper-has-face-support-p)
	     (fset 'viper-get-face (symbol-function 'get-face))
	     (fset 'viper-color-defined-p
		   (symbol-function 'valid-color-name-p))
	     )))
  (fset 'viper-read-event (symbol-function 'read-event))
  (fset 'viper-make-overlay (symbol-function 'make-overlay))
  (fset 'viper-overlay-start (symbol-function 'overlay-start))
  (fset 'viper-overlay-end (symbol-function 'overlay-end))
  (fset 'viper-overlay-put (symbol-function 'overlay-put))
  (fset 'viper-overlay-p (symbol-function 'overlayp))
  (fset 'viper-overlay-get (symbol-function 'overlay-get))
  (fset 'viper-move-overlay (symbol-function 'move-overlay))
  (if (viper-window-display-p)
      (fset 'viper-iconify (symbol-function 'iconify-or-deiconify-frame)))
  (cond ((viper-has-face-support-p)
	 (fset 'viper-get-face (symbol-function 'internal-get-face))
	 (fset 'viper-color-defined-p (symbol-function 'x-color-defined-p))
	 )))


(fset 'viper-characterp
      (symbol-function
       (if viper-xemacs-p 'characterp 'integerp)))

(defsubst viper-color-display-p ()
  (if viper-emacs-p
      (x-display-color-p)
    (eq (device-class (selected-device)) 'color)))
   
(defsubst viper-get-cursor-color ()
  (if viper-emacs-p
      (cdr (assoc 'cursor-color (frame-parameters)))
    (color-instance-name (frame-property (selected-frame) 'cursor-color))))
  
;;(defun viper-set-face-pixmap (face pixmap)
;;  "Set face pixmap on a monochrome display."
;;  (if (and (viper-window-display-p) (not (viper-color-display-p)))
;;      (condition-case nil
;;	  (set-face-background-pixmap face pixmap)
;;	(error
;;	 (message "Pixmap not found for %S: %s" (face-name face) pixmap)
;;	 (sit-for 1)))))

  
;; OS/2
(cond ((eq (viper-device-type) 'pm)
       (fset 'viper-color-defined-p
	     (function (lambda (color) (assoc color pm-color-alist))))))
    
;; needed to smooth out the difference between Emacs and XEmacs
;;(defsubst viper-italicize-face (face)
;;  (if viper-xemacs-p
;;      (make-face-italic face)
;;    (make-face-italic face nil 'noerror)))
    
;; test if display is color and the colors are defined
;;(defsubst viper-can-use-colors (&rest colors)
;;  (if (viper-color-display-p)
;;      (not (memq nil (mapcar 'viper-color-defined-p colors)))
;;    ))

;; cursor colors
(defun viper-change-cursor-color (new-color)
  (if (and (viper-window-display-p)  (viper-color-display-p)
	   (stringp new-color) (viper-color-defined-p new-color)
	   (not (string= new-color (viper-get-cursor-color))))
      (modify-frame-parameters
       (selected-frame) (list (cons 'cursor-color new-color)))))
	 
(defun viper-save-cursor-color ()
  (if (and (viper-window-display-p) (viper-color-display-p))
      (let ((color (viper-get-cursor-color)))
	(if (and (stringp color) (viper-color-defined-p color)
		 (not (string= color viper-replace-overlay-cursor-color)))
	    (viper-overlay-put viper-replace-overlay 'viper-cursor-color color)))))
	
;; restore cursor color from replace overlay
(defsubst viper-restore-cursor-color-after-replace ()
  (viper-change-cursor-color
   (viper-overlay-get viper-replace-overlay 'viper-cursor-color)))
(defsubst viper-restore-cursor-color-after-insert ()
  (viper-change-cursor-color viper-saved-cursor-color))
	 
   

;; Check the current version against the major and minor version numbers
;; using op: cur-vers op major.minor If emacs-major-version or
;; emacs-minor-version are not defined, we assume that the current version
;; is hopelessly outdated.  We assume that emacs-major-version and
;; emacs-minor-version are defined.  Otherwise, for Emacs/XEmacs 19, if the
;; current minor version is < 10 (xemacs) or < 23 (emacs) the return value
;; will be nil (when op is =, >, or >=) and t (when op is <, <=), which may be
;; incorrect. However, this gives correct result in our cases, since we are
;; testing for sufficiently high Emacs versions.
(defun viper-check-version (op major minor &optional type-of-emacs)
  (if (and (boundp 'emacs-major-version) (boundp 'emacs-minor-version))
      (and (cond ((eq type-of-emacs 'xemacs) viper-xemacs-p)
		 ((eq type-of-emacs 'emacs) viper-emacs-p)
		 (t t))
	   (cond ((eq op '=) (and (= emacs-minor-version minor)
				  (= emacs-major-version major)))
		 ((memq op '(> >= < <=))
		  (and (or (funcall op emacs-major-version major)
			   (= emacs-major-version major))
		       (if (= emacs-major-version major)
			   (funcall op emacs-minor-version minor)
			 t)))
		 (t
		  (error "%S: Invalid op in viper-check-version" op))))
    (cond ((memq op '(= > >=)) nil)
	  ((memq op '(< <=)) t))))
	  

(defun viper-get-visible-buffer-window (wind)
  (if viper-xemacs-p
      (get-buffer-window wind t)
    (get-buffer-window wind 'visible)))
    
    
;; Return line position.
;; If pos is 'start then returns position of line start.
;; If pos is 'end, returns line end. If pos is 'mid, returns line center.
;; Pos = 'indent returns beginning of indentation.
;; Otherwise, returns point. Current point is not moved in any case."
(defun viper-line-pos (pos)
  (let ((cur-pos (point))
        (result))
    (cond
     ((equal pos 'start)
      (beginning-of-line))
     ((equal pos 'end)
      (end-of-line))
     ((equal pos 'mid)
      (goto-char (+ (viper-line-pos 'start) (viper-line-pos 'end) 2)))
     ((equal pos 'indent)
      (back-to-indentation))
     (t   nil))
    (setq result (point))
    (goto-char cur-pos)
    result))

;; Emacs counts each multibyte character as several positions in the buffer, so
;; we use Emacs' chars-in-region. XEmacs is counting each char as just one pos,
;; so we can simply subtract. 
(defun viper-chars-in-region (beg end &optional preserve-sign)
  (let ((count (abs (if (fboundp 'chars-in-region)
			(chars-in-region beg end)
		      (- end beg)))))
    (if (and (< end beg) preserve-sign)
	(- count)
      count)))

;; Test if POS is between BEG and END
(defsubst viper-pos-within-region (pos beg end)
  (and (>= pos (min beg end)) (>= (max beg end) pos)))


;; Like move-marker but creates a virgin marker if arg isn't already a marker.
;; The first argument must eval to a variable name.
;; Arguments: (var-name position &optional buffer).
;; 
;; This is useful for moving markers that are supposed to be local.
;; For this, VAR-NAME should be made buffer-local with nil as a default.
;; Then, each time this var is used in `viper-move-marker-locally' in a new
;; buffer, a new marker will be created.
(defun viper-move-marker-locally (var pos &optional buffer)
  (if (markerp (eval var))
      ()
    (set var (make-marker)))
  (move-marker (eval var) pos buffer))


;; Print CONDITIONS as a message.
(defun viper-message-conditions (conditions)
  (let ((case (car conditions)) (msg (cdr conditions)))
    (if (null msg)
	(message "%s" case)
      (message "%s: %s" case (mapconcat 'prin1-to-string msg " ")))
    (beep 1)))



;;; List/alist utilities
	
;; Convert LIST to an alist
(defun viper-list-to-alist (lst)
  (let ((alist))
    (while lst
      (setq alist (cons (list (car lst)) alist))
      (setq lst (cdr lst)))
    alist))	

;; Convert ALIST to a list.
(defun viper-alist-to-list (alst)
  (let ((lst))
    (while alst
      (setq lst (cons (car (car alst)) lst))
      (setq alst (cdr alst)))
    lst))

;; Filter ALIST using REGEXP. Return alist whose elements match the regexp.
(defun viper-filter-alist (regexp alst)
  (interactive "s x")
  (let ((outalst) (inalst alst))
    (while (car inalst)
      (if (string-match regexp (car (car inalst)))
	  (setq outalst (cons (car inalst) outalst)))
      (setq inalst (cdr inalst)))
    outalst))    
       
;; Filter LIST using REGEXP. Return list whose elements match the regexp.
(defun viper-filter-list (regexp lst)
  (interactive "s x")
  (let ((outlst) (inlst lst))
    (while (car inlst)
      (if (string-match regexp (car inlst))
	  (setq outlst (cons (car inlst) outlst)))
      (setq inlst (cdr inlst)))
    outlst))    

   
;; Append LIS2 to LIS1, both alists, by side-effect and returns LIS1
;; LIS2 is modified by filtering it: deleting its members of the form
;; \(car elt\) such that (car elt') is in LIS1.
(defun viper-append-filter-alist (lis1 lis2)
  (let ((temp lis1)
	elt)
  
    ;;filter-append the second list
    (while temp
      ;; delete all occurrences
      (while (setq elt (assoc (car (car temp)) lis2))
	(setq lis2 (delq elt lis2)))
      (setq temp (cdr temp)))
    
    (nconc lis1 lis2)))


;;; Support for :e and file globbing

(defun viper-ex-nontrivial-find-file-unix (filespec)
  "Glob the file spec and visit all files matching the spec.
This function is designed to work under Unix. It may also work under VMS.

Users who prefer other types of shells should write their own version of this
function and set the variable `ex-nontrivial-find-file-function'
appropriately." 
  (let ((gshell
	 (cond (ex-unix-type-shell shell-file-name)
	       ((memq system-type '(vax-vms axp-vms)) "*dcl*") ; VAX VMS
	       (t "sh"))) ; probably Unix anyway
	(gshell-options
	 ;; using cond in anticipation of further additions
	 (cond (ex-unix-type-shell-options)
	       ))
	(command (cond (viper-ms-style-os-p (format "\"ls -1 -d %s\"" filespec))
		       (t (format "ls -1 -d %s" filespec))))
	file-list status)
    (save-excursion 
      (set-buffer (get-buffer-create viper-ex-tmp-buf-name))
      (erase-buffer)
      (setq status
	    (if gshell-options
		(call-process gshell nil t nil
			      gshell-options
			      "-c"
			      command)
	      (call-process gshell nil t nil
			    "-c"
			    command)))
      (goto-char (point-min))
      ;; Issue an error, if no match.
      (if (> status 0)
	  (save-excursion
	    (skip-chars-forward " \t\n\j")
	    (if (looking-at "ls:")
		(viper-forward-Word 1))
	    (error "%s: %s"
		   (if (stringp  gshell)
		       gshell
		     "shell")
		   (buffer-substring (point) (viper-line-pos 'end)))
	    ))
      (goto-char (point-min))
      (setq file-list (viper-get-filenames-from-buffer 'one-per-line)))

    (mapcar 'find-file file-list)
    ))

(defun viper-ex-nontrivial-find-file-ms (filespec)
  "Glob the file spec and visit all files matching the spec.
This function is designed to work under MS type systems, such as NT, W95, and
DOS. It may also work under OS/2.

The users of Unix-type shells should be able to use
`viper-ex-nontrivial-find-file-unix', making it into the value of the variable 
`ex-nontrivial-find-file-function'. If this doesn't work, the user may have
to write a custom function, similar to `viper-ex-nontrivial-find-file-unix'."
  (save-excursion 
    (set-buffer (get-buffer-create viper-ex-tmp-buf-name))
    (erase-buffer)
    (insert filespec)
    (goto-char (point-min))
    (mapcar 'find-file
	    (viper-glob-ms-windows-files (viper-get-filenames-from-buffer)))
    ))


;; Interpret the stuff in the buffer as a list of file names
;; return a list of file names listed in the buffer beginning at point
;; If optional arg is supplied, assume each filename is listed on a separate
;; line
(defun viper-get-filenames-from-buffer (&optional one-per-line)
  (let ((skip-chars (if one-per-line "\t\n" " \t\n"))
	 result fname delim)
    (skip-chars-forward skip-chars)
    (while (not (eobp))
      (if (cond ((looking-at "\"")
		 (setq delim ?\")
		 (re-search-forward "[^\"]+" nil t)) ; noerror
		((looking-at "'")
		 (setq delim ?')
		 (re-search-forward "[^']+" nil t)) ; noerror
		(t 
		 (re-search-forward
		  (concat "[^" skip-chars "]+") nil t))) ;noerror
	  (setq fname
		(buffer-substring (match-beginning 0) (match-end 0))))
      (if delim
	  (forward-char 1))
      (skip-chars-forward " \t\n")
      (setq result (cons fname result)))
    result))

;; convert MS-DOS wildcards to regexp
(defun viper-wildcard-to-regexp (wcard)
  (save-excursion
    (set-buffer (get-buffer-create viper-ex-tmp-buf-name))
    (erase-buffer)
    (insert wcard)
    (goto-char (point-min))
    (while (not (eobp))
      (skip-chars-forward "^*?.\\\\")
      (cond ((eq (char-after (point)) ?*) (insert ".")(forward-char 1))
	    ((eq (char-after (point)) ?.) (insert "\\")(forward-char 1))
	    ((eq (char-after (point)) ?\\) (insert "\\")(forward-char 1))
	    ((eq (char-after (point)) ??) (delete-char 1)(insert ".")))
      )
    (buffer-string)
    ))


;; glob windows files
;; LIST is expected to be in reverse order
(defun viper-glob-ms-windows-files (list)
  (let ((tmp list)
	(case-fold-search t)
	tmp2)
    (while tmp
      (setq tmp2 (cons (directory-files 
			;; the directory part
			(or (file-name-directory (car tmp))
			    "")
			t  ; return full names
			;; the regexp part: globs the file names
			(concat "^"
				(viper-wildcard-to-regexp
				 (file-name-nondirectory (car tmp)))
				"$"))
		       tmp2))
      (setq tmp (cdr tmp)))
    (reverse (apply 'append tmp2))))


;;; Insertion ring

;; Rotate RING's index. DIRection can be positive or negative.
(defun viper-ring-rotate1 (ring dir)
  (if (and (ring-p ring) (> (ring-length ring) 0))
      (progn
	(setcar ring (cond ((> dir 0)
			    (ring-plus1 (car ring) (ring-length ring)))
			   ((< dir 0)
			    (ring-minus1 (car ring) (ring-length ring)))
			   ;; don't rotate if dir = 0
			   (t (car ring))))
	(viper-current-ring-item ring)
	)))
	
(defun viper-special-ring-rotate1 (ring dir)
  (if (memq viper-intermediate-command
	    '(repeating-display-destructive-command
	      repeating-insertion-from-ring))
      (viper-ring-rotate1 ring dir)
    ;; don't rotate otherwise
    (viper-ring-rotate1 ring 0)))
    
;; current ring item; if N is given, then so many items back from the
;; current
(defun viper-current-ring-item (ring &optional n)
  (setq n (or n 0))
  (if (and (ring-p ring) (> (ring-length ring) 0))
      (aref (cdr (cdr ring)) (mod (- (car ring) 1 n) (ring-length ring)))))
    
;; push item onto ring. the second argument is a ring-variable, not value.
(defun viper-push-onto-ring (item ring-var)
  (or (ring-p (eval ring-var))
      (set ring-var (make-ring (eval (intern (format "%S-size" ring-var))))))
  (or (null item) ; don't push nil
      (and (stringp item) (string= item "")) ; or empty strings
      (equal item (viper-current-ring-item (eval ring-var))) ; or old stuff
      ;; Since viper-set-destructive-command checks if we are inside
      ;; viper-repeat, we don't check whether this-command-keys is a `.'.  The
      ;; cmd viper-repeat makes a call to the current function only if `.' is
      ;; executing a command from the command history. It doesn't call the
      ;; push-onto-ring function if `.' is simply repeating the last
      ;; destructive command.  We only check for ESC (which happens when we do
      ;; insert with a prefix argument, or if this-command-keys doesn't give
      ;; anything meaningful (in that case we don't know what to show to the
      ;; user).
      (and (eq ring-var 'viper-command-ring)
	   (string-match "\\([0-9]*\e\\|^[ \t]*$\\|escape\\)"
			 (viper-array-to-string (this-command-keys))))
      (viper-ring-insert (eval ring-var) item))
  )
  

;; removing elts from ring seems to break it
(defun viper-cleanup-ring (ring)
  (or (< (ring-length ring) 2)
      (null (viper-current-ring-item ring))
      ;; last and previous equal
      (if (equal (viper-current-ring-item ring)
		 (viper-current-ring-item ring 1))
	  (viper-ring-pop ring))))
	  
;; ring-remove seems to be buggy, so we concocted this for our purposes.
(defun viper-ring-pop (ring)
  (let* ((ln (ring-length ring))
	 (vec (cdr (cdr ring)))
	 (veclen (length vec))
	 (hd (car ring))
	 (idx (max 0 (ring-minus1 hd ln)))
	 (top-elt (aref vec idx)))
	
	;; shift elements
	(while (< (1+ idx) veclen)
	  (aset vec idx (aref vec (1+ idx)))
	  (setq idx (1+ idx)))
	(aset vec idx nil)
	
	(setq hd (max 0 (ring-minus1 hd ln)))
	(if (= hd (1- ln)) (setq hd 0))
	(setcar ring hd) ; move head
	(setcar (cdr ring) (max 0 (1- ln))) ; adjust length
	top-elt
	))
	
(defun viper-ring-insert (ring item)
  (let* ((ln (ring-length ring))
	 (vec (cdr (cdr ring)))
	 (veclen (length vec))
	 (hd (car ring))
	 (vecpos-after-hd (if (= hd 0) ln hd))
	 (idx ln))
	 
    (if (= ln veclen)
	(progn
	  (aset vec hd item) ; hd is always 1+ the actual head index in vec
	  (setcar ring (ring-plus1 hd ln)))
      (setcar (cdr ring) (1+ ln))
      (setcar ring (ring-plus1 vecpos-after-hd (1+ ln)))
      (while (and (>= idx vecpos-after-hd) (> ln 0))
	(aset vec idx (aref vec (1- idx)))
	(setq idx (1- idx)))
      (aset vec vecpos-after-hd item))
    item))
	

;;; String utilities

;; If STRING is longer than MAX-LEN, truncate it and print ...... instead
;; PRE-STRING is a string to prepend to the abbrev string.
;; POST-STRING is a string to append to the abbrev string.
;; ABBREV_SIGN is a string to be inserted before POST-STRING
;; if the orig string was truncated. 
(defun viper-abbreviate-string (string max-len
				     pre-string post-string abbrev-sign)
  (let (truncated-str)
    (setq truncated-str
	  (if (stringp string) 
	      (substring string 0 (min max-len (length string)))))
    (cond ((null truncated-str) "")
	  ((> (length string) max-len)
	   (format "%s%s%s%s"
		   pre-string truncated-str abbrev-sign post-string))
	  (t (format "%s%s%s" pre-string truncated-str post-string)))))

;; tells if we are over a whitespace-only line
(defsubst viper-over-whitespace-line ()
  (save-excursion
    (beginning-of-line)
    (looking-at "^[ \t]*$")))
	  

;;; Saving settings in custom file

;; Save the current setting of VAR in CUSTOM-FILE.
;; If given, MESSAGE is a message to be displayed after that.
;; This message is erased after 2 secs, if erase-msg is non-nil.
;; Arguments: var message custom-file &optional erase-message
(defun viper-save-setting (var message custom-file &optional erase-msg)
  (let* ((var-name (symbol-name var))
	 (var-val (if (boundp var) (eval var)))
	 (regexp (format "^[^;]*%s[ \t\n]*[a-zA-Z---_']*[ \t\n)]" var-name))
	 (buf (find-file-noselect (substitute-in-file-name custom-file)))
	)
    (message message)
    (save-excursion
      (set-buffer buf)
      (goto-char (point-min))
      (if (re-search-forward regexp nil t)
	  (let ((reg-end (1- (match-end 0))))
	    (search-backward var-name)
	    (delete-region (match-beginning 0) reg-end)
	    (goto-char (match-beginning 0))
	    (insert (format "%s  '%S" var-name var-val)))
	(goto-char (point-max))
	(if (not (bolp)) (insert "\n"))
	(insert (format "(setq %s '%S)\n" var-name var-val)))
      (save-buffer))
      (kill-buffer buf)
      (if erase-msg
	  (progn
	    (sit-for 2)
	    (message "")))
      ))
      
;; Save STRING in CUSTOM-FILE. If PATTERN is non-nil, remove strings that
;; match this pattern.
(defun viper-save-string-in-file (string custom-file &optional pattern)
  (let ((buf (find-file-noselect (substitute-in-file-name custom-file))))
    (save-excursion
      (set-buffer buf)
      (goto-char (point-min))
      (if pattern (delete-matching-lines pattern))
      (goto-char (point-max))
      (if string (insert string))
      (save-buffer))
    (kill-buffer buf)
    ))
    

;;; Overlays

;; Search

(defun viper-flash-search-pattern ()
  (if (viper-overlay-p viper-search-overlay)
      (viper-move-overlay
       viper-search-overlay (match-beginning 0) (match-end 0))
    (setq viper-search-overlay
	  (viper-make-overlay
	   (match-beginning 0) (match-end 0) (current-buffer))))
  
  (viper-overlay-put
   viper-search-overlay 'priority viper-search-overlay-priority)
  (if (viper-has-face-support-p)
      (progn
	(viper-overlay-put viper-search-overlay 'face viper-search-face)
	(sit-for 2)
	(viper-overlay-put viper-search-overlay 'face nil))))


;; Replace state

(defsubst viper-move-replace-overlay (beg end)
  (viper-move-overlay viper-replace-overlay beg end))
  
(defun viper-set-replace-overlay (beg end)
  (if (viper-overlay-p viper-replace-overlay)
      (viper-move-replace-overlay beg end)
    (setq viper-replace-overlay (viper-make-overlay beg end (current-buffer)))
    ;; never detach
    (viper-overlay-put
     viper-replace-overlay (if viper-emacs-p 'evaporate 'detachable) nil)
    (viper-overlay-put 
     viper-replace-overlay 'priority viper-replace-overlay-priority)
    ;; If Emacs will start supporting overlay maps, as it currently supports
    ;; text-property maps, we could do away with viper-replace-minor-mode and
    ;; just have keymap attached to replace overlay.
    ;;(viper-overlay-put
    ;; viper-replace-overlay
    ;; (if viper-xemacs-p 'keymap 'local-map)
    ;; viper-replace-map)
    ) 
  (if (viper-has-face-support-p)
      (viper-overlay-put
       viper-replace-overlay 'face viper-replace-overlay-face))
  (viper-save-cursor-color)
  (viper-change-cursor-color viper-replace-overlay-cursor-color)
  )
  
      
(defun viper-set-replace-overlay-glyphs (before-glyph after-glyph)
  (if (or (not (viper-has-face-support-p))
	  viper-use-replace-region-delimiters)
      (let ((before-name (if viper-xemacs-p 'begin-glyph 'before-string))
	    (after-name (if viper-xemacs-p 'end-glyph 'after-string)))
	(viper-overlay-put viper-replace-overlay before-name before-glyph)
	(viper-overlay-put viper-replace-overlay after-name after-glyph))))
  
(defun viper-hide-replace-overlay ()
  (viper-set-replace-overlay-glyphs nil nil)
  (viper-restore-cursor-color-after-replace)
  (viper-restore-cursor-color-after-insert)
  (if (viper-has-face-support-p)
      (viper-overlay-put viper-replace-overlay 'face nil)))

    
(defsubst viper-replace-start ()
  (viper-overlay-start viper-replace-overlay))
(defsubst viper-replace-end ()
  (viper-overlay-end viper-replace-overlay))
 

;; Minibuffer

(defun viper-set-minibuffer-overlay ()
  (viper-check-minibuffer-overlay)
  (if (viper-has-face-support-p)
      (progn
	(viper-overlay-put
	 viper-minibuffer-overlay 'face viper-minibuffer-current-face)
	(viper-overlay-put 
	 viper-minibuffer-overlay 'priority viper-minibuffer-overlay-priority)
	;; never detach
	(viper-overlay-put
	 viper-minibuffer-overlay
	 (if viper-emacs-p 'evaporate 'detachable)
	 nil)
	;; make viper-minibuffer-overlay open-ended
	;; In emacs, it is made open ended at creation time
	(if viper-xemacs-p
	    (progn
	      (viper-overlay-put viper-minibuffer-overlay 'start-open nil)
	      (viper-overlay-put viper-minibuffer-overlay 'end-open nil)))
	)))
       
(defun viper-check-minibuffer-overlay ()
  (or (viper-overlay-p viper-minibuffer-overlay)
      (setq viper-minibuffer-overlay
	    (if viper-xemacs-p
		(viper-make-overlay 1 (1+ (buffer-size)) (current-buffer))
	      ;; make overlay open-ended
	      (viper-make-overlay
	       1 (1+ (buffer-size)) (current-buffer) nil 'rear-advance)))
      ))


(defsubst viper-is-in-minibuffer ()
  (string-match "\*Minibuf-" (buffer-name)))
  


;;; XEmacs compatibility

(defun viper-abbreviate-file-name (file)
  (if viper-emacs-p
      (abbreviate-file-name file)
    ;; XEmacs requires addl argument
    (abbreviate-file-name file t)))
    
;; Sit for VAL milliseconds. XEmacs doesn't support the millisecond arg 
;; in sit-for, so this function smoothes out the differences.
(defsubst viper-sit-for-short (val &optional nodisp)
  (if viper-xemacs-p
      (sit-for (/ val 1000.0) nodisp)
    (sit-for 0 val nodisp)))

;; EVENT may be a single event of a sequence of events
(defsubst viper-ESC-event-p (event)
  (let ((ESC-keys '(?\e (control \[) escape))
	(key (viper-event-key event)))
    (member key ESC-keys)))

;; checks if object is a marker, has a buffer, and points to within that buffer
(defun viper-valid-marker (marker)
  (if (and (markerp marker) (marker-buffer marker))
      (let ((buf (marker-buffer marker))
	    (pos (marker-position marker)))
	(save-excursion
	  (set-buffer buf)
	  (and (<= pos (point-max)) (<= (point-min) pos))))))
  
(defsubst viper-mark-marker ()
  (if viper-xemacs-p
      (mark-marker t)
    (mark-marker)))

;; like (set-mark-command nil) but doesn't push twice, if (car mark-ring)
;; is the same as (mark t).
(defsubst viper-set-mark-if-necessary ()
  (setq mark-ring (delete (viper-mark-marker) mark-ring))
  (set-mark-command nil))
       
;; In transient mark mode (zmacs mode), it is annoying when regions become
;; highlighted due to Viper's pushing marks. So, we deactivate marks, unless
;; the user explicitly wants highlighting, e.g., by hitting '' or ``
(defun viper-deactivate-mark ()
  (if viper-xemacs-p
      (zmacs-deactivate-region)
    (deactivate-mark)))

(defsubst viper-leave-region-active ()
  (if viper-xemacs-p
      (setq zmacs-region-stays t)))

;; Check if arg is a valid character for register
;; TYPE is a list that can contain `letter', `Letter', and `digit'.
;; Letter means lowercase letters, Letter means uppercase letters, and
;; digit means digits from 1 to 9.
;; If TYPE is nil, then down/uppercase letters and digits are allowed.
(defun viper-valid-register (reg &optional type)
  (or type (setq type '(letter Letter digit)))
  (or (if (memq 'letter type)
	  (and (<= ?a reg) (<= reg ?z)))
      (if (memq 'digit type)
	  (and (<= ?1 reg) (<= reg ?9)))
      (if (memq 'Letter type)
	  (and (<= ?A reg) (<= reg ?Z)))
      ))

    
(defsubst viper-events-to-keys (events)
  (cond (viper-xemacs-p (events-to-keys events))
	(t events)))
		  
	
;; This is here because Emacs changed the way local hooks work.
;;
;;Add to the value of HOOK the function FUNCTION.
;;FUNCTION is not added if already present.
;;FUNCTION is added (if necessary) at the beginning of the hook list
;;unless the optional argument APPEND is non-nil, in which case
;;FUNCTION is added at the end.
;;
;;HOOK should be a symbol, and FUNCTION may be any valid function.  If
;;HOOK is void, it is first set to nil.  If HOOK's value is a single
;;function, it is changed to a list of functions."
(defun viper-add-hook (hook function &optional append)
  (if (not (boundp hook)) (set hook nil))
  ;; If the hook value is a single function, turn it into a list.
  (let ((old (symbol-value hook)))
    (if (or (not (listp old)) (eq (car old) 'lambda))
	(setq old (list old)))
    (if (member function old)
	nil
      (set hook (if append
		    (append old (list function)) ; don't nconc
		  (cons function old))))))

;; This is here because of Emacs's changes in the semantics of add/remove-hooks
;; and due to the bugs they introduced.
;;
;; Remove from the value of HOOK the function FUNCTION.
;; HOOK should be a symbol, and FUNCTION may be any valid function.  If
;; FUNCTION isn't the value of HOOK, or, if FUNCTION doesn't appear in the
;; list of hooks to run in HOOK, then nothing is done.  See `viper-add-hook'."
(defun viper-remove-hook (hook function)
  (if (or (not (boundp hook))		;unbound symbol, or
	  (null (symbol-value hook))	;value is nil, or
	  (null function))		;function is nil, then
      nil				;Do nothing.
    (let ((hook-value (symbol-value hook)))
      (if (consp hook-value)
	  ;; don't side-effect the list
	  (setq hook-value (delete function (copy-sequence hook-value)))
	(if (equal hook-value function)
	    (setq hook-value nil)))
      (set hook hook-value))))

    
;; it is suggested that an event must be copied before it is assigned to
;; last-command-event in XEmacs
(defun viper-copy-event (event)
  (if viper-xemacs-p
      (copy-event event)
    event))
    
;; like read-event, but in XEmacs also try to convert to char, if possible
(defun viper-read-event-convert-to-char ()
  (let (event)
    (if viper-emacs-p
	(read-event)
      (setq event (next-command-event))
      (or (event-to-character event)
	  event))
    ))

;; This function lets function-key-map convert key sequences into logical
;; keys. This does a better job than viper-read-event when it comes to kbd
;; macros, since it enables certain macros to be shared between X and TTY modes
;; by correctly mapping key sequences for Left/Right/... (one an ascii
;; terminal) into logical keys left, right, etc.
(defun viper-read-key () 
  (let ((overriding-local-map viper-overriding-map) 
	(inhibit-quit t)
	help-char key) 
    (use-global-map viper-overriding-map) 
    (unwind-protect
	(setq key (elt (read-key-sequence nil) 0)) 
      (use-global-map global-map))
    key))


;; Emacs has a bug in eventp, which causes (eventp nil) to return (nil)
;; instead of nil, if '(nil) was previously inadvertently assigned to
;; unread-command-events
(defun viper-event-key (event)
  (or (and event (eventp event))
      (error "viper-event-key: Wrong type argument, eventp, %S" event))
  (when (cond (viper-xemacs-p (or (key-press-event-p event)
				  (mouse-event-p event)))
	      (t t))
    (let ((mod (event-modifiers event))
	  basis)
      (setq basis
	    (cond
	     (viper-xemacs-p
	      (cond ((key-press-event-p event)
		     (event-key event))
		    ((button-event-p event)
		     (concat "mouse-" (prin1-to-string (event-button event))))
		    (t 
		     (error "viper-event-key: Unknown event, %S" event))))
	     (t 
	      ;; Emacs doesn't handle capital letters correctly, since
	      ;; \S-a isn't considered the same as A (it behaves as
	      ;; plain `a' instead). So we take care of this here
	      (cond ((and (viper-characterp event) (<= ?A event) (<= event ?Z))
		     (setq mod nil
			   event event))
		    ;; Emacs has the oddity whereby characters 128+char
		    ;; represent M-char *if* this appears inside a string.
		    ;; So, we convert them manually to (meta char).
		    ((and (viper-characterp event)
			  (< ?\C-? event) (<= event 255))
		     (setq mod '(meta)
			   event (- event ?\C-? 1)))
		    ((and (null mod) (eq event 'return))
		     (setq event ?\C-m))
		    ((and (null mod) (eq event 'space))
		     (setq event ?\ ))
		    ((and (null mod) (eq event 'delete))
		     (setq event ?\C-?))
		    ((and (null mod) (eq event 'backspace))
		     (setq event ?\C-h))
		    (t (event-basic-type event)))
	      )))
      (if (viper-characterp basis)
	  (setq basis
		(if (= basis ?\C-?)
		    (list 'control '\?) ; taking care of an emacs bug
		  (intern (char-to-string basis)))))
      (if mod
	  (append mod (list basis))
	basis))))
    
(defun viper-key-to-emacs-key (key)
  (let (key-name char-p modifiers mod-char-list base-key base-key-name)
    (cond (viper-xemacs-p key)

	  ((symbolp key)
	   (setq key-name (symbol-name key))
	   (cond ((= (length key-name) 1) ; character event
		  (string-to-char key-name))
		 ;; Emacs doesn't recognize `return' and `escape' as events on
		 ;; dumb terminals, so we translate them into characters
		 ((and viper-emacs-p (not (viper-window-display-p))
		       (string= key-name "return"))
		  ?\C-m)
		 ((and viper-emacs-p (not (viper-window-display-p))
		       (string= key-name "escape"))
		  ?\e)
		 ;; pass symbol-event as is
		 (t key)))

	  ((listp key)
	   (setq modifiers (subseq key 0 (1- (length key)))
		 base-key (viper-seq-last-elt key)
		 base-key-name (symbol-name base-key)
		 char-p (= (length base-key-name) 1))
	   (setq mod-char-list
		 (mapcar
		  '(lambda (elt) (upcase (substring (symbol-name elt) 0 1)))
		  modifiers))
	   (if char-p
	       (setq key-name
		     (car (read-from-string
			   (concat
			    "?\\"
			    (mapconcat 'identity mod-char-list "-\\")
			    "-"
			    base-key-name))))
	     (setq key-name
		   (intern
		    (concat
		     (mapconcat 'identity mod-char-list "-")
		     "-"
		     base-key-name))))))
    ))


;; Args can be a sequence of events, a string, or a Viper macro.  Will try to
;; convert events to keys and, if all keys are regular printable
;; characters, will return a string. Otherwise, will return a string
;; representing a vector of converted events. If the input was a Viper macro,
;; will return a string that represents this macro as a vector.
(defun viper-array-to-string (event-seq)
  (let (temp temp2)
    (cond ((stringp event-seq) event-seq)
	  ((viper-event-vector-p event-seq)
	    (setq temp (mapcar 'viper-event-key event-seq))
	    (cond ((viper-char-symbol-sequence-p temp)
		   (mapconcat 'symbol-name temp ""))
		  ((and (viper-char-array-p
			 (setq temp2 (mapcar 'viper-key-to-character temp))))
		   (mapconcat 'char-to-string temp2 ""))
		  (t (prin1-to-string (vconcat temp)))))
	  ((viper-char-symbol-sequence-p event-seq)
	   (mapconcat 'symbol-name event-seq ""))
	  ((and (vectorp event-seq) 
		(viper-char-array-p
		 (setq temp (mapcar 'viper-key-to-character event-seq))))
	   (mapconcat 'char-to-string temp ""))
	  (t (prin1-to-string event-seq)))))

(defun viper-key-press-events-to-chars (events)
  (mapconcat (if viper-emacs-p
		 'char-to-string
	       (function
		(lambda (elt) (char-to-string (event-to-character elt)))))
	     events
	     ""))
	   
    
;; Uses different timeouts for ESC-sequences and others
(defsubst viper-fast-keysequence-p ()
  (not (viper-sit-for-short 
	(if (viper-ESC-event-p last-input-event)
	    viper-ESC-keyseq-timeout
	  viper-fast-keyseq-timeout)
	t)))
    
(defun viper-read-char-exclusive ()
  (let (char
	(echo-keystrokes 1))
    (while (null char)
      (condition-case nil
	  (setq char (read-char))
	(error
	 ;; skip event if not char
	 (viper-read-event))))
    char))

;; key is supposed to be in viper's representation, e.g., (control l), a
;; character, etc.
(defun viper-key-to-character (key)
  (cond ((eq key 'space) ?\ )
	((eq key 'delete) ?\C-?)
	((eq key 'return) ?\C-m)
	((eq key 'backspace) ?\C-h)
	((and (symbolp key)
	      (= 1 (length (symbol-name key))))
	 (string-to-char (symbol-name key)))
	((and (listp key)
	      (eq (car key) 'control)
	      (symbol-name (nth 1 key))
	      (= 1 (length (symbol-name (nth 1 key)))))
	 (read (format "?\\C-%s" (symbol-name (nth 1 key)))))
	(t key)))
    
      
(defun viper-setup-master-buffer (&rest other-files-or-buffers)
  "Set up the current buffer as a master buffer.
Arguments become related buffers. This function should normally be used in
the `Local variables' section of a file."
  (setq viper-related-files-and-buffers-ring 
	(make-ring (1+ (length other-files-or-buffers))))
  (mapcar '(lambda (elt)
	     (viper-ring-insert viper-related-files-and-buffers-ring elt))
	  other-files-or-buffers)
  (viper-ring-insert viper-related-files-and-buffers-ring (buffer-name))
  )

;;; Movement utilities

;; Characters that should not be considered as part of the word, in reformed-vi
;; syntax mode.
(defconst viper-non-word-characters-reformed-vi
  "!@#$%^&*()-+=|\\~`{}[];:'\",<.>/?")
;; These are characters that are not to be considered as parts of a word in
;; Viper.
;; Set each time state changes and at loading time
(viper-deflocalvar viper-non-word-characters  nil)

;; must be buffer-local
(viper-deflocalvar viper-ALPHA-char-class "w"
  "String of syntax classes characterizing Viper's alphanumeric symbols.
In addition, the symbol `_' may be considered alphanumeric if
`viper-syntax-preference' is `strict-vi' or `reformed-vi'.")

(defconst viper-strict-ALPHA-chars "a-zA-Z0-9_"
  "Regexp matching the set of alphanumeric characters acceptable to strict
Vi.")
(defconst viper-strict-SEP-chars " \t\n"
  "Regexp matching the set of alphanumeric characters acceptable to strict
Vi.")
(defconst viper-strict-SEP-chars-sans-newline " \t"
  "Regexp matching the set of alphanumeric characters acceptable to strict
Vi.")

(defconst viper-SEP-char-class " -"
  "String of syntax classes for Vi separators.
Usually contains ` ', linefeed, TAB or formfeed.")


;; Set Viper syntax classes and related variables according to
;; `viper-syntax-preference'.  
(defun viper-update-syntax-classes (&optional set-default)
  (let ((preference (cond ((eq viper-syntax-preference 'emacs)
			   "w")   ; Viper words have only Emacs word chars
			  ((eq viper-syntax-preference 'extended)
			   "w_")  ; Viper words have Emacs word & symbol chars
			  (t "w"))) ; Viper words are Emacs words plus `_'
	(non-word-chars (cond ((eq viper-syntax-preference 'reformed-vi)
			       (viper-string-to-list
				viper-non-word-characters-reformed-vi))
			      (t nil))))
    (if set-default
	(setq-default viper-ALPHA-char-class preference
		      viper-non-word-characters non-word-chars)
      (setq viper-ALPHA-char-class preference
	    viper-non-word-characters non-word-chars))
    ))

;; SYMBOL is used because customize requires it, but it is ignored, unless it
;; is `nil'. If nil, use setq.
(defun viper-set-syntax-preference (&optional symbol value)
  "Set Viper syntax preference.
If called interactively or if SYMBOL is nil, sets syntax preference in current
buffer. If called non-interactively, preferably via the customization widget,
sets the default value."
  (interactive)
  (or value
      (setq value
	    (completing-read
	     "Viper syntax preference: "
	     '(("strict-vi") ("reformed-vi") ("extended") ("emacs"))
	     nil 'require-match)))
  (if (stringp value) (setq value (intern value)))
  (or (memq value '(strict-vi reformed-vi extended emacs))
      (error "Invalid Viper syntax preference, %S" value))
  (if symbol
      (setq-default viper-syntax-preference value)
    (setq viper-syntax-preference value))
  (viper-update-syntax-classes))

(defcustom viper-syntax-preference 'reformed-vi
  "*Syntax type characterizing Viper's alphanumeric symbols.
Affects movement and change commands that deal with Vi-style words.
Works best when set in the hooks to various major modes.

`strict-vi' means Viper words are (hopefully) exactly as in Vi.

`reformed-vi' means Viper words are like Emacs words \(as determined using
Emacs syntax tables, which are different for different major modes\) with two
exceptions: the symbol `_' is always part of a word and typical Vi non-word
symbols, such as `,',:,\",),{, etc., are excluded.
This behaves very close to `strict-vi', but also works well with non-ASCII
characters from various alphabets.

`extended' means Viper word constituents are symbols that are marked as being
parts of words OR symbols in Emacs syntax tables.
This is most appropriate for major modes intended for editing programs.

`emacs' means Viper words are the same as Emacs words as specified by Emacs
syntax tables.
This option is appropriate if you like Emacs-style words."
  :type '(radio (const strict-vi) (const reformed-vi) 
		 (const extended) (const emacs))
  :set 'viper-set-syntax-preference
  :group 'viper)
(make-variable-buffer-local 'viper-syntax-preference)


;; addl-chars are characters to be temporarily considered as alphanumerical
(defun viper-looking-at-alpha (&optional addl-chars)
  (or (stringp addl-chars) (setq addl-chars ""))
  (if (eq viper-syntax-preference 'reformed-vi)
      (setq addl-chars (concat addl-chars "_")))
  (let ((char (char-after (point))))
    (if char
	(if (eq viper-syntax-preference 'strict-vi)
	    (looking-at (concat "[" viper-strict-ALPHA-chars addl-chars "]"))
	  (or
	   ;; or one of the additional chars being asked to include
	   (memq char (viper-string-to-list addl-chars))
	   (and
	    ;; not one of the excluded word chars
	    (not (memq char viper-non-word-characters))
	    ;; char of the Viper-word syntax class
	    (memq (char-syntax char)
		  (viper-string-to-list viper-ALPHA-char-class))))))
    ))

(defun viper-looking-at-separator ()
  (let ((char (char-after (point))))
    (if char
	(if (eq viper-syntax-preference 'strict-vi)
	    (memq char (viper-string-to-list viper-strict-SEP-chars))
	  (or (eq char ?\n) ; RET is always a separator in Vi
	      (memq (char-syntax char)
		    (viper-string-to-list viper-SEP-char-class)))))
    ))

(defsubst viper-looking-at-alphasep (&optional addl-chars)
  (or (viper-looking-at-separator) (viper-looking-at-alpha addl-chars)))

(defun viper-skip-alpha-forward (&optional addl-chars)
  (or (stringp addl-chars) (setq addl-chars ""))
  (viper-skip-syntax
   'forward 
   (cond ((eq viper-syntax-preference 'strict-vi)
	  "")
	 (t viper-ALPHA-char-class))
   (cond ((eq viper-syntax-preference 'strict-vi)
	  (concat viper-strict-ALPHA-chars addl-chars))
	 (t addl-chars))))

(defun viper-skip-alpha-backward (&optional addl-chars)
  (or (stringp addl-chars) (setq addl-chars ""))
  (viper-skip-syntax
   'backward 
   (cond ((eq viper-syntax-preference 'strict-vi)
	  "")
	 (t viper-ALPHA-char-class))
   (cond ((eq viper-syntax-preference 'strict-vi)
	  (concat viper-strict-ALPHA-chars addl-chars))
	 (t addl-chars))))

;; weird syntax tables may confuse strict-vi style
(defsubst viper-skip-all-separators-forward (&optional within-line)
  (if (eq viper-syntax-preference 'strict-vi)
      (if within-line 
	  (skip-chars-forward viper-strict-SEP-chars-sans-newline)
	(skip-chars-forward viper-strict-SEP-chars))
    (viper-skip-syntax 'forward
		       viper-SEP-char-class
		       (or within-line "\n")
		       (if within-line (viper-line-pos 'end)))))
(defsubst viper-skip-all-separators-backward (&optional within-line)
  (if (eq viper-syntax-preference 'strict-vi)
      (if within-line 
	  (skip-chars-backward viper-strict-SEP-chars-sans-newline)
	(skip-chars-backward viper-strict-SEP-chars))
    (viper-skip-syntax 'backward
		       viper-SEP-char-class
		       (or within-line "\n")
		       (if within-line (viper-line-pos 'start)))))
(defun viper-skip-nonseparators (direction)
  (viper-skip-syntax
   direction
   (concat "^" viper-SEP-char-class)
   nil
   (viper-line-pos (if (eq direction 'forward) 'end 'start))))


;; skip over non-word constituents and non-separators
(defun viper-skip-nonalphasep-forward ()
  (if (eq viper-syntax-preference 'strict-vi)
      (skip-chars-forward
       (concat "^" viper-strict-SEP-chars viper-strict-ALPHA-chars))
    (viper-skip-syntax
     'forward
     (concat "^" viper-ALPHA-char-class viper-SEP-char-class)
     ;; Emacs may consider some of these as words, but we don't want them
     viper-non-word-characters 
     (viper-line-pos 'end))))
(defun viper-skip-nonalphasep-backward ()
  (if (eq viper-syntax-preference 'strict-vi)
      (skip-chars-backward
       (concat "^" viper-strict-SEP-chars viper-strict-ALPHA-chars))
    (viper-skip-syntax
     'backward
     (concat "^" viper-ALPHA-char-class viper-SEP-char-class)
     ;; Emacs may consider some of these as words, but we don't want them
     viper-non-word-characters
     (viper-line-pos 'start))))

;; Skip SYNTAX like skip-syntax-* and ADDL-CHARS like skip-chars-*
;; Return the number of chars traveled.
;; Both SYNTAX or ADDL-CHARS can be strings or lists of characters.
;; When SYNTAX is "w", then viper-non-word-characters are not considered to be
;; words, even if Emacs syntax table says they are.
(defun viper-skip-syntax (direction syntax addl-chars &optional limit)
  (let ((total 0)
	(local 1)
	(skip-chars-func
	 (if (eq direction 'forward)
	     'skip-chars-forward 'skip-chars-backward))
	(skip-syntax-func
	 (if (eq direction 'forward)
	     'viper-forward-char-carefully 'viper-backward-char-carefully))
	char-looked-at syntax-of-char-looked-at negated-syntax)
    (setq addl-chars
	  (cond ((listp addl-chars) (viper-charlist-to-string addl-chars))
		((stringp addl-chars) addl-chars)
		(t "")))
    (setq syntax
	  (cond ((listp syntax) syntax)
		((stringp syntax) (viper-string-to-list syntax))
		(t nil)))
    (if (memq ?^ syntax) (setq negated-syntax t))

    (while (and (not (= local 0)) (not (eobp)))
      (setq char-looked-at (viper-char-at-pos direction)
	    ;; if outside the range, set to nil
	    syntax-of-char-looked-at (if char-looked-at
					 (char-syntax char-looked-at)))
      (setq local
	    (+ (if (and
		    (cond ((and limit (eq direction 'forward))
			   (< (point) limit))
			  (limit ; backward & limit
			   (> (point) limit))
			  (t t)) ; no limit
		    ;; char under/before cursor has appropriate syntax
		    (if negated-syntax
			(not (memq syntax-of-char-looked-at syntax))
		      (memq syntax-of-char-looked-at syntax))
		    ;; if char-syntax class is "word", make sure it is not one
		    ;; of the excluded characters
		    (if (and (eq syntax-of-char-looked-at ?w)
			     (not negated-syntax))
			(not (memq char-looked-at viper-non-word-characters))
		      t))
		   (funcall skip-syntax-func 1)
		 0)
	       (funcall skip-chars-func addl-chars limit)))
      (setq total (+ total local)))
    total
    ))
  

  
(provide 'viper-util)
  

;;; Local Variables:
;;; eval: (put 'viper-deflocalvar 'lisp-indent-hook 'defun)
;;; End:

;;;  viper-util.el ends here
