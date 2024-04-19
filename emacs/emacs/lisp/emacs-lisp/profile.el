;;; profile.el --- generate run time measurements of Emacs Lisp functions

;; Copyright (C) 1992, 1994 Free Software Foundation, Inc.

;; Author: Boaz Ben-Zvi <boaz@lcs.mit.edu>
;; Created: 07 Feb 1992
;; Version: 1.0
;; Adapted-By: ESR
;; Keywords: lisp, tools

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

;; DESCRIPTION:
;; ------------
;;   This program can be used to monitor running time performance of Emacs Lisp
;; functions. It takes a list of functions and report the real time spent 
;; inside these functions. It runs a process with a separate timer program.
;;   Caveat: the C code in ../lib-src/profile.c requires BSD-compatible
;; time-of-day functions.  If you're running an AT&T version prior to SVr4,
;; you may have difficulty getting it to work.  Your X library may supply
;; the required routines if the standard C library does not.

;; HOW TO USE:
;; -----------
;;   Set the variable  profile-functions-list  to the list of functions
;; (as symbols) You want to profile. Call  M-x  profile-functions to set 
;; this list on and start using your program.  Note that profile-functions 
;; MUST be called AFTER all the functions in profile-functions-list have 
;; been loaded !!   (This call modifies the code of the profiled functions.
;; Hence if you reload these functions, you need to call  profile-functions  
;; again! ).
;;   To display the results do  M-x  profile-results .  For example:
;;-------------------------------------------------------------------
;;  (setq profile-functions-list '(sokoban-set-mode-line sokoban-load-game 
;;	                          sokoban-move-vertical sokoban-move))
;;  (load "sokoban")
;;  M-x profile-functions
;;     ...  I play the sokoban game ..........
;;  M-x profile-results
;;
;;      Function                     Time (Seconds.Useconds)
;;      ========                     =======================
;;      sokoban-move                     0.539088
;;      sokoban-move-vertical            0.410130
;;      sokoban-load-game                0.453235
;;      sokoban-set-mode-line            1.949203
;;-----------------------------------------------------
;; To clear all the settings to profile use profile-finish. 
;; To set one function at a time (instead of or in addition to setting the 
;; above list and  M-x profile-functions) use M-x profile-a-function.

;;; Code:

;;;
;;;  User modifiable VARIABLES
;;;

(defvar profile-functions-list nil "*List of functions to profile.")
(defvar profile-timer-program
  (concat exec-directory "profile")
  "*Name of the profile timer program.")

;;;
;;; V A R I A B L E S
;;;

(defvar profile-timer-process nil "Process running the timer.")
(defvar profile-time-list nil 
    "List of cumulative calls and time for each profiled function.")
