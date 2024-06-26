;;; viper-ex.el --- functions implementing the Ex commands for Viper

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

(provide 'viper-ex)

;; Compiler pacifier
(defvar read-file-name-map)
(defvar viper-use-register)
(defvar viper-s-string)
(defvar viper-shift-width)
(defvar viper-ex-history)
(defvar viper-related-files-and-buffers-ring)
(defvar viper-local-search-start-marker)
(defvar viper-expert-level)
(defvar viper-custom-file-name)
(defvar viper-case-fold-search)
(defvar explicit-shell-file-name)

;; loading happens only in non-interactive compilation
;; in order to spare non-viperized emacs from being viperized
(if noninteractive
    (eval-when-compile
      (let ((load-path (cons (expand-file-name ".") load-path)))
	(or (featurep 'viper-util)
	    (load "viper-util.el" nil nil 'nosuffix))
	(or (featurep 'viper-keym)
	    (load "viper-keym.el" nil nil 'nosuffix))
	(or (featurep 'viper-cmd)
	    (load "viper-cmd.el" nil nil 'nosuffix))
	)))
;; end pacifier

(require 'viper-util)

(defgroup viper-ex nil
  "Viper support for Ex commands"
  :prefix "ex-"
  :group 'viper)



;;; Variables

(defconst viper-ex-work-buf-name " *ex-working-space*")
(defconst viper-ex-work-buf (get-buffer-create viper-ex-work-buf-name))
(defconst viper-ex-tmp-buf-name " *ex-tmp*")


;;; Variable completion in :set command
  
;; The list of Ex commands. Used for completing command names.
(defconst ex-token-alist
  '(("!") ("=") (">") ("&") ("~")
    ("yank") ("xit") ("WWrite") ("Write") ("write") ("wq") ("visual") 
    ("version") ("vglobal") ("unmap") ("undo") ("tag") ("transfer") ("suspend")
    ("substitute") ("submitReport") ("stop")  ("sr") ("source") ("shell")
    ("set") ("rewind") ("recover") ("read") ("quit") ("pwd")
    ("put") ("preserve") ("PreviousRelatedFile") ("RelatedFile")
    ("next") ("Next") ("move") ("mark") ("map") ("kmark") ("join")
    ("help") ("goto") ("global") ("file") ("edit") ("delete") ("copy")
    ("chdir") ("cd") ("Buffer") ("buffer") ("args"))  )

;; A-list of Ex variables that can be set using the :set command.
(defconst ex-variable-alist 
  '(("wrapscan") ("ws") ("wrapmargin") ("wm")
    ("tabstop-global") ("ts-g") ("tabstop") ("ts")
    ("showmatch") ("sm") ("shiftwidth") ("sw") ("shell") ("sh")
    ("readonly") ("ro") 
    ("nowrapscan") ("nows") ("noshowmatch") ("nosm")
    ("noreadonly") ("noro") ("nomagic") ("noma")
    ("noignorecase") ("noic")
    ("noautoindent-global") ("noai-g") ("noautoindent") ("noai")
    ("magic") ("ma") ("ignorecase") ("ic")
    ("autoindent-global") ("ai-g") ("autoindent") ("ai") 
    ("all") 
    ))

  

;; Token recognized during parsing of Ex commands (e.g., "read", "comma")
(defvar ex-token nil)

;; Type of token. 
;; If non-nil, gives type of address; if nil, it is a command.
(defvar ex-token-type nil)

;; List of addresses passed to Ex command
(defvar ex-addresses nil)

;; It seems that this flag is used only for `#', `print', and `list', which
;; aren't implemented. Check later.
(defvar ex-flag nil)

;; "buffer" where Ex commands keep deleted data.
;; In Emacs terms, this is a register.
(defvar ex-buffer nil)

;; Value of ex count.
(defvar ex-count nil)

;; Flag indicating that :global Ex command is being executed.
(defvar ex-g-flag nil)
;; Flag indicating that :vglobal Ex command is being executed.
(defvar ex-g-variant nil)

;; Save reg-exp used in substitute.
(defvar ex-reg-exp nil)


;; Replace pattern for substitute.
(defvar ex-repl nil)

;; Pattern for global command.
(defvar ex-g-pat nil)

(defcustom ex-unix-type-shell
  (let ((case-fold-search t))
    (and (stringp shell-file-name)
	 (string-match
	  (concat
	   "\\("
	   "csh$\\|csh.exe$"
	   "\\|"
	   "ksh$\\|ksh.exe$"
	   "\\|"
	   "^sh$\\|sh.exe$"
	   "\\|"
	   "[^a-z]sh$\\|[^a-z]sh.exe$"
	   "\\|"
	   "bash$\\|bash.exe$"
	   "\\)")
	  shell-file-name)))
  "Is the user using a unix-type shell under a non-OS?"
  :type 'boolean
  :group 'viper-ex)

(defcustom ex-unix-type-shell-options
  (let ((case-fold-search t))
    (if ex-unix-type-shell
	(cond ((string-match "\\(csh$\\|csh.exe$\\)" shell-file-name)
	       "-f") ; csh: do it fast
	      ((string-match "\\(bash$\\|bash.exe$\\)" shell-file-name)
	       "-noprofile") ; bash: ignore .profile
	      )))
  "Options to pass to the Unix-style shell. 
Don't put `-c' here, as it is added automatically."
  :type 'string
  :group 'viper-ex)

(defvar ex-nontrivial-find-file-function
  (cond (ex-unix-type-shell 'viper-ex-nontrivial-find-file-unix)
	((eq system-type 'emx) 'viper-ex-nontrivial-find-file-ms) ; OS/2
	(viper-ms-style-os-p 'viper-ex-nontrivial-find-file-ms) ; Microsoft OS
	(viper-vms-os-p 'viper-ex-nontrivial-find-file-unix) ; VMS
	(t  'viper-ex-nontrivial-find-file-unix) ; presumably UNIX
	))

;; Remembers the previous Ex tag.
(defvar ex-tag nil)

;; file used by Ex commands like :r, :w, :n
(defvar ex-file nil)

;; If t, tells Ex that this is a variant-command, i.e., w>>, r!, etc.
(defvar ex-variant nil)

;; Specified the offset of an Ex command, such as :read.
(defvar ex-offset nil)

;; Tells Ex that this is a w>> command.
(defvar ex-append nil)

;; File containing the shell command to be executed at Ex prompt,
;; e.g., :r !date
(defvar ex-cmdfile nil)
  
;; flag used in viper-ex-read-file-name to indicate that we may be reading
;; multiple file names. Used for :edit and :next
(defvar viper-keep-reading-filename nil)

(defcustom ex-cycle-other-window t
  "*If t, :n and :b cycles through files and buffers in other window.
Then :N and :B cycles in the current window. If nil, this behavior is
reversed."
  :type 'boolean
  :group 'viper-ex)

(defcustom ex-cycle-through-non-files nil
  "*Cycle through *scratch* and other buffers that don't visit any file."
  :type 'boolean
  :group 'viper-ex)

;; Last shell command executed with :! command.
(defvar viper-ex-last-shell-com nil)
  
;; Indicates if Minibuffer was exited temporarily in Ex-command.
(defvar viper-incomplete-ex-cmd nil)
  
;; Remembers the last ex-command prompt.
(defvar viper-last-ex-prompt "")


;;; Code
  
;; Check if ex-token is an initial segment of STR
(defun viper-check-sub (str)
  (let ((length (length ex-token)))
    (if (and (<= length (length str))
  	     (string= ex-token (substring str 0 length)))
	(setq ex-token str)
      (setq ex-token-type 'non-command))))

;; Get a complete ex command
(defun viper-get-ex-com-subr ()
  (let (case-fold-search)
    (set-mark (point))
    (re-search-forward "[a-zA-Z][a-zA-Z]*")
    (setq ex-token-type 'command)
    (setq ex-token (buffer-substring (point) (mark t)))
    (exchange-point-and-mark)
    (cond ((looking-at "a")
	   (cond ((looking-at "ab") (viper-check-sub "abbreviate"))
		 ((looking-at "ar") (viper-check-sub "args"))
		 (t (viper-check-sub "append"))))
	  ((looking-at "h") (viper-check-sub "help"))
	  ((looking-at "c")
	   (cond ((looking-at "cd") (viper-check-sub "cd"))
		 ((looking-at "ch") (viper-check-sub "chdir"))
		 ((looking-at "co") (viper-check-sub "copy"))
		 (t (viper-check-sub "change"))))
	  ((looking-at "d") (viper-check-sub "delete"))
	  ((looking-at "b") (viper-check-sub "buffer"))
	  ((looking-at "B") (viper-check-sub "Buffer"))
	  ((looking-at "e")
	   (if (looking-at "ex") (viper-check-sub "ex")
	     (viper-check-sub "edit")))
	  ((looking-at "f") (viper-check-sub "file"))
	  ((looking-at "g") (viper-check-sub "global"))
	  ((looking-at "i") (viper-check-sub "insert"))
	  ((looking-at "j") (viper-check-sub "join"))
	  ((looking-at "l") (viper-check-sub "list"))
	  ((looking-at "m")
	   (cond ((looking-at "map") (viper-check-sub "map"))
		 ((looking-at "mar") (viper-check-sub "mark"))
		 (t (viper-check-sub "move"))))
	  ((looking-at "k[a-z][^a-z]")
	   (setq ex-token "kmark")
	   (forward-char 1)
	   (exchange-point-and-mark))   ; this is canceled out by another
					; exchange-point-and-mark at the end
	  ((looking-at "k") (viper-check-sub "kmark"))
	  ((looking-at "n") (if (looking-at "nu")
				(viper-check-sub "number")
			      (viper-check-sub "next")))
	  ((looking-at "N") (viper-check-sub "Next"))
	  ((looking-at "o") (viper-check-sub "open"))
	  ((looking-at "p")
	   (cond ((looking-at "pre") (viper-check-sub "preserve"))
		 ((looking-at "pu") (viper-check-sub "put"))
		 ((looking-at "pw") (viper-check-sub "pwd"))
		 (t (viper-check-sub "print"))))
	  ((looking-at "P") (viper-check-sub "PreviousRelatedFile"))
	  ((looking-at "R") (viper-check-sub "RelatedFile"))
	  ((looking-at "q") (viper-check-sub "quit"))
	  ((looking-at "r")
	   (cond ((looking-at "rec") (viper-check-sub "recover"))
		 ((looking-at "rew") (viper-check-sub "rewind"))
		 (t (viper-check-sub "read"))))
	  ((looking-at "s")
	   (cond ((looking-at "se") (viper-check-sub "set"))
		 ((looking-at "sh") (viper-check-sub "shell"))
		 ((looking-at "so") (viper-check-sub "source"))
		 ((looking-at "sr") (viper-check-sub "sr"))
		 ((looking-at "st") (viper-check-sub "stop"))
		 ((looking-at "sus") (viper-check-sub "suspend"))
		 ((looking-at "subm") (viper-check-sub "submitReport"))
		 (t (viper-check-sub "substitute"))))
	  ((looking-at "t")
	   (if (looking-at "ta") (viper-check-sub "tag")
	     (viper-check-sub "transfer")))
	  ((looking-at "u")
	   (cond ((looking-at "una") (viper-check-sub "unabbreviate"))
		 ((looking-at "unm") (viper-check-sub "unmap"))
		 (t (viper-check-sub "undo"))))
	  ((looking-at "v")
	   (cond ((looking-at "ve") (viper-check-sub "version"))
		 ((looking-at "vi") (viper-check-sub "visual"))
		 (t (viper-check-sub "vglobal"))))
	  ((looking-at "w")
	   (if (looking-at "wq") (viper-check-sub "wq")
	     (viper-check-sub "write")))
	  ((looking-at "W")
	   (if (looking-at "WW") 
	       (viper-check-sub "WWrite")
	     (viper-check-sub "Write")))
	  ((looking-at "x") (viper-check-sub "xit"))
	  ((looking-at "y") (viper-check-sub "yank"))
	  ((looking-at "z") (viper-check-sub "z")))
    (exchange-point-and-mark)
    ))

;; Get an ex-token which is either an address or a command.
;; A token has a type, \(command, address, end-mark\), and a value
(defun viper-get-ex-token ()
  (save-window-excursion
    (setq viper-ex-work-buf (get-buffer-create viper-ex-work-buf-name)) 
    (set-buffer viper-ex-work-buf)
    (skip-chars-forward " \t|")
    (let ((case-fold-search t))
      (cond ((looking-at "#")
	     (setq ex-token-type 'command)
	     (setq ex-token (char-to-string (following-char)))
	     (forward-char 1))
	    ((looking-at "[a-z]") (viper-get-ex-com-subr))
	    ((looking-at "\\.")
	     (forward-char 1)
	     (setq ex-token-type 'dot))
	    ((looking-at "[0-9]")
	     (set-mark (point))
	     (re-search-forward "[0-9]*")
	     (setq ex-token-type
		   (cond ((eq ex-token-type 'plus) 'add-number)
			 ((eq ex-token-type 'minus) 'sub-number)
			 (t 'abs-number)))
	     (setq ex-token
		   (string-to-int (buffer-substring (point) (mark t)))))
	    ((looking-at "\\$")
	     (forward-char 1)
	     (setq ex-token-type 'end))
	    ((looking-at "%")
	     (forward-char 1)
	     (setq ex-token-type 'whole))
	    ((looking-at "+")
	     (cond ((or (looking-at "+[-+]") (looking-at "+[\n|]"))
		    (forward-char 1)
		    (insert "1")
		    (backward-char 1)
		  (setq ex-token-type 'plus))
		   ((looking-at "+[0-9]")
		    (forward-char 1)
		    (setq ex-token-type 'plus))
		   (t
		    (error viper-BadAddress))))
	    ((looking-at "-")
	     (cond ((or (looking-at "-[-+]") (looking-at "-[\n|]"))
		    (forward-char 1)
		    (insert "1")
		    (backward-char 1)
		    (setq ex-token-type 'minus))
		   ((looking-at "-[0-9]")
		    (forward-char 1)
		    (setq ex-token-type 'minus))
		   (t
		    (error viper-BadAddress))))
	    ((looking-at "/")
	     (forward-char 1)
	     (set-mark (point))
	     (let ((cont t))
	       (while (and (not (eolp)) cont)
		 ;;(re-search-forward "[^/]*/")
		 (re-search-forward "[^/]*\\(/\\|\n\\)")
		 (if (not (viper-looking-back "[^\\\\]\\(\\\\\\\\\\)*\\\\/"))
		     (setq cont nil))))
	     (backward-char 1)
	     (setq ex-token (buffer-substring (point) (mark t)))
	     (if (looking-at "/") (forward-char 1))
	     (setq ex-token-type 'search-forward))
	    ((looking-at "\\?")
	     (forward-char 1)
	     (set-mark (point))
	     (let ((cont t))
	       (while (and (not (eolp)) cont)
		 ;;(re-search-forward "[^\\?]*\\?")
		 (re-search-forward "[^\\?]*\\(\\?\\|\n\\)")
		 (if (not (viper-looking-back "[^\\\\]\\(\\\\\\\\\\)*\\\\\\?"))
		     (setq cont nil))
		 (backward-char 1)
		 (if (not (looking-at "\n")) (forward-char 1))))
	     (setq ex-token-type 'search-backward)
	     (setq ex-token (buffer-substring (1- (point)) (mark t))))
	    ((looking-at ",")
	     (forward-char 1)
	     (setq ex-token-type 'comma))
	    ((looking-at ";")
	     (forward-char 1)
	     (setq ex-token-type 'semi-colon))
	    ((looking-at "[!=><&~]")
	     (setq ex-token-type 'command)
	     (setq ex-token (char-to-string (following-char)))
	     (forward-char 1))
	    ((looking-at "'")
	     (setq ex-token-type 'goto-mark)
	     (forward-char 1)
	     (cond ((looking-at "'") (setq ex-token nil))
		   ((looking-at "[a-z]") (setq ex-token (following-char)))
		   (t (error "Marks are ' and a-z")))
	     (forward-char 1))
	    ((looking-at "\n")
	     (setq ex-token-type 'end-mark)
	     (setq ex-token "goto"))
	    (t
	     (error viper-BadExCommand))))))

;; Reads Ex command. Tries to determine if it has to exit because command
;; is complete or invalid. If not, keeps reading command.
(defun ex-cmd-read-exit ()
  (interactive)
  (setq viper-incomplete-ex-cmd t)
  (let ((quit-regex1 (concat
		      "\\(" "set[ \t]*"
		      "\\|" "edit[ \t]*"
		      "\\|" "[nN]ext[ \t]*"
		      "\\|" "unm[ \t]*"
		      "\\|" "^[ \t]*rep"
		      "\\)"))
	(quit-regex2 (concat
		      "[a-zA-Z][ \t]*"
		      "\\(" "!" "\\|" ">>"
		      "\\|" "\\+[0-9]+"
		      "\\)"
		      "*[ \t]*$"))
	(stay-regex (concat
		     "\\(" "^[ \t]*$"
		     "\\|" "[?/].*"
		     "\\|" "[ktgjmsz][ \t]*$"
		     "\\|" "^[ \t]*ab.*"
		     "\\|" "tr[ansfer \t]*"
		     "\\|" "sr[ \t]*"
		     "\\|" "mo.*"
		     "\\|" "^[ \t]*k?ma[^p]*"
		     "\\|" "^[ \t]*fi.*"
		     "\\|" "v?gl.*"
		     "\\|" "[vg][ \t]*$"
		     "\\|" "jo.*"
		     "\\|" "^[ \t]*ta.*"
		     "\\|" "^[ \t]*una.*"
		     "\\|" "^[ \t]*su.*"
		     "\\|['`][a-z][ \t]*"
		     "\\|" "![ \t]*[a-zA-Z].*"
		     "\\)"
		     "!*")))
	
    (save-window-excursion ;; put cursor at the end of the Ex working buffer
      (setq viper-ex-work-buf (get-buffer-create viper-ex-work-buf-name)) 
      (set-buffer viper-ex-work-buf)
      (goto-char (point-max)))
    (cond ((viper-looking-back quit-regex1) (exit-minibuffer))
	  ((viper-looking-back stay-regex)  (insert " "))
	  ((viper-looking-back quit-regex2) (exit-minibuffer))
	  (t (insert " ")))))
  
;; complete Ex command
(defun ex-cmd-complete ()
  (interactive)
  (let (save-pos dist compl-list string-to-complete completion-result)
    
    (save-excursion
      (setq dist (skip-chars-backward "[a-zA-Z!=>&~]")
	    save-pos (point)))
	
    (if (or (= dist 0)
	    (viper-looking-back "\\([ \t]*['`][ \t]*[a-z]*\\)")
	    (viper-looking-back
	     "^[ \t]*[a-zA-Z!=>&~][ \t]*[/?]*+[ \t]+[a-zA-Z!=>&~]+"))
	;; Preceding characters are not the ones allowed in an Ex command
	;; or we have typed past command name.
	;; Note: we didn't do parsing, so there may be surprises.
	(if (or (viper-looking-back "[a-zA-Z!=>&~][ \t]*[/?]*[ \t]*")
		(viper-looking-back "\\([ \t]*['`][ \t]*[a-z]*\\)")
		(looking-at "[^ \t\n\C-m]"))
	    nil
	  (with-output-to-temp-buffer "*Completions*" 
	    (display-completion-list
	     (viper-alist-to-list ex-token-alist))))
      ;; Preceding chars may be part of a command name
      (setq string-to-complete (buffer-substring save-pos (point)))
      (setq completion-result
	    (try-completion string-to-complete ex-token-alist))
      
      (cond ((eq completion-result t)  ; exact match--do nothing
	     (viper-tmp-insert-at-eob " (Sole completion)"))
	    ((eq completion-result nil)
	     (viper-tmp-insert-at-eob " (No match)"))
	    (t  ;; partial completion
	     (goto-char save-pos)
	     (delete-region (point) (point-max))
	     (insert completion-result)
	     (let (case-fold-search)
	       (setq compl-list
		     (viper-filter-alist (concat "^" completion-result)
				       ex-token-alist)))
	     (if (> (length compl-list) 1)
		 (with-output-to-temp-buffer "*Completions*" 
		   (display-completion-list
		    (viper-alist-to-list (reverse compl-list)))))))
      )))
    

;; Read Ex commands 
(defun viper-ex (&optional string)
  (interactive)
  (or string
      (setq ex-g-flag nil
	    ex-g-variant nil))
  (let* ((map (copy-keymap minibuffer-local-map))
	 (address nil)
	 (cont t)
	 (dot (point))
	 prev-token-type com-str)
	 
    (viper-add-keymap viper-ex-cmd-map map)
    
    (setq com-str (or string (viper-read-string-with-history
			      ":" 
			      nil
			      'viper-ex-history
			      (car viper-ex-history)
			      map)))
    (save-window-excursion
      ;; just a precaution
      (setq viper-ex-work-buf (get-buffer-create viper-ex-work-buf-name)) 
      (set-buffer viper-ex-work-buf)
      (delete-region (point-min) (point-max))
      (insert com-str "\n")
      (goto-char (point-min)))
    (setq ex-token-type nil
	  ex-addresses nil)
    (while cont
      (viper-get-ex-token)
      (cond ((memq ex-token-type '(command end-mark))
	     (if address (setq ex-addresses (cons address ex-addresses)))
	     (cond ((string= ex-token "global")
		    (ex-global nil)
		    (setq cont nil))
		   ((string= ex-token "vglobal")
		    (ex-global t)
		    (setq cont nil))
		   (t
		    (viper-execute-ex-command)
		    (save-window-excursion
		      (setq viper-ex-work-buf
			    (get-buffer-create viper-ex-work-buf-name))
		      (set-buffer viper-ex-work-buf)
		      (skip-chars-forward " \t")
		      (cond ((looking-at "|")
			     (forward-char 1))
			    ((looking-at "\n")
			     (setq cont nil))
			    (t (error "`%s': %s" ex-token viper-SpuriousText)))
		      ))
		   ))
	    ((eq ex-token-type 'non-command)
	     (error "`%s': %s" ex-token viper-BadExCommand))
	    ((eq ex-token-type 'whole)
	     (setq address nil)
	     (setq ex-addresses
		   (if ex-addresses
		       (cons (point-max) ex-addresses)
		     (cons (point-max) (cons (point-min) ex-addresses)))))
	    ((eq ex-token-type 'comma)
	     (if (eq prev-token-type 'whole)
		 (setq address (point-min)))
	     (setq ex-addresses
		   (cons (if (null address) (point) address) ex-addresses)))
	    ((eq ex-token-type 'semi-colon)
	     (if (eq prev-token-type 'whole)
		 (setq address (point-min)))
	     (if address (setq dot address))
	     (setq ex-addresses
		   (cons (if (null address) (point) address) ex-addresses)))
	    (t (let ((ans (viper-get-ex-address-subr address dot)))
		 (if ans (setq address ans)))))
      (setq prev-token-type ex-token-type))))
      

;; Get a regular expression and set `ex-variant', if found
(defun viper-get-ex-pat ()
  (save-window-excursion
    (setq viper-ex-work-buf (get-buffer-create viper-ex-work-buf-name))
    (set-buffer viper-ex-work-buf)
    (skip-chars-forward " \t")
    (if (looking-at "!")
	(progn
	  (setq ex-g-variant (not ex-g-variant)
		ex-g-flag (not ex-g-flag))
	  (forward-char 1)
	  (skip-chars-forward " \t")))
    (let ((c (following-char)))
      (if (string-match "[0-9A-Za-z]" (format "%c" c))
	  (error
	   "Global regexp must be inside matching non-alphanumeric chars"))
      (if (looking-at "[^\\\\\n]")
	  (progn
	    (forward-char 1)
	    (set-mark (point))
	    (let ((cont t))
	      (while (and (not (eolp)) cont)
		(if (not (re-search-forward (format "[^%c]*%c" c c) nil t))
		    (if (member ex-token '("global" "vglobal"))
			(error
			 "Missing closing delimiter for global regexp")
		      (goto-char (point-max))))
		(if (not (viper-looking-back
			  (format "[^\\\\]\\(\\\\\\\\\\)*\\\\%c" c)))
		    (setq cont nil))))
	    (setq ex-token
		  (if (= (mark t) (point)) ""
		    (buffer-substring (1- (point)) (mark t))))
	    (backward-char 1)
	    ;; if the user doesn't specify the final pattern delimiter, we're
	    ;; at newline now. In this case, insert the initial delimiter
	    ;; specified in variable c
	    (if (looking-at "\n")
		(progn
		    (insert c)
		      (backward-char 1)))
	    )
	(setq ex-token nil))
      c)))

;; get an ex command
(defun viper-get-ex-command ()
  (save-window-excursion
    (setq viper-ex-work-buf (get-buffer-create viper-ex-work-buf-name)) 
    (set-buffer viper-ex-work-buf)
    (if (looking-at "/") (forward-char 1))
    (skip-chars-forward " \t")
    (cond ((looking-at "[a-z]")
	   (viper-get-ex-com-subr)
	   (if (eq ex-token-type 'non-command)
	       (error "`%s': %s" ex-token viper-BadExCommand)))
	  ((looking-at "[!=><&~]")
	   (setq ex-token (char-to-string (following-char)))
	   (forward-char 1))
	  (t (error viper-BadExCommand)))))

;; Get an Ex option g or c
(defun viper-get-ex-opt-gc (c)
  (save-window-excursion
    (setq viper-ex-work-buf (get-buffer-create viper-ex-work-buf-name)) 
    (set-buffer viper-ex-work-buf)
    (if (looking-at (format "%c" c)) (forward-char 1))
    (skip-chars-forward " \t")
    (cond ((looking-at "g")
	   (setq ex-token "g")
	   (forward-char 1)
	   t)
	  ((looking-at "c")
	   (setq ex-token "c")
	   (forward-char 1)
	   t)
	  (t nil))))

;; Compute default addresses.  WHOLE-FLAG means use the whole buffer
(defun viper-default-ex-addresses (&optional whole-flag)
  (cond ((null ex-addresses)
	 (setq ex-addresses
	       (if whole-flag
		   (cons (point-max) (cons (point-min) nil))
		 (cons (point) (cons (point) nil)))))
	((null (cdr ex-addresses))
	 (setq ex-addresses
	       (cons (car ex-addresses) ex-addresses)))))

;; Get an ex-address as a marker and set ex-flag if a flag is found
(defun viper-get-ex-address ()
  (let ((address (point-marker))
	(cont t))
    (setq ex-token "")
    (setq ex-flag nil)
    (while cont
      (viper-get-ex-token)
      (cond ((eq ex-token-type 'command)
	     (if (member ex-token '("print" "list" "#"))
		 (progn
		   (setq ex-flag t
			 cont nil))
	       (error "Address expected in this Ex command")))
	    ((eq ex-token-type 'end-mark)
	     (setq cont nil))
	    ((eq ex-token-type 'whole)
	     (error "Trailing address expected"))
	    ((eq ex-token-type 'comma)
	     (error "`%s': %s" ex-token viper-SpuriousText))
	    (t (let ((ans (viper-get-ex-address-subr address (point-marker))))
		 (if ans (setq address ans))))))
    address))

;; Returns an address as a point
(defun viper-get-ex-address-subr (old-address dot)
  (let ((address nil))
    (if (null old-address) (setq old-address dot))
    (cond ((eq ex-token-type 'dot)
	   (setq address dot))
	  ((eq ex-token-type 'add-number)
	   (save-excursion
	     (goto-char old-address)
	     (forward-line (if (= old-address 0) (1- ex-token) ex-token))
	     (setq address (point-marker))))
	  ((eq ex-token-type 'sub-number)
	   (save-excursion
	     (goto-char old-address)
	     (forward-line (- ex-token))
	     (setq address (point-marker))))
	  ((eq ex-token-type 'abs-number)
	   (save-excursion
	     (goto-char (point-min))
	     (if (= ex-token 0) (setq address 0)
	       (forward-line (1- ex-token))
	       (setq address (point-marker)))))
	  ((eq ex-token-type 'end)
	   (setq address (point-max-marker)))
	  ((eq ex-token-type 'plus) t)  ; do nothing
	  ((eq ex-token-type 'minus) t) ; do nothing
	  ((eq ex-token-type 'search-forward)
	   (save-excursion
	     (ex-search-address t)
	     (setq address (point-marker))))
	  ((eq ex-token-type 'search-backward)
	   (save-excursion
	     (ex-search-address nil)
	     (setq address (point-marker))))
	  ((eq ex-token-type 'goto-mark)
	   (save-excursion
	     (if (null ex-token)
		 (exchange-point-and-mark)
	       (goto-char (viper-register-to-point
			   (1+ (- ex-token ?a)) 'enforce-buffer)))
	     (setq address (point-marker)))))
    address))


;; Search pattern and set address
(defun ex-search-address (forward)
  (if (string= ex-token "")
      (if (null viper-s-string)
	  (error viper-NoPrevSearch)
	(setq ex-token viper-s-string))
    (setq viper-s-string ex-token))
  (if forward
      (progn
	(forward-line 1)
	(re-search-forward ex-token))
    (forward-line -1)
    (re-search-backward ex-token)))

;; Get a buffer name and set `ex-count' and `ex-flag' if found
(defun viper-get-ex-buffer ()
  (setq ex-buffer nil)
  (setq ex-count nil)
  (setq ex-flag nil)
  (save-window-excursion
    (setq viper-ex-work-buf (get-buffer-create viper-ex-work-buf-name)) 
    (set-buffer viper-ex-work-buf)
    (skip-chars-forward " \t")
    (if (looking-at "[a-zA-Z]")
	(progn
	  (setq ex-buffer (following-char))
	  (forward-char 1)
	  (skip-chars-forward " \t")))
    (if (looking-at "[0-9]")
	(progn
	  (set-mark (point))
	  (re-search-forward "[0-9][0-9]*")
	  (setq ex-count (string-to-int (buffer-substring (point) (mark t))))
	  (skip-chars-forward " \t")))
    (if (looking-at "[pl#]")
	(progn
	  (setq ex-flag t)
	  (forward-char 1)))
    (if (not (looking-at "[\n|]"))
	(error "`%s': %s" ex-token viper-SpuriousText))))

(defun viper-get-ex-count ()
  (setq ex-variant nil
	ex-count nil
	ex-flag nil)
  (save-window-excursion
    (setq viper-ex-work-buf (get-buffer-create viper-ex-work-buf-name)) 
    (set-buffer viper-ex-work-buf)
    (skip-chars-forward " \t")
    (if (looking-at "!")
	(progn
	  (setq ex-variant t)
	  (forward-char 1)))
    (skip-chars-forward " \t")
    (if (looking-at "[0-9]")
	(progn
	  (set-mark (point))
	  (re-search-forward "[0-9][0-9]*")
	  (setq ex-count (string-to-int (buffer-substring (point) (mark t))))
	  (skip-chars-forward " \t")))
    (if (looking-at "[pl#]")
	(progn
	  (setq ex-flag t)
	  (forward-char 1)))
    (if (not (looking-at "[\n|]"))
	(error "`%s': %s"
	       (buffer-substring
		(point-min) (1- (point-max))) viper-BadExCommand))))

;; Expand \% and \# in ex command
(defun ex-expand-filsyms (cmd buf)
  (let (cf pf ret)
    (save-excursion 
      (set-buffer buf)
      (setq cf buffer-file-name)
      (setq pf (ex-next nil t))) ; this finds alternative file name
    (if (and (null cf) (string-match "[^\\]%\\|\\`%" cmd))
	(error "No current file to substitute for `%%'"))
    (if (and (null pf) (string-match "[^\\]#\\|\\`#" cmd))
	(error "No alternate file to substitute for `#'"))
    (save-excursion
      (set-buffer (get-buffer-create viper-ex-tmp-buf-name))
      (erase-buffer)
      (insert cmd)
      (goto-char (point-min))
      (while (re-search-forward "%\\|#" nil t)
	(let ((data (match-data)) 
	      (char (buffer-substring (match-beginning 0) (match-end 0))))
	  (if (viper-looking-back (concat "\\\\" char))
	      (replace-match char)
	    (store-match-data data)
	    (if (string= char "%")
		(replace-match cf)
	      (replace-match pf)))))
      (end-of-line)
      (setq ret (buffer-substring (point-min) (point)))
      (message "%s" ret))
    ret))

;; Get a file name and set ex-variant, `ex-append' and `ex-offset' if found
(defun viper-get-ex-file ()
  (let (prompt)
    (setq ex-file nil
	  ex-variant nil
	  ex-append nil
	  ex-offset nil
	  ex-cmdfile nil)
    (save-excursion
      (save-window-excursion
	(setq viper-ex-work-buf (get-buffer-create viper-ex-work-buf-name)) 
	(set-buffer viper-ex-work-buf)
	(skip-chars-forward " \t")
	(if (looking-at "!")
	    (if (and (not (viper-looking-back "[ \t]"))
		     ;; read doesn't have a corresponding :r! form, so ! is
		     ;; immediately interpreted as a shell command.
		     (not (string= ex-token "read")))
		(progn
		  (setq ex-variant t)
		  (forward-char 1)
		  (skip-chars-forward " \t"))
	      (setq ex-cmdfile t)
	      (forward-char 1)
	      (skip-chars-forward " \t")))
	(if (looking-at ">>")
	    (progn
	      (setq ex-append t
		    ex-variant t)
	      (forward-char 2)
	      (skip-chars-forward " \t")))
	(if (looking-at "+")
	    (progn
	      (forward-char 1)
	      (set-mark (point))
	      (re-search-forward "[ \t\n]")
	      (backward-char 1)
	      (setq ex-offset (buffer-substring (point) (mark t)))
	      (forward-char 1)
	      (skip-chars-forward " \t")))
	;; this takes care of :r, :w, etc., when they get file names
	;; from the history list
	(if (member ex-token '("read" "write" "edit" "visual" "next"))
	    (progn
	      (setq ex-file (buffer-substring (point)  (1- (point-max))))
	      (setq ex-file
		    ;; For :e, match multiple non-white strings separated
		    ;; by white. For others, find the first non-white string
		    (if (string-match
			 (if (string= ex-token "edit")
			     "[^ \t\n]+\\([ \t]+[^ \t\n]+\\)*"
			   "[^ \t\n]+")
			 ex-file)
			(progn
			  ;; if file name comes from history, don't leave
			  ;; minibuffer when the user types space
			  (setq viper-incomplete-ex-cmd nil)
			  ;; this must be the last clause in this progn
			  (substring ex-file (match-beginning 0) (match-end 0))
			  )
		      ""))
	      ;; this leaves only the command name in the work area
	      ;; file names are gone
	      (delete-region (point) (1- (point-max)))
	      ))
	(goto-char (point-max))
	(skip-chars-backward " \t\n")
	(setq prompt (buffer-substring (point-min) (point)))
	))
    
    (setq viper-last-ex-prompt prompt)
    
    ;; If we just finished reading command, redisplay prompt
    (if viper-incomplete-ex-cmd
	(setq ex-file (viper-ex-read-file-name (format ":%s " prompt)))
      ;; file was typed in-line
      (setq ex-file (or ex-file "")))
    ))


;; Completes file name or exits minibuffer. If Ex command accepts multiple
;; file names, arranges to re-enter the minibuffer.
(defun viper-complete-filename-or-exit ()
  (interactive)
  (setq viper-keep-reading-filename t) 
  ;; don't exit if directory---ex-commands don't 
  (cond ((ex-cmd-accepts-multiple-files-p ex-token) (exit-minibuffer))
	;; apparently the argument to an Ex command is
	;; supposed to be a shell command
	((viper-looking-back "^[ \t]*!.*")
	 (setq ex-cmdfile t)
	 (insert " "))
	(t
	 (setq ex-cmdfile nil)
	 (minibuffer-complete-word))))

(defun viper-handle-! ()
  (interactive)
  (if (and (string=
	    (buffer-string) (viper-abbreviate-file-name default-directory))
	   (member ex-token '("read" "write")))
      (erase-buffer))
  (insert "!"))

(defun ex-cmd-accepts-multiple-files-p (token)
  (member token '("edit" "next" "Next")))

;; If user doesn't enter anything, then "" is returned, i.e., the
;; prompt-directory is not returned.
(defun viper-ex-read-file-name (prompt)
  (let* ((str "")
	 (minibuffer-local-completion-map
	  (copy-keymap minibuffer-local-completion-map))
	 beg end cont val)
    
    (viper-add-keymap ex-read-filename-map
		    (if viper-emacs-p 
			minibuffer-local-completion-map
		      read-file-name-map)) 
		    
    (setq cont (setq viper-keep-reading-filename t))
    (while cont
      (setq viper-keep-reading-filename nil
	    val (read-file-name (concat prompt str) nil default-directory))
      (if (string-match " " val)
	  (setq val (concat "\\\"" val "\\\"")))
      (setq str  (concat str (if (equal val "") "" " ")
			 val (if (equal val "") "" " ")))
			 
      ;; Only edit, next, and Next commands accept multiple files.
      ;; viper-keep-reading-filename is set in the anonymous function that is
      ;; bound to " " in ex-read-filename-map.
      (setq cont (and viper-keep-reading-filename
		      (ex-cmd-accepts-multiple-files-p ex-token)))
      )
    
    (setq beg (string-match "[^ \t]" str)   ; delete leading blanks
	  end (string-match "[ \t]*$" str)) ; delete trailing blanks
    (if (member ex-token '("read" "write"))
	  (if (string-match "[\t ]*!" str)
	      ;; this is actually a shell command
	      (progn
		(setq ex-cmdfile t)
		(setq beg (1+ beg))
		(setq viper-last-ex-prompt
		      (concat viper-last-ex-prompt " !")))))
    (substring str (or beg 0) end)))

;; Execute ex command using the value of addresses
(defun viper-execute-ex-command ()
  (viper-deactivate-mark)
  (cond ((string= ex-token "args") (ex-args))
	((string= ex-token "copy") (ex-copy nil))
	((string= ex-token "cd") (ex-cd))
	((string= ex-token "chdir") (ex-cd))
	((string= ex-token "delete") (ex-delete))
	((string= ex-token "edit") (ex-edit))
	((string= ex-token "file") (viper-info-on-file))
	((string= ex-token "goto") (ex-goto))
	((string= ex-token "help") (ex-help))
	((string= ex-token "join") (ex-line "join"))
	((string= ex-token "kmark") (ex-mark))
	((string= ex-token "mark") (ex-mark))
	((string= ex-token "map") (ex-map))
	((string= ex-token "move") (ex-copy t))
	((string= ex-token "next") (ex-next ex-cycle-other-window))
	((string= ex-token "Next") (ex-next (not ex-cycle-other-window)))
	((string= ex-token "RelatedFile") (ex-next-related-buffer 1))
	((string= ex-token "put") (ex-put))
	((string= ex-token "pwd") (ex-pwd))
	((string= ex-token "preserve") (ex-preserve))
	((string= ex-token "PreviousRelatedFile") (ex-next-related-buffer -1))
	((string= ex-token "quit") (ex-quit))
	((string= ex-token "read") (ex-read))
	((string= ex-token "recover") (ex-recover))
	((string= ex-token "rewind") (ex-rewind))
	((string= ex-token "submitReport") (viper-submit-report))
	((string= ex-token "set") (ex-set))
	((string= ex-token "shell") (ex-shell))
	((string= ex-token "source") (ex-source))
	((string= ex-token "sr") (ex-substitute t t))
	((string= ex-token "substitute") (ex-substitute))
	((string= ex-token "suspend") (suspend-emacs))
	((string= ex-token "stop") (suspend-emacs))
	((string= ex-token "transfer") (ex-copy nil))
	((string= ex-token "buffer") (if ex-cycle-other-window
					 (viper-switch-to-buffer-other-window)
				       (viper-switch-to-buffer)))
	((string= ex-token "Buffer") (if ex-cycle-other-window
					 (viper-switch-to-buffer)
				       (viper-switch-to-buffer-other-window)))
	((string= ex-token "tag") (ex-tag))
	((string= ex-token "undo") (viper-undo))
	((string= ex-token "unmap") (ex-unmap))
	((string= ex-token "version") (viper-version))
	((string= ex-token "visual") (ex-edit))
	((string= ex-token "write") (ex-write nil))
	((string= ex-token "Write") (save-some-buffers))
	((string= ex-token "wq") (ex-write t))
	((string= ex-token "WWrite") (save-some-buffers t)) ; don't ask
	((string= ex-token "xit") (ex-write t))
	((string= ex-token "yank") (ex-yank))
	((string= ex-token "!") (ex-command))
	((string= ex-token "=") (ex-line-no))
	((string= ex-token ">") (ex-line "right"))
	((string= ex-token "<") (ex-line "left"))
	((string= ex-token "&") (ex-substitute t))
	((string= ex-token "~") (ex-substitute t t))
	((or (string= ex-token "append")
	     (string= ex-token "change")
	     (string= ex-token "insert")
	     (string= ex-token "open"))
	 (error "`%s': Obsolete command, not supported by Viper" ex-token))
	((or (string= ex-token "abbreviate")
	     (string= ex-token "unabbreviate"))
	 (error
	  "`%s': Vi abbrevs are obsolete. Use the more powerful Emacs abbrevs"
	  ex-token))
	((or (string= ex-token "list")
	     (string= ex-token "print")
	     (string= ex-token "z")
	     (string= ex-token "#"))
	 (error "`%s': Command not implemented in Viper" ex-token))
	(t (error "`%s': %s" ex-token viper-BadExCommand))))

(defun viper-undisplayed-files ()
  (mapcar
   (function 
    (lambda (b) 
      (if (null (get-buffer-window b))
	  (let ((f (buffer-file-name b)))
	    (if f f
	      (if ex-cycle-through-non-files 
		  (let ((s (buffer-name b)))
		    (if (string= " " (substring s 0 1))
			nil
		      s))
		nil)))
	nil)))
   (buffer-list)))


(defun ex-args ()
  (let ((l (viper-undisplayed-files))
	(args "")
	(file-count 1))
    (while (not (null l))
      (if (car l) 
	  (setq args (format "%s %d) %s\n" args file-count (car l))
		file-count (1+ file-count)))
      (setq l (cdr l)))
    (if (string= args "")
	(message "All files are already displayed")
      (save-excursion
	(save-window-excursion
	  (with-output-to-temp-buffer " *viper-info*"
	    (princ "\n\nThese files are not displayed in any window.\n")
	    (princ "\n=============\n")
	    (princ args)
	    (princ "\n=============\n")
	    (princ "\nThe numbers can be given as counts to :next. ")
	    (princ "\n\nPress any key to continue...\n\n"))
	  (viper-read-event))))))

;; Ex cd command. Default directory of this buffer changes
(defun ex-cd ()
  (viper-get-ex-file)
  (if (string= ex-file "")
      (setq ex-file "~"))
  (setq default-directory (file-name-as-directory (expand-file-name ex-file))))

;; Ex copy and move command.  DEL-FLAG means delete
(defun ex-copy (del-flag)
  (viper-default-ex-addresses)
  (let ((address (viper-get-ex-address))
	(end (car ex-addresses)) (beg (car (cdr ex-addresses))))
    (goto-char end)
    (save-excursion
      (push-mark beg t)
      (viper-enlarge-region (mark t) (point))
      (if del-flag
	  (kill-region (point) (mark t))
	(copy-region-as-kill (point) (mark t)))
      (if ex-flag
	  (progn
	    (with-output-to-temp-buffer "*copy text*"
	      (princ
	       (if (or del-flag ex-g-flag ex-g-variant)
		   (current-kill 0)
		 (buffer-substring (point) (mark t)))))
	    (condition-case nil
		(progn
		  (read-string "[Hit return to continue] ")
		  (save-excursion (kill-buffer "*copy text*")))
	      (quit (save-excursion (kill-buffer "*copy text*"))
		    (signal 'quit nil))))))
    (if (= address 0)
	(goto-char (point-min))
      (goto-char address)
      (forward-line 1))
      (insert (current-kill 0))))

;; Ex delete command
(defun ex-delete ()
  (viper-default-ex-addresses)
  (viper-get-ex-buffer)
  (let ((end (car ex-addresses)) (beg (car (cdr ex-addresses))))
    (if (> beg end) (error viper-FirstAddrExceedsSecond))
    (save-excursion
      (viper-enlarge-region beg end)
      (exchange-point-and-mark)
      (if ex-count
	  (progn
	    (set-mark (point))
	    (forward-line (1- ex-count)))
	(set-mark end))
      (viper-enlarge-region (point) (mark t))
      (if ex-flag
	  ;; show text to be deleted and ask for confirmation
	  (progn
	    (with-output-to-temp-buffer " *delete text*"
	      (princ (buffer-substring (point) (mark t))))
	    (condition-case nil
		(read-string "[Hit return to continue] ")
	      (quit
	       (save-excursion (kill-buffer " *delete text*"))
	       (error "")))
	    (save-excursion (kill-buffer " *delete text*")))
	(if ex-buffer
	    (cond ((viper-valid-register ex-buffer '(Letter))
		   (viper-append-to-register
		    (downcase ex-buffer) (point) (mark t)))
		  ((viper-valid-register ex-buffer)
		   (copy-to-register ex-buffer (point) (mark t) nil))
		  (t (error viper-InvalidRegister ex-buffer))))
	(kill-region (point) (mark t))))))



;; Ex edit command
;; In Viper, `e' and `e!' behave identically. In both cases, the user is
;; asked if current buffer should really be discarded.
;; This command can take multiple file names. It replaces the current buffer
;; with the first file in its argument list
(defun ex-edit (&optional file)
  (if (not file)
      (viper-get-ex-file))
  (cond ((and (string= ex-file "") buffer-file-name)
	 (setq ex-file  (viper-abbreviate-file-name (buffer-file-name))))
	((string= ex-file "")
	 (error viper-NoFileSpecified)))
      
  (let (msg do-edit)
    (if buffer-file-name
	(cond ((buffer-modified-p)
	       (setq msg
		     (format "Buffer %s is modified. Discard changes? "
			     (buffer-name))
		     do-edit t))
	      ((not (verify-visited-file-modtime (current-buffer)))
	       (setq msg
		     (format "File %s changed on disk.  Reread from disk? "
			     buffer-file-name)
		     do-edit t))
	      (t (setq do-edit nil))))
      
    (if do-edit
	(if (yes-or-no-p msg)
	    (progn
	      (set-buffer-modified-p nil)
	      (kill-buffer (current-buffer)))
	  (message "Buffer %s was left intact" (buffer-name))))
    ) ; let
  
  (if (null (setq file (get-file-buffer ex-file)))
      (progn 
	(ex-find-file ex-file)
	(or (eq major-mode 'dired-mode)
	    (viper-change-state-to-vi))
	(goto-char (point-min)))
    (switch-to-buffer file))
  (if ex-offset
      (progn
	(save-window-excursion
	  (setq viper-ex-work-buf (get-buffer-create viper-ex-work-buf-name)) 
	  (set-buffer viper-ex-work-buf)
	  (delete-region (point-min) (point-max))
	  (insert ex-offset "\n")
	  (goto-char (point-min)))
	(goto-char (viper-get-ex-address))
	(beginning-of-line)))
  (ex-fixup-history viper-last-ex-prompt ex-file))

;; Find-file FILESPEC if it appears to specify a single file.
;; Otherwise, assume that FILES{EC is a wildcard.
;; In this case, split it into substrings separated by newlines.
;; Each line is assumed to be a file name. find-file's each file thus obtained.
(defun ex-find-file (filespec)
  (let ((nonstandard-filename-chars "[^-a-zA-Z0-9_./,~$\\]"))
    (cond ((file-exists-p filespec) (find-file filespec))
	  ((string-match nonstandard-filename-chars  filespec)
	   (funcall ex-nontrivial-find-file-function filespec))
	  (t (find-file filespec)))
    ))


;; Ex global command
;; This is executed in response to:
;;		:global "pattern" ex-command
;;		:vglobal "pattern" ex-command
;; :global executes ex-command on all lines matching <pattern>
;; :vglobal executes ex-command on all lines that don't match <pattern>
;;
;; With VARIANT nil, this functions executes :global
;; With VARIANT t, executes :vglobal
(defun ex-global (variant)
  (let ((gcommand ex-token))
    (if (or ex-g-flag ex-g-variant)
	(error "`%s' within `global' is not allowed" gcommand)
      (if variant
	  (setq ex-g-flag nil
		ex-g-variant t)
	(setq ex-g-flag t
	      ex-g-variant nil)))
    (viper-get-ex-pat)
    (if (null ex-token)
	(error "`%s': Missing regular expression" gcommand)))
  
  (if (string= ex-token "")
      (if (null viper-s-string)
	  (error viper-NoPrevSearch)
	(setq ex-g-pat viper-s-string))
    (setq ex-g-pat ex-token
	  viper-s-string ex-token))
  (if (null ex-addresses)
      (setq ex-addresses (list (point-max) (point-min)))
    (viper-default-ex-addresses))
  (let ((marks nil)
	(mark-count 0)
	(end (car ex-addresses))
	(beg (car (cdr ex-addresses)))
	com-str)
    (if (> beg end) (error viper-FirstAddrExceedsSecond))
    (save-excursion
      (viper-enlarge-region beg end)
      (exchange-point-and-mark)
      (let ((cont t) (limit (point-marker)))
	(exchange-point-and-mark)
	;; skip the last line if empty
	(beginning-of-line)
	(if (eobp) (viper-backward-char-carefully))
	(while (and cont (not (bobp)) (>= (point) limit))
	  (beginning-of-line)
	  (set-mark (point))
	  (end-of-line)
	  (let ((found (re-search-backward ex-g-pat (mark t) t)))
	    (if (or (and ex-g-flag found)
		    (and ex-g-variant (not found)))
		(progn
		  (end-of-line)
		  (setq mark-count (1+ mark-count))
		  (setq marks (cons (point-marker) marks)))))
	  (beginning-of-line)
	  (if (bobp) (setq cont nil)
	    (forward-line -1)
	    (end-of-line)))))
    (save-window-excursion
      (setq viper-ex-work-buf (get-buffer-create viper-ex-work-buf-name)) 
      (set-buffer viper-ex-work-buf)
      (setq com-str (buffer-substring (1+ (point)) (1- (point-max)))))
    (while marks
      (goto-char (car marks))
      (viper-ex com-str)
      (setq mark-count (1- mark-count))
      (setq marks (cdr marks)))))

;; Ex goto command
(defun ex-goto ()
  (if (null ex-addresses)
      (setq ex-addresses (cons (point) nil)))
  (push-mark (point) t)
  (goto-char (car ex-addresses))
  (beginning-of-line))

;; Ex line commands.  COM is join, shift-right or shift-left
(defun ex-line (com)
  (viper-default-ex-addresses)
  (viper-get-ex-count)
  (let ((end (car ex-addresses)) (beg (car (cdr ex-addresses))) point)
    (if (> beg end) (error viper-FirstAddrExceedsSecond))
    (save-excursion
      (viper-enlarge-region beg end)
      (exchange-point-and-mark)
      (if ex-count
	  (progn
	    (set-mark (point))
	    (forward-line ex-count)))
      (if ex-flag
	  ;; show text to be joined and ask for confirmation
	  (progn
	    (with-output-to-temp-buffer " *text*"
	      (princ (buffer-substring (point) (mark t))))
	    (condition-case nil
		(progn
		  (read-string "[Hit return to continue] ")
		  (ex-line-subr com (point) (mark t)))
	      (quit (ding)))
	    (save-excursion (kill-buffer " *text*")))
	(ex-line-subr com (point) (mark t)))
      (setq point (point)))
    (goto-char (1- point))
    (beginning-of-line)))

(defun ex-line-subr (com beg end)
  (cond ((string= com "join")
	 (goto-char (min beg end))
	 (while (and (not (eobp)) (< (point) (max beg end)))
	   (end-of-line)
	   (if (and (<= (point) (max beg end)) (not (eobp)))
	       (progn
		 (forward-line 1)
		 (delete-region (point) (1- (point)))
		 (if (not ex-variant) (fixup-whitespace))))))
	((or (string= com "right") (string= com "left"))
	 (indent-rigidly
	  (min beg end) (max beg end)
	  (if (string= com "right") viper-shift-width (- viper-shift-width)))
	 (goto-char (max beg end))
	 (end-of-line)
	 (viper-forward-char-carefully))))


;; Ex mark command
(defun ex-mark ()
  (let (char)
    (if (null ex-addresses)
	(setq ex-addresses
	      (cons (point) nil)))
    (save-window-excursion
      (setq viper-ex-work-buf (get-buffer-create viper-ex-work-buf-name)) 
      (set-buffer viper-ex-work-buf)
      (skip-chars-forward " \t")
      (if (looking-at "[a-z]")
	  (progn
	    (setq char (following-char))
	    (forward-char 1)
	    (skip-chars-forward " \t")
	    (if (not (looking-at "[\n|]"))
		(error "`%s': %s" ex-token viper-SpuriousText)))
	(error "`%s' requires a following letter" ex-token)))
    (save-excursion
      (goto-char (car ex-addresses))
      (point-to-register (1+ (- char ?a))))))

    
      
;; Alternate file is the file next to the first one in the buffer ring
(defun ex-next (cycle-other-window &optional find-alt-file)
  (catch 'ex-edit
    (let (count l)
      (if (not find-alt-file) 
	  (progn
	    (viper-get-ex-file)
	    (if (or (char-or-string-p ex-offset)
		    (and (not (string= "" ex-file)) 
		         (not (string-match "^[0-9]+$" ex-file))))
		(progn
		  (ex-edit t)
		  (throw 'ex-edit nil))
	      (setq count (string-to-int ex-file))
	      (if (= count 0) (setq count 1))
	      (if (< count 0) (error "Usage: `next <count>' (count >= 0)"))))
	(setq count 1))
      (setq l (viper-undisplayed-files))
      (while (> count 0)
	(while (and (not (null l)) (null (car l)))
	  (setq l (cdr l)))
	(setq count (1- count))
	(if (> count 0)
	    (setq l (cdr l))))
      (if find-alt-file (car l)
	(progn
	  (if (and (car l) (get-file-buffer (car l)))
	      (let* ((w (if cycle-other-window
			    (get-lru-window) (selected-window)))
		     (b (window-buffer w)))
		(set-window-buffer w (get-file-buffer (car l)))
		(bury-buffer b)
		;; this puts "next <count>" in the ex-command history
		(ex-fixup-history viper-last-ex-prompt ex-file))
	    (error "Not that many undisplayed files")))))))


(defun ex-next-related-buffer (direction &optional no-recursion)
  
  (viper-ring-rotate1 viper-related-files-and-buffers-ring direction)
  
  (let ((file-or-buffer-name 
	 (viper-current-ring-item viper-related-files-and-buffers-ring))
	(old-ring viper-related-files-and-buffers-ring)
	(old-win (selected-window))
	skip-rest buf wind)
    
    (or (and (ring-p viper-related-files-and-buffers-ring)
	     (> (ring-length viper-related-files-and-buffers-ring) 0))
	(error "This buffer has no related files or buffers"))
	
    (or (stringp file-or-buffer-name)
	(error
	 "File and buffer names must be strings, %S" file-or-buffer-name))
    
    (setq buf (cond ((get-buffer file-or-buffer-name))
		    ((file-exists-p file-or-buffer-name)
		     (find-file-noselect file-or-buffer-name))
		    ))
    
    (if (not (viper-buffer-live-p buf))
	(error "Didn't find buffer %S or file %S"
	       file-or-buffer-name
	       (viper-abbreviate-file-name
		(expand-file-name file-or-buffer-name))))
	  
    (if (equal buf (current-buffer))
	(or no-recursion
	    ;; try again
	    (progn
	      (setq skip-rest t)
	      (ex-next-related-buffer direction 'norecursion))))
	
    (if skip-rest
	()
      ;; setup buffer
      (if (setq wind (viper-get-visible-buffer-window buf))
	  ()
	(setq wind (get-lru-window (if viper-xemacs-p nil 'visible)))
	(set-window-buffer wind buf))
	    
      (if (viper-window-display-p)
	  (progn
	    (raise-frame (window-frame wind))
	    (if (equal (window-frame wind) (window-frame old-win))
		(save-window-excursion (select-window wind) (sit-for 1))
	      (select-window wind)))
	(save-window-excursion (select-window wind) (sit-for 1)))
	
      (save-excursion
	(set-buffer buf)
	(setq viper-related-files-and-buffers-ring old-ring))
      
      (setq viper-local-search-start-marker (point-marker))
      )))
  
    
;; Force auto save
(defun ex-preserve ()
  (message "Autosaving all buffers that need to be saved...")
  (do-auto-save t))

;; Ex put
(defun ex-put ()
  (let ((point (if (null ex-addresses) (point) (car ex-addresses))))
    (viper-get-ex-buffer)
    (setq viper-use-register ex-buffer)
    (goto-char point)
    (if (bobp) (viper-Put-back 1) (viper-put-back 1))))

;; Ex print working directory
(defun ex-pwd ()
  (message default-directory))

;; Ex quit command
(defun ex-quit ()
  ;; skip "!", if it is q!. In Viper q!, w!, etc., behave as q, w, etc.
  (save-excursion
    (setq viper-ex-work-buf (get-buffer-create viper-ex-work-buf-name)) 
    (set-buffer viper-ex-work-buf)
    (if (looking-at "!") (forward-char 1)))
  (if (< viper-expert-level 3)
      (save-buffers-kill-emacs)
    (kill-buffer (current-buffer))))


;; Ex read command
(defun ex-read ()
  (viper-get-ex-file)
  (let ((point (if (null ex-addresses) (point) (car ex-addresses)))
	command)
    (goto-char point)
    (viper-add-newline-at-eob-if-necessary)
    (if (not (or (bobp) (eobp))) (forward-line 1))
    (if (and (not ex-variant) (string= ex-file ""))
	(progn
	  (if (null buffer-file-name)
	      (error viper-NoFileSpecified))
	  (setq ex-file buffer-file-name)))
    (if ex-cmdfile
	(progn
	  (setq command (ex-expand-filsyms ex-file (current-buffer)))
	  (shell-command command t))
      (insert-file-contents ex-file)))
  (ex-fixup-history viper-last-ex-prompt ex-file))
  
;; this function fixes ex-history for some commands like ex-read, ex-edit
(defun ex-fixup-history (&rest args)  
  (setq viper-ex-history
	(cons (mapconcat 'identity args " ") (cdr viper-ex-history))))
  

;; Ex recover from emacs \#file\#
(defun ex-recover ()
  (viper-get-ex-file)
  (if (or ex-append ex-offset)
      (error "`recover': %s" viper-SpuriousText))
  (if (string= ex-file "")
      (progn
	(if (null buffer-file-name)
	    (error "This buffer isn't visiting any file"))
	(setq ex-file buffer-file-name))
    (setq ex-file (expand-file-name ex-file)))
  (if (and (not (string= ex-file (buffer-file-name)))
	   (buffer-modified-p)
	   (not ex-variant))
      (error "No write since last change \(:rec! overrides\)"))
  (recover-file ex-file))

;; Tell that `rewind' is obsolete and to use `:next count' instead
(defun ex-rewind ()
  (message
   "Use `:n <count>' instead. Counts are obtained from the `:args' command"))


;; read variable name for ex-set
(defun ex-set-read-variable ()
  (let ((minibuffer-local-completion-map
	 (copy-keymap minibuffer-local-completion-map))
	(cursor-in-echo-area t)
	str batch)
    (define-key
      minibuffer-local-completion-map " " 'minibuffer-complete-and-exit)
    (define-key minibuffer-local-completion-map "=" 'exit-minibuffer)
    (if (viper-set-unread-command-events
	 (ex-get-inline-cmd-args "[ \t]*[a-zA-Z]*[ \t]*" nil "\C-m"))
	(progn
	  (setq batch t)
	  (viper-set-unread-command-events ?\C-m)))
    (message ":set  <Variable> [= <Value>]")
    (or batch (sit-for 2))
    
    (while (string-match "^[ \\t\\n]*$"
			 (setq str
			       (completing-read ":set " ex-variable-alist)))
      (message ":set <Variable> [= <Value>]")
      ;; if there are unread events, don't wait
      (or (viper-set-unread-command-events "") (sit-for 2))
      ) ; while
    str))


(defun ex-set ()
  (let ((var (ex-set-read-variable))
	(val 0)
	(set-cmd "setq")
	(ask-if-save t)
	(auto-cmd-label "; don't touch or else...")
	(delete-turn-on-auto-fill-pattern
	 "([ \t]*add-hook[ \t]+'viper-insert-state-hooks[ \t]+'turn-on-auto-fill.*)")
	actual-lisp-cmd lisp-cmd-del-pattern
	val2 orig-var)
    (setq orig-var var)
    (cond ((string= var "all")
	   (setq ask-if-save nil
		 set-cmd nil))
	  ((member var '("ai" "autoindent"))
	   (setq var "viper-auto-indent"
		 set-cmd "setq"
		 ask-if-save nil
		 val "t"))
	  ((member var '("ai-g" "autoindent-global"))
	   (kill-local-variable 'viper-auto-indent)
	   (setq var "viper-auto-indent"
		 set-cmd "setq-default"
		 val "t"))
	  ((member var '("noai" "noautoindent"))
	   (setq var "viper-auto-indent"
		 ask-if-save nil
		 val "nil"))
	  ((member var '("noai-g" "noautoindent-global"))
	   (kill-local-variable 'viper-auto-indent)
	   (setq var "viper-auto-indent"
		 set-cmd "setq-default"
		 val "nil"))
	  ((member var '("ic" "ignorecase"))
	   (setq var "viper-case-fold-search"
		 val "t"))
	  ((member var '("noic" "noignorecase"))
	   (setq var "viper-case-fold-search"
		 val "nil"))
	  ((member var '("ma" "magic"))
	   (setq var "viper-re-search"
		 val "t"))
  	  ((member var '("noma" "nomagic"))
	   (setq var "viper-re-search"
		 val "nil"))
	  ((member var '("ro" "readonly"))
	   (setq var "buffer-read-only"
		 val "t"))
	  ((member var '("noro" "noreadonly"))
	   (setq var "buffer-read-only"
		 val "nil"))
	  ((member var '("sm" "showmatch"))
	   (setq var "blink-matching-paren"
		 val "t"))
	  ((member var '("nosm" "noshowmatch"))
	   (setq var "blink-matching-paren"
		 val "nil"))
	  ((member var '("ws" "wrapscan"))
	   (setq var "viper-search-wrap-around-t"
		 val "t"))
	  ((member var '("nows" "nowrapscan"))
	   (setq var "viper-search-wrap-around-t"
		 val "nil")))
    (if (and set-cmd (eq val 0)) ; value must be set by the user
	(let ((cursor-in-echo-area t))
	  (message ":set %s = <Value>" var)
	  ;; if there are unread events, don't wait
	  (or (viper-set-unread-command-events "") (sit-for 2))
	  (setq val (read-string (format ":set %s = " var)))
	  (ex-fixup-history "set" orig-var val)
	  
	  ;; check numerical values
	  (if (member var
		      '("sw" "shiftwidth"
			"ts" "tabstop"
			"ts-g" "tabstop-global"
			"wm" "wrapmargin")) 
	      (condition-case nil
		  (or (numberp (setq val2 (car (read-from-string val))))
		      (error "%s: Invalid value, numberp, %S" var val))
		(error
		 (error "%s: Invalid value, numberp, %S" var val))))
		  
	  (cond
	   ((member var '("sw" "shiftwidth"))
	    (setq var "viper-shift-width"))
	   ((member var '("ts" "tabstop"))
	    ;; make it take effect in curr buff and new bufs
	    (setq var "tab-width"
		  set-cmd "setq"
		  ask-if-save nil))
	   ((member var '("ts-g" "tabstop-global"))
	    (kill-local-variable 'tab-width)
	    (setq var "tab-width"
		  set-cmd "setq-default"))
	   ((member var '("wm" "wrapmargin"))
	    ;; make it take effect in curr buff and new bufs
	    (kill-local-variable 'fill-column) 
	    (setq var "fill-column" 
		  val (format "(- (window-width) %s)" val)
		  set-cmd "setq-default"))
	   ((member var '("sh" "shell"))
	    (setq var "explicit-shell-file-name"
		  val (format "\"%s\"" val)))))
      (ex-fixup-history "set" orig-var))
    
    (if set-cmd
	(setq actual-lisp-cmd
	      (format "\n(%s %s %s) %s" set-cmd var val auto-cmd-label)
	      lisp-cmd-del-pattern
	      (format "^\n?[ \t]*([ \t]*%s[ \t]+%s[ \t].*)[ \t]*%s"
		      set-cmd var auto-cmd-label)))
    
    (if (and ask-if-save
	     (y-or-n-p (format "Do you want to save this setting in %s "
			       viper-custom-file-name)))
	(progn
	  (viper-save-string-in-file 
	   actual-lisp-cmd viper-custom-file-name
	   ;; del pattern
	   lisp-cmd-del-pattern)
	  (if (string= var "fill-column")
	      (if (> val2 0)
		  (viper-save-string-in-file
		   (concat
		    "(add-hook 'viper-insert-state-hooks 'turn-on-auto-fill) "
		    auto-cmd-label)
		   viper-custom-file-name
		   delete-turn-on-auto-fill-pattern)
		(viper-save-string-in-file
		 nil viper-custom-file-name delete-turn-on-auto-fill-pattern)
		(viper-save-string-in-file
		 nil viper-custom-file-name
		 ;; del pattern
		 lisp-cmd-del-pattern)
		))
	  ))
    
    (if set-cmd
	(message "%s %s %s"
		 set-cmd var
		 (if (string-match "^[ \t]*$" val)
		     (format "%S" val)
		   val)))
    (if actual-lisp-cmd
	(eval (car (read-from-string actual-lisp-cmd))))
    (if (string= var "fill-column")
	(if (> val2 0)
	    (auto-fill-mode 1)
	  (auto-fill-mode -1)))
    (if (string= var "all") (ex-show-vars))
    ))

;; In inline args, skip regex-forw and (optionally) chars-back.
;; Optional 3d arg is a string that should replace ' ' to prevent its
;; special meaning
(defun ex-get-inline-cmd-args (regex-forw &optional chars-back replace-str)
  (save-excursion
    (setq viper-ex-work-buf (get-buffer-create viper-ex-work-buf-name)) 
    (set-buffer viper-ex-work-buf)
    (goto-char (point-min))
    (re-search-forward regex-forw nil t)
    (let ((beg (point))
	  end)
      (goto-char (point-max))
      (if chars-back
	  (skip-chars-backward chars-back)
	(skip-chars-backward " \t\n\C-m"))
      (setq end (point))
      ;; replace SPC with `=' to suppress the special meaning SPC has
      ;; in Ex commands
      (goto-char beg)
      (if replace-str
	  (while (re-search-forward " +" nil t)
	    (replace-match replace-str nil t)
	    (viper-forward-char-carefully)))
      (goto-char end)
      (buffer-substring beg end))))


;; Ex shell command
(defun ex-shell ()
  (shell))
  
;; Viper help. Invokes Info
(defun ex-help ()
  (condition-case nil
      (progn
	(pop-to-buffer (get-buffer-create "*info*"))
	(info (if viper-xemacs-p "viper.info" "viper"))
	(message "Type `i' to search for a specific topic"))
    (error (beep 1)
	   (with-output-to-temp-buffer " *viper-info*"
	     (princ (format "
The Info file for Viper does not seem to be installed.

This file is part of the standard distribution of %sEmacs.
Please contact your system administrator. "
			    (if viper-xemacs-p "X" "")
			    ))))))

;; Ex source command. Loads the file specified as argument or `~/.viper'
(defun ex-source ()
  (viper-get-ex-file)
  (if (string= ex-file "")
      (load viper-custom-file-name)
    (load ex-file)))

;; Ex substitute command
;; If REPEAT use previous regexp which is ex-reg-exp or viper-s-string
(defun ex-substitute (&optional repeat r-flag) 
  (let ((opt-g nil)
	(opt-c nil)
	(matched-pos nil)
	(case-fold-search viper-case-fold-search)
	delim pat repl)
    (if repeat (setq ex-token nil) (setq delim (viper-get-ex-pat)))
    (if (null ex-token)
	(progn
	  (setq pat (if r-flag viper-s-string ex-reg-exp))
	  (or (stringp pat)
	      (error "No previous pattern to use in substitution"))
	  (setq repl ex-repl
		delim (string-to-char pat)))
      (setq pat (if (string= ex-token "") viper-s-string ex-token))
      (setq viper-s-string pat
	    ex-reg-exp pat)
      (setq delim (viper-get-ex-pat))
      (if (null ex-token)
	  (setq ex-token ""
		ex-repl "")
	(setq repl ex-token
	      ex-repl ex-token)))
    (while (viper-get-ex-opt-gc delim)
      (if (string= ex-token "g") (setq opt-g t) (setq opt-c t)))
    (viper-get-ex-count)
    (if ex-count
	(save-excursion
	  (if ex-addresses (goto-char (car ex-addresses)))
	  (set-mark (point))
	  (forward-line (1- ex-count))
	  (setq ex-addresses (cons (point) (cons (mark t) nil))))
      (if (null ex-addresses)
	  (setq ex-addresses (cons (point) (cons (point) nil)))
	(if (null (cdr ex-addresses))
	    (setq ex-addresses (cons (car ex-addresses) ex-addresses)))))
					;(setq G opt-g)
    (let ((beg (car ex-addresses))
	  (end (car (cdr ex-addresses)))
	  eol-mark)
      (save-excursion
	(viper-enlarge-region beg end)
	(let ((limit (save-excursion
		       (goto-char (max (point) (mark t)))
		       (point-marker))))
	  (goto-char (min (point) (mark t)))
	  (while (< (point) limit)
	    (end-of-line)
	    (setq eol-mark (point-marker))
	    (beginning-of-line)
	    (if opt-g
		(progn
		  (while (and (not (eolp))
			      (re-search-forward pat eol-mark t))
		    (if (or (not opt-c) (y-or-n-p "Replace? "))
			(progn
			  (setq matched-pos (point))
			  (if (not (stringp repl))
			      (error "Can't perform Ex substitution: No previous replacement pattern"))
			  (replace-match repl t))))
		  (end-of-line)
		  (viper-forward-char-carefully))
	      (if (null pat)
		  (error
		   "Can't repeat Ex substitution: No previous regular expression"))
	      (if (and (re-search-forward pat eol-mark t)
		       (or (not opt-c) (y-or-n-p "Replace? ")))
		  (progn
		    (setq matched-pos (point))
		    (if (not (stringp repl))
			(error "Can't perform Ex substitution: No previous replacement pattern"))
		    (replace-match repl t)))
	      (end-of-line)
	      (viper-forward-char-carefully))))))
    (if matched-pos (goto-char matched-pos))
    (beginning-of-line)
    (if opt-c (message "done"))))

;; Ex tag command
(defun ex-tag ()
  (let (tag)
    (save-window-excursion
      (setq viper-ex-work-buf (get-buffer-create viper-ex-work-buf-name)) 
      (set-buffer viper-ex-work-buf)
      (skip-chars-forward " \t")
      (set-mark (point))
      (skip-chars-forward "^ |\t\n")
      (setq tag (buffer-substring (mark t) (point))))
    (if (not (string= tag "")) (setq ex-tag tag))
    (viper-change-state-to-emacs)
    (condition-case conds
	(progn
	  (if (string= tag "")
	      (find-tag ex-tag t)
	    (find-tag-other-window ex-tag))
	  (viper-change-state-to-vi))
      (error
       (viper-change-state-to-vi)
       (viper-message-conditions conds)))))

;; Ex write command
(defun ex-write (q-flag)
  (viper-default-ex-addresses t)
  (viper-get-ex-file)
  (let ((end (car ex-addresses))
	(beg (car (cdr ex-addresses))) 
	(orig-buf (current-buffer))
	(orig-buf-file-name (buffer-file-name))
	(orig-buf-name (buffer-name))
	(buff-changed-p (buffer-modified-p))
	temp-buf writing-same-file region
	file-exists writing-whole-file)
    (if (> beg end) (error viper-FirstAddrExceedsSecond))
    (if ex-cmdfile
	(progn
	  (viper-enlarge-region beg end)
	  (shell-command-on-region (point) (mark t) ex-file))
      (if (and (string= ex-file "") (not (buffer-file-name)))
	  (setq ex-file
		(read-file-name
		 (format "Buffer %s isn't visiting any file. File to save in: "
			 (buffer-name)))))
      
      (setq writing-whole-file (and (= (point-min) beg) (= (point-max) end))
	    ex-file (if (string= ex-file "")
			(buffer-file-name)
		      (expand-file-name ex-file)))
      ;; if ex-file is a directory use the file portion of the buffer file name
      (if (and (file-directory-p ex-file)
	       buffer-file-name
	       (not (file-directory-p buffer-file-name)))
	  (setq ex-file
		(concat (file-name-as-directory ex-file)
			(file-name-nondirectory buffer-file-name))))
      
      (setq file-exists (file-exists-p ex-file)
	    writing-same-file (string= ex-file (buffer-file-name)))

      (if (and writing-whole-file writing-same-file)
	  (if (not (buffer-modified-p))
	      (message "(No changes need to be saved)")
	    (save-buffer)
	    (save-restriction
		 (widen)
		 (ex-write-info file-exists ex-file (point-min) (point-max))
		 ))
	;; writing some other file or portion of the current file
	(cond ((and file-exists
		    (not writing-same-file)
		    (not (yes-or-no-p
			  (format "File %s exists. Overwrite? " ex-file))))
	       (error "Quit"))
	      ((and writing-whole-file (not ex-append))
	       (unwind-protect
		   (progn
		     (set-visited-file-name ex-file)
		     (set-buffer-modified-p t)
		     (save-buffer))
		 ;; restore the buffer file name
		 (set-visited-file-name orig-buf-file-name)
		 (set-buffer-modified-p buff-changed-p)
		 ;; If the buffer wasn't visiting a file, restore buffer name.
		 ;; Name could've been changed by packages such as uniquify.
		 (or orig-buf-file-name
		     (progn
		       (unlock-buffer)
		       (rename-buffer orig-buf-name))))
	       (save-restriction
		 (widen)
		 (ex-write-info
		  file-exists ex-file (point-min) (point-max))))
	      (t ; writing a region
	       (unwind-protect 
		   (save-excursion
		     (viper-enlarge-region beg end)
		     (setq region (buffer-substring (point) (mark t)))
		     ;; create temp buffer for the region
		     (setq temp-buf (get-buffer-create " *ex-write*"))
		     (set-buffer temp-buf)
		     (set-visited-file-name ex-file 'noquerry)
		     (erase-buffer)
		     (if (and file-exists ex-append)
			 (insert-file-contents ex-file))
		     (goto-char (point-max))
		     (insert region)
		     (save-buffer)
		     (ex-write-info
		      file-exists ex-file (point-min) (point-max))
		     ))
	       (set-buffer temp-buf)
	       (set-buffer-modified-p nil)
	       (kill-buffer temp-buf))
	      ))
      (set-buffer orig-buf)
      ;; this prevents the loss of data if writing part of the buffer
      (if (and (buffer-file-name) writing-same-file)
	  (set-visited-file-modtime))
      (or writing-whole-file 
	  (not writing-same-file)
	  (set-buffer-modified-p t))
      (if q-flag
	  (if (< viper-expert-level 2)
	      (save-buffers-kill-emacs)
	    (kill-buffer (current-buffer))))
      )))
	  

(defun ex-write-info (exists file-name beg end)
  (message "`%s'%s %d lines, %d characters"
	   (viper-abbreviate-file-name file-name)
	   (if exists "" " [New file]")
	   (count-lines beg (min (1+ end) (point-max)))
	   (- end beg)))

;; Ex yank command
(defun ex-yank ()
  (viper-default-ex-addresses)
  (viper-get-ex-buffer)
  (let ((end (car ex-addresses)) (beg (car (cdr ex-addresses))))
    (if (> beg end) (error viper-FirstAddrExceedsSecond))
    (save-excursion
      (viper-enlarge-region beg end)
      (exchange-point-and-mark)
      (if (or ex-g-flag ex-g-variant)
	  (error "Can't execute `yank' within `global'"))
      (if ex-count
	  (progn
	    (set-mark (point))
	    (forward-line (1- ex-count)))
	(set-mark end))
      (viper-enlarge-region (point) (mark t))
      (if ex-flag (error "`yank': %s" viper-SpuriousText))
      (if ex-buffer
	  (cond ((viper-valid-register ex-buffer '(Letter))
		 (viper-append-to-register
		  (downcase ex-buffer) (point) (mark t)))
		((viper-valid-register ex-buffer)
		 (copy-to-register ex-buffer (point) (mark t) nil))
		(t (error viper-InvalidRegister ex-buffer))))
      (copy-region-as-kill (point) (mark t)))))

;; Execute shell command
(defun ex-command ()
  (let (command)
    (save-window-excursion
      (setq viper-ex-work-buf (get-buffer-create viper-ex-work-buf-name)) 
      (set-buffer viper-ex-work-buf)
      (skip-chars-forward " \t")
      (setq command (buffer-substring (point) (point-max)))
      (end-of-line))
    (setq command (ex-expand-filsyms command (current-buffer)))
    (if (and (> (length command) 0) (string= "!" (substring command 0 1)))
	(if viper-ex-last-shell-com
	    (setq command
		  (concat viper-ex-last-shell-com (substring command 1)))
	  (error "No previous shell command")))
    (setq viper-ex-last-shell-com command)
    (if (null ex-addresses)
	(shell-command command)
      (let ((end (car ex-addresses)) (beg (car (cdr ex-addresses))))
	(if (null beg) (setq beg end))
	(save-excursion
	  (goto-char beg)
	  (set-mark end)
	  (viper-enlarge-region (point) (mark t))
	  (shell-command-on-region (point) (mark t) command t))
	(goto-char beg)))))

;; Print line number
(defun ex-line-no ()
  (message "%d"
	   (1+ (count-lines
		(point-min)
		(if (null ex-addresses) (point-max) (car ex-addresses))))))

;; Give information on the file visited by the current buffer
(defun viper-info-on-file ()
  (interactive)
  (let ((pos1 (viper-line-pos 'start))
	(pos2 (viper-line-pos 'end))
	lines file info)
    (setq lines (count-lines (point-min) (viper-line-pos 'end))
	  file (if (buffer-file-name)
		   (concat (viper-abbreviate-file-name (buffer-file-name)) ":")
		 (concat (buffer-name) " [Not visiting any file]:"))
	  info (format "line=%d/%d pos=%d/%d col=%d %s"
		       (if (= pos1 pos2)
			   (1+ lines)
			 lines)
		       (count-lines (point-min) (point-max))
		       (point) (1- (point-max))
		       (1+ (current-column))
		       (if (buffer-modified-p) "[Modified]" "[Unchanged]")))
    (if (< (+ 1 (length info) (length file))
	   (window-width (minibuffer-window)))
	(message (concat file " " info))
      (save-window-excursion
	(with-output-to-temp-buffer " *viper-info*"
	  (princ (concat "\n"
			 file "\n\n\t" info
			 "\n\n\nPress any key to continue...\n\n")))
	(viper-read-event)
	(kill-buffer " *viper-info*")))
    ))

;; display all variables set through :set
(defun ex-show-vars ()
  (with-output-to-temp-buffer " *viper-info*"
    (princ (if viper-auto-indent
	       "autoindent (local)\n" "noautoindent (local)\n"))
    (princ (if (default-value 'viper-auto-indent) 
	       "autoindent (global) \n" "noautoindent (global) \n"))
    (princ (if viper-case-fold-search "ignorecase\n" "noignorecase\n"))
    (princ (if viper-re-search "magic\n" "nomagic\n"))
    (princ (if buffer-read-only "readonly\n" "noreadonly\n"))
    (princ (if blink-matching-paren "showmatch\n" "noshowmatch\n"))
    (princ (if viper-search-wrap-around-t "wrapscan\n" "nowrapscan\n"))
    (princ (format "shiftwidth \t\t= %S\n" viper-shift-width))
    (princ (format "tabstop (local) \t= %S\n" tab-width))
    (princ (format "tabstop (global) \t= %S\n" (default-value 'tab-width)))
    (princ (format "wrapmargin (local) \t= %S\n"
		   (- (window-width) fill-column)))
    (princ (format "wrapmargin (global) \t= %S\n"
		   (- (window-width) (default-value 'fill-column))))
    (princ (format "shell \t\t\t= %S\n" (if (boundp 'explicit-shell-file-name)
					    explicit-shell-file-name
					  'none)))
    ))





;;;  viper-ex.el ends here