(defvar profile-init-list nil
    "List of entry time for each function. 
Both how many times invoked and real time of start.")
(defvar profile-max-fun-name 0 "Max length of name of any function profiled.")
(defvar profile-temp-result- nil "Should NOT be used anywhere else.")
(defvar profile-time (cons 0 0) "Used to return result from a filter.")
(defvar profile-buffer "*profile*" "Name of profile buffer.")

(defconst profile-million 1000000)

;;;
;;; F U N C T I O N S
;;;

(defun profile-functions (&optional flist)
  "Profile all the functions listed in `profile-functions-list'.
With argument FLIST, use the list FLIST instead."
  (interactive "P")
  (if (null flist) (setq flist profile-functions-list))
  (mapcar 'profile-a-function flist))

(defun profile-filter (process input)
  "Filter for the timer process.  Sets `profile-time' to the returned time."
  (if (zerop (string-match "\\." input)) 
      (error "Bad output from %s" profile-timer-program)
    (setcar profile-time 
	    (string-to-int (substring input 0 (match-beginning 0))))
    (setcdr profile-time 
	    (string-to-int (substring input (match-end 0))))))


(defun profile-print (entry)
  "Print one ENTRY (from `profile-time-list')."
  (let* ((calls (car (cdr entry)))
	 (timec (cdr (cdr entry)))
	 (time (+ (car timec) (/ (cdr timec) (float profile-million))))
	 (avgtime 0.0))
    (insert (format (concat "%-"
			    (int-to-string profile-max-fun-name)
			    "s%8d%11d.%06d")
		    (car entry) calls (car timec) (cdr timec))
	    (if (zerop calls)
		"\n"
	      (format "%12d.%06d\n"
		      (truncate (setq avgtime (/ time calls)))
		      (truncate (* (- avgtime (ftruncate avgtime))
				   profile-million))))
	    )))

(defun profile-results ()
  "Display profiling results in the buffer `*profile*'.
\(The buffer name comes from `profile-buffer'.)"
  (interactive)
  (switch-to-buffer profile-buffer)
  (erase-buffer)
  (insert "Function" (make-string (- profile-max-fun-name 6) ? ))
  (insert " Calls  Total time (sec)  Avg time per call\n")
  (insert (make-string profile-max-fun-name ?=) "  ")
  (insert "======  ================  =================\n")
  (mapcar 'profile-print profile-time-list))
    
(defun profile-reset-timer ()
  (process-send-string profile-timer-process "z\n"))

(defun profile-check-zero-init-times (entry)
  "If ENTRY has non zero time, give an error."
  (let ((time (cdr (cdr entry))))
    (if (and (zerop (car time)) (zerop (cdr time))) nil ; OK
      (error "Process timer died while making performance profile."))))

(defun profile-get-time ()
  "Get time from timer process into `profile-time'."
  ;; first time or if process dies
  (if (and (processp profile-timer-process)
	   (eq 'run (process-status profile-timer-process))) nil
    (setq profile-timer-process;; [re]start the timer process
	  (start-process "timer" 
			 (get-buffer-create profile-buffer) 
			 profile-timer-program))
    (set-process-filter profile-timer-process 'profile-filter)
    (process-kill-without-query profile-timer-process)
    (profile-reset-timer)
    ;; check if timer died during time measurement
    (mapcar 'profile-check-zero-init-times profile-init-list)) 
  ;; make timer process return current time
  (process-send-string profile-timer-process "p\n")
  (accept-process-output))

(defun profile-find-function (fun flist)
  "Linear search for FUN in FLIST."
  (if (null flist) nil
    (if (eq fun (car (car flist))) (cdr (car flist))
      (profile-find-function fun (cdr flist)))))

(defun profile-start-function (fun)
  "On entry, keep current time for function FUN."
  ;; assumes that profile-time contains the current time
  (let ((init-time (profile-find-function fun profile-init-list)))
    (if (null init-time) (error "Function %s missing from list" fun))
    (if (not (zerop (car init-time)));; is it a recursive call ?
	(setcar init-time (1+ (car init-time)))
      (setcar init-time 1)		; mark first entry
      (setq init-time (cdr init-time))
      (setcar init-time (car profile-time))
      (setcdr init-time (cdr profile-time)))
    ))

(defun profile-update-function (fun)
  "When the call to the function FUN is finished, add its run time."
  ;; assumes that profile-time contains the current time
  (let ((init-time (profile-find-function fun profile-init-list))
	(accum (profile-find-function fun profile-time-list))
	calls time sec usec)
    (if (or (null init-time)
	    (null accum)) (error "Function %s missing from list" fun))
    (setq calls (car accum))
    (setq time (cdr accum))
    (setcar init-time (1- (car init-time))) ; pop one level in recursion
    (if (not (zerop (car init-time))) 
	nil				; in some recursion level,
					; do not update cumulated time
      (setcar accum (1+ calls))
      (setq init-time (cdr init-time))
      (setq sec (- (car profile-time) (car init-time))
	    usec (- (cdr profile-time) (cdr init-time)))
      (setcar init-time 0)		;  reset time to check for error
      (setcdr init-time 0)		;  in case timer process dies
      (if (>= usec 0) nil
	(setq usec (+ usec profile-million))
	(setq sec (1- sec)))
      (setcar time (+ sec (car time)))
      (setcdr time (+ usec (cdr time)))
      (if (< (cdr time) profile-million) nil
	(setcar time (1+ (car time)))
	(setcdr time (- (cdr time) profile-million)))
      )))

(defun profile-convert-byte-code (function)
  (let ((defn (symbol-function function)))
    (if (byte-code-function-p defn)
	;; It is a compiled code object.
	(let* ((contents (append defn nil))
	       (body
		(list (list 'byte-code (nth 1 contents)
			    (nth 2 contents) (nth 3 contents)))))
	  (if (nthcdr 5 contents)
	      (setq body (cons (list 'interactive (nth 5 contents)) body)))
	  (if (nth 4 contents)
	      ;; Use `documentation' here, to get the actual string,
	      ;; in case the compiled function has a reference
	      ;; to the .elc file.
	      (setq body (cons (documentation function) body)))
	  (fset function (cons 'lambda (cons (car contents) body)))))))

(defun profile-a-function (fun)
  "Profile the function FUN."
  (interactive "aFunction to profile: ")
  (profile-convert-byte-code fun)
  (let ((def (symbol-function fun)) (funlen (length (symbol-name fun))))
    (if (eq (car def) 'lambda) nil
      (error "To profile: %s must be a user-defined function" fun))
    (setq profile-time-list		; add a new entry
	  (cons (cons fun (cons 0 (cons 0 0))) profile-time-list))
    (setq profile-init-list		; add a new entry
	  (cons (cons fun (cons 0 (cons 0 0))) profile-init-list))
    (if (< profile-max-fun-name funlen) (setq profile-max-fun-name funlen))
    (fset fun (profile-fix-fun fun def))))

(defun profile-fix-fun (fun def)
  "Take function FUN and return it fixed for profiling.
DEF is (symbol-function FUN)."
  (let (prefix first second third (count 2) inter suffix)
    (if (< (length def) 3)
	nil		; nothing to see
      (setq first (car def) second (car (cdr def))
	    third (car (nthcdr 2 def)))
      (setq prefix (list first second))
      ;; Skip the doc string, if there is a string
      ;; which serves only as a doc string,
      ;; and put it in PREFIX.
      (if (or (not (stringp third)) (not (nthcdr 3 def)))
	  ;; Either no doc string, or it is also the function value.
	  (setq inter third) 
	;; Skip the doc string,
	(setq count 3
	      prefix (nconc prefix (list third))
	      inter (car (nthcdr 3 def))))
      ;; Check for an interactive spec.
      ;; If found, put it inu  PREFIX and skip it.
      (if (not (and (listp inter) 
		    (eq (car inter) 'interactive)))
	  nil
	(setq prefix (nconc prefix (list inter)))
	(setq count (1+ count)))	; skip this sexp for suffix
      ;; Set SUFFIX to the function body forms.
      (setq suffix (nthcdr count def))
      (if (equal (car suffix) '(profile-get-time))
	  nil
	;; Prepare new function definition.
	(nconc prefix
	       (list '(profile-get-time)) ; read time
	       (list (list 'profile-start-function 
			   (list 'quote fun)))
	       (list (list 'setq 'profile-temp-result- 
			   (nconc (list 'progn) suffix)))
	       (list '(profile-get-time)) ; read time
	       (list (list 'profile-update-function 
			   (list 'quote fun)))
	       (list 'profile-temp-result-)
	       )))))

(defun profile-restore-fun (fun)
  "Restore profiled function FUN to its original state."
  (let ((def (symbol-function (car fun))) body index)
    ;; move index beyond header
    (setq index (cdr def))
    (if (stringp (car (cdr index))) (setq index (cdr index)))
    (if (and (listp (car (cdr index)))
	     (eq (car (car (cdr index))) 'interactive))
	(setq index (cdr index)))
    (setq body (car (nthcdr 3 index)))
    (if (and (listp body)		; the right element ?
	     (eq (car (cdr body)) 'profile-temp-result-))
	(setcdr index (cdr (car (cdr (cdr body))))))))

(defun profile-finish ()
  "Stop profiling functions.  Clear all the settings."
  (interactive)
  (mapcar 'profile-restore-fun profile-time-list)
  (setq profile-max-fun-name 0)
  (setq profile-time-list nil)
  (setq profile-init-list nil))

(defun profile-quit ()
  "Kill the timer process."
  (interactive)
  (process-send-string profile-timer-process "q\n"))

(provide 'profile)

;;; profile.el ends here
