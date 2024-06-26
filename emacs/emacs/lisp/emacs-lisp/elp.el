;;; elp.el --- Emacs Lisp Profiler

;; Copyright (C) 1994, 1995, 1997 Free Software Foundation, Inc.

;; Author:        1994-1997 Barry A. Warsaw
;; Maintainer:    tools-help@python.org
;; Created:       26-Feb-1994
;; Version:       3.0
;; Last Modified: 1997/04/21 17:45:15
;; Keywords:      debugging lisp tools

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
;;
;; If you want to profile a bunch of functions, set elp-function-list
;; to the list of symbols, then do a M-x elp-instrument-list.  This
;; hacks those functions so that profiling information is recorded
;; whenever they are called.  To print out the current results, use
;; M-x elp-results.  If you want output to go to standard-output
;; instead of a separate buffer, setq elp-use-standard-output to
;; non-nil.  With elp-reset-after-results set to non-nil, profiling
;; information will be reset whenever the results are displayed.  You
;; can also reset all profiling info at any time with M-x
;; elp-reset-all.
;;
;; You can also instrument all functions in a package, provided that
;; the package follows the GNU coding standard of a common textural
;; prefix.  Use M-x elp-instrument-package for this.
;;
;; If you want to sort the results, set elp-sort-by-function to some
;; predicate function.  The three most obvious choices are predefined:
;; elp-sort-by-call-count, elp-sort-by-average-time, and
;; elp-sort-by-total-time.  Also, you can prune from the output, all
;; functions that have been called fewer than a given number of times
;; by setting elp-report-limit.
;;
;; Elp can instrument byte-compiled functions just as easily as
;; interpreted functions, but it cannot instrument macros.  However,
;; when you redefine a function (e.g. with eval-defun), you'll need to
;; re-instrument it with M-x elp-instrument-function.  This will also
;; reset profiling information for that function.  Elp can handle
;; interactive functions (i.e. commands), but of course any time spent
;; idling for user prompts will show up in the timing results.
;;
;; You can also designate a `master' function.  Profiling times will
;; be gathered for instrumented functions only during execution of
;; this master function.  Thus, if you have some defuns like:
;;
;;  (defun foo () (do-something-time-intensive))
;;  (defun bar () (foo))
;;  (defun baz () (bar) (foo))
;;
;; and you want to find out the amount of time spent in bar and foo,
;; but only during execution of bar, make bar the master.  The call of
;; foo from baz will not add to foo's total timing sums.  Use M-x
;; elp-set-master and M-x elp-unset-master to utilize this feature.
;; Only one master function can be set at a time.

;; You can restore any function's original function definition with
;; elp-restore-function.  The other instrument, restore, and reset
;; functions are provided for symmetry.

;; Here is a list of variable you can use to customize elp:
;;   elp-function-list
;;   elp-reset-after-results
;;   elp-sort-by-function
;;   elp-report-limit
;;
;; Here is a list of the interactive commands you can use:
;;   elp-instrument-function
;;   elp-restore-function
;;   elp-instrument-list
;;   elp-restore-list
;;   elp-instrument-package
;;   elp-restore-all
;;   elp-reset-function
;;   elp-reset-list
;;   elp-reset-all
;;   elp-set-master
;;   elp-unset-master
;;   elp-results
;;   elp-submit-bug-report

;; Note that there are plenty of factors that could make the times
;; reported unreliable, including the accuracy and granularity of your
;; system clock, and the overhead spent in lisp calculating and
;; recording the intervals.  I figure the latter is pretty constant,
;; so while the times may not be entirely accurate, I think they'll
;; give you a good feel for the relative amount of work spent in the
;; various lisp routines you are profiling.  Note further that times
;; are calculated using wall-clock time, so other system load will
;; affect accuracy too.

;;; Background:

;; This program was inspired by the only two existing Emacs Lisp
;; profilers that I'm aware of, Boaz Ben-Zvi's profile.el, and Root
;; Boy Jim's profiler.el. Both were written for Emacs 18 and both were
;; pretty good first shots at profiling, but I found that they didn't
;; provide the functionality or interface that I wanted, so I wrote
;; this.  I've tested elp in XEmacs 19 and Emacs 19.  There's no point
;; in even trying to make this work with Emacs 18.

;; Unlike previous profilers, elp uses Emacs 19's built-in function
;; current-time to return interval times.  This obviates the need for
;; both an external C program and Emacs processes to communicate with
;; such a program, and thus simplifies the package as a whole.

;; TBD:
;; Make this act like a real profiler, so that it records time spent
;; in all branches of execution.

;;; Code:


;; start of user configuration variables
;; vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

(defgroup elp nil
  "Emacs Lisp Profiler"
  :group 'lisp)

(defcustom elp-function-list nil
  "*List of functions to profile.
Used by the command `elp-instrument-list'."
  :type '(repeat function)
  :group 'elp)

(defcustom elp-reset-after-results t
  "*Non-nil means reset all profiling info after results are displayed.
Results are displayed with the `elp-results' command."
  :type 'boolean
  :group 'elp)

(defcustom elp-sort-by-function 'elp-sort-by-total-time
  "*Non-nil specifies elp results sorting function.
These functions are currently available:

  elp-sort-by-call-count   -- sort by the highest call count
  elp-sort-by-total-time   -- sort by the highest total time
  elp-sort-by-average-time -- sort by the highest average times

You can write you're own sort function. It should adhere to the
interface specified by the PRED argument for the `sort' defun.  Each
\"element of LIST\" is really a 4 element vector where element 0 is
the call count, element 1 is the total time spent in the function,
element 2 is the average time spent in the function, and element 3 is
the symbol's name string."
  :type 'function
  :group 'elp)

(defcustom elp-report-limit 1
  "*Prevents some functions from being displayed in the results buffer.
If a number, no function that has been called fewer than that number
of times will be displayed in the output buffer.  If nil, all
functions will be displayed."
  :type '(choice integer
		 (const :tag "Show All" nil))
  :group 'elp)

(defcustom elp-use-standard-output nil
  "*Non-nil says to output to `standard-output' instead of a buffer."
  :type 'boolean
  :group 'elp)

(defcustom elp-recycle-buffers-p t
  "*Nil says to not recycle the `elp-results-buffer'.
In other words, a new unique buffer is create every time you run
\\[elp-results]."
  :type 'boolean
  :group 'elp)


;; ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
;; end of user configuration variables


(defconst elp-version "3.0"
  "ELP version number.")

(defconst elp-help-address "tools-help@python.org"
  "Address accepting submissions of bug reports and questions.")

(defvar elp-results-buffer "*ELP Profiling Results*"
  "Buffer name for outputting profiling results.")

(defconst elp-timer-info-property 'elp-info
  "ELP information property name.")

(defvar elp-all-instrumented-list nil
  "List of all functions currently being instrumented.")

(defvar elp-record-p t
  "Controls whether functions should record times or not.
This variable is set by the master function.")

(defvar elp-master nil
  "Master function symbol.")


;;;###autoload
(defun elp-instrument-function (funsym)
  "Instrument FUNSYM for profiling.
FUNSYM must be a symbol of a defined function."
  (interactive "aFunction to instrument: ")
  ;; restore the function.  this is necessary to avoid infinite
  ;; recursion of already instrumented functions (i.e. elp-wrapper
  ;; calling elp-wrapper ad infinitum).  it is better to simply
  ;; restore the function than to throw an error.  this will work
  ;; properly in the face of eval-defun because if the function was
  ;; redefined, only the timer info will be nil'd out since
  ;; elp-restore-function is smart enough not to trash the new
  ;; definition.
  (elp-restore-function funsym)
  (let* ((funguts (symbol-function funsym))
	 (infovec (vector 0 0 funguts))
	 (newguts '(lambda (&rest args))))
    ;; we cannot profile macros
    (and (eq (car-safe funguts) 'macro)
	 (error "ELP cannot profile macro: %s" funsym))
    ;; TBD: at some point it might be better to load the autoloaded
    ;; function instead of throwing an error.  if we do this, then we
    ;; probably want elp-instrument-package to be updated with the
    ;; newly loaded list of functions.  i'm not sure it's smart to do
    ;; the autoload here, since that could have side effects, and
    ;; elp-instrument-function is similar (in my mind) to defun-ish
    ;; type functionality (i.e. it shouldn't execute the function).
    (and (eq (car-safe funguts) 'autoload)
	 (error "ELP cannot profile autoloaded function: %s" funsym))
    ;; put rest of newguts together
    (if (commandp funsym)
	(setq newguts (append newguts '((interactive)))))
    (setq newguts (append newguts (list
				   (list 'elp-wrapper
					 (list 'quote funsym)
					 (list 'and
					       '(interactive-p)
					       (not (not (commandp funsym))))
					 'args))))
    ;; to record profiling times, we set the symbol's function
    ;; definition so that it runs the elp-wrapper function with the
    ;; function symbol as an argument.  We place the old function
    ;; definition on the info vector.
    ;;
    ;; The info vector data structure is a 3 element vector.  The 0th
    ;; element is the call-count, i.e. the total number of times this
    ;; function has been entered.  This value is bumped up on entry to
    ;; the function so that non-local exists are still recorded. TBD:
    ;; I haven't tested non-local exits at all, so no guarantees.
    ;;
    ;; The 1st element is the total amount of time in usecs that have
    ;; been spent inside this function.  This number is added to on
    ;; function exit.
    ;;
    ;; The 2nd element is the old function definition list.  This gets
    ;; funcall'd in between start/end time retrievals. I believe that
    ;; this lets us profile even byte-compiled functions.

    ;; put the info vector on the property list
    (put funsym elp-timer-info-property infovec)

    ;; set the symbol's new profiling function definition to run
    ;; elp-wrapper
    (fset funsym newguts)

    ;; add this function to the instrumentation list
    (or (memq funsym elp-all-instrumented-list)
	(setq elp-all-instrumented-list
	      (cons funsym elp-all-instrumented-list)))
    ))

;;;###autoload
(defun elp-restore-function (funsym)
  "Restore an instrumented function to its original definition.
Argument FUNSYM is the symbol of a defined function."
  (interactive "aFunction to restore: ")
  (let ((info (get funsym elp-timer-info-property)))
    ;; delete the function from the all instrumented list
    (setq elp-all-instrumented-list
	  (delq funsym elp-all-instrumented-list))

    ;; if the function was the master, reset the master
    (if (eq funsym elp-master)
	(setq elp-master nil
	      elp-record-p t))

    ;; zap the properties
    (put funsym elp-timer-info-property nil)

    ;; restore the original function definition, but if the function
    ;; wasn't instrumented do nothing.  we do this after the above
    ;; because its possible the function got un-instrumented due to
    ;; circumstances beyond our control.  Also, check to make sure
    ;; that the current function symbol points to elp-wrapper.  If
    ;; not, then the user probably did an eval-defun, or loaded a
    ;; byte-compiled version, while the function was instrumented and
    ;; we don't want to destroy the new definition.  can it ever be
    ;; the case that a lisp function can be compiled instrumented?
    (and info
	 (functionp funsym)
	 (not (compiled-function-p (symbol-function funsym)))
	 (assq 'elp-wrapper (symbol-function funsym))
	 (fset funsym (aref info 2)))))

;;;###autoload
(defun elp-instrument-list (&optional list)
  "Instrument for profiling, all functions in `elp-function-list'.
Use optional LIST if provided instead."
  (interactive "PList of functions to instrument: ")
  (let ((list (or list elp-function-list)))
    (mapcar 'elp-instrument-function list)))

;;;###autoload
(defun elp-instrument-package (prefix)
  "Instrument for profiling, all functions which start with PREFIX.
For example, to instrument all ELP functions, do the following:

    \\[elp-instrument-package] RET elp- RET"
  (interactive "sPrefix of package to instrument: ")
  (elp-instrument-list
   (mapcar
    'intern
    (all-completions
     prefix obarray
     (function
      (lambda (sym)
	(and (fboundp sym)
	     (not (memq (car-safe (symbol-function sym)) '(autoload macro))))
	))
     ))))

(defun elp-restore-list (&optional list)
  "Restore the original definitions for all functions in `elp-function-list'.
Use optional LIST if provided instead."
  (interactive "PList of functions to restore: ")
  (let ((list (or list elp-function-list)))
    (mapcar 'elp-restore-function list)))

(defun elp-restore-all ()
  "Restores the original definitions of all functions being profiled."
  (interactive)
  (elp-restore-list elp-all-instrumented-list))


(defun elp-reset-function (funsym)
  "Reset the profiling information for FUNSYM."
  (interactive "aFunction to reset: ")
  (let ((info (get funsym elp-timer-info-property)))
    (or info
	(error "%s is not instrumented for profiling." funsym))
    (aset info 0 0)			;reset call counter
    (aset info 1 0.0)			;reset total time
    ;; don't muck with aref 2 as that is the old symbol definition
    ))

(defun elp-reset-list (&optional list)
  "Reset the profiling information for all functions in `elp-function-list'.
Use optional LIST if provided instead."
  (interactive "PList of functions to reset: ")
  (let ((list (or list elp-function-list)))
    (mapcar 'elp-reset-function list)))

(defun elp-reset-all ()
  "Reset the profiling information for all functions being profiled."
  (interactive)
  (elp-reset-list elp-all-instrumented-list))

(defun elp-set-master (funsym)
  "Set the master function for profiling."
  (interactive "aMaster function: ")
  ;; when there's a master function, recording is turned off by
  ;; default
  (setq elp-master funsym
	elp-record-p nil)
  ;; make sure master function is instrumented
  (or (memq funsym elp-all-instrumented-list)
      (elp-instrument-function funsym)))

(defun elp-unset-master ()
  "Unsets the master function."
  (interactive)
  ;; when there's no master function, recording is turned on by default.
  (setq elp-master nil
	elp-record-p t))


(defsubst elp-elapsed-time (start end)
  (+ (* (- (car end) (car start)) 65536.0)
     (- (car (cdr end)) (car (cdr start)))
     (/ (- (car (cdr (cdr end))) (car (cdr (cdr start)))) 1000000.0)))

(defun elp-wrapper (funsym interactive-p args)
  "This function has been instrumented for profiling by the ELP.
ELP is the Emacs Lisp Profiler.  To restore the function to its
original definition, use \\[elp-restore-function] or \\[elp-restore-all]."
  ;; turn on recording if this is the master function
  (if (and elp-master
	   (eq funsym elp-master))
      (setq elp-record-p t))
  ;; get info vector and original function symbol
  (let* ((info (get funsym elp-timer-info-property))
	 (func (aref info 2))
	 result)
    (or func
	(error "%s is not instrumented for profiling." funsym))
    (if (not elp-record-p)
	;; when not recording, just call the original function symbol
	;; and return the results.
	(setq result
	      (if interactive-p
		  (call-interactively func)
		(apply func args)))
      ;; we are recording times
      (let (enter-time exit-time)
	;; increment the call-counter
	(aset info 0 (1+ (aref info 0)))
	;; now call the old symbol function, checking to see if it
	;; should be called interactively.  make sure we return the
	;; correct value
	(if interactive-p
	    (setq enter-time (current-time)
		  result (call-interactively func)
		  exit-time (current-time))
	  (setq enter-time (current-time)
		result (apply func args)
		exit-time (current-time)))
	;; calculate total time in function
	(aset info 1 (+ (aref info 1) (elp-elapsed-time enter-time exit-time)))
	))
    ;; turn off recording if this is the master function
    (if (and elp-master
	     (eq funsym elp-master))
	(setq elp-record-p nil))
    result))


;; shut the byte-compiler up
(defvar elp-field-len nil)
(defvar elp-cc-len nil)
(defvar elp-at-len nil)
(defvar elp-et-len nil)

(defun elp-sort-by-call-count (vec1 vec2)
  ;; sort by highest call count.  See `sort'.
  (>= (aref vec1 0) (aref vec2 0)))

(defun elp-sort-by-total-time (vec1 vec2)
  ;; sort by highest total time spent in function. See `sort'.
  (>= (aref vec1 1) (aref vec2 1)))

(defun elp-sort-by-average-time (vec1 vec2)
  ;; sort by highest average time spent in function. See `sort'.
  (>= (aref vec1 2) (aref vec2 2)))

(defsubst elp-pack-number (number width)
  ;; pack the NUMBER string into WIDTH characters, watching out for
  ;; very small or large numbers
  (if (<= (length number) width)
      number
    ;; check for very large or small numbers
    (if (string-match "^\\(.*\\)\\(e[+-].*\\)$" number)
	(concat (substring
		 (substring number (match-beginning 1) (match-end 1))
		 0
		 (- width (match-end 2) (- (match-beginning 2)) 3))
		"..."
		(substring number (match-beginning 2) (match-end 2)))
      (concat (substring number 0 width)))))

(defun elp-output-result (resultvec)
  ;; output the RESULTVEC into the results buffer. RESULTVEC is a 4 or
  ;; more element vector where aref 0 is the call count, aref 1 is the
  ;; total time spent in the function, aref 2 is the average time
  ;; spent in the function, and aref 3 is the symbol's string
  ;; name. All other elements in the vector are ignored.
  (let* ((cc (aref resultvec 0))
	 (tt (aref resultvec 1))
	 (at (aref resultvec 2))
	 (symname (aref resultvec 3))
	 callcnt totaltime avetime)
    (setq callcnt (number-to-string cc)
	  totaltime (number-to-string tt)
	  avetime (number-to-string at))
    ;; possibly prune the results
    (if (and elp-report-limit
	     (numberp elp-report-limit)
	     (< cc elp-report-limit))
	nil
      (insert symname)
      (insert-char 32 (+ elp-field-len (- (length symname)) 2))
      ;; print stuff out, formatting it nicely
      (insert callcnt)
      (insert-char 32 (+ elp-cc-len (- (length callcnt)) 2))
      (let ((ttstr (elp-pack-number totaltime elp-et-len))
	    (atstr (elp-pack-number avetime elp-at-len)))
	(insert ttstr)
	(insert-char 32 (+ elp-et-len (- (length ttstr)) 2))
	(insert atstr))
      (insert "\n"))))

;;;###autoload
(defun elp-results ()
  "Display current profiling results.
If `elp-reset-after-results' is non-nil, then current profiling
information for all instrumented functions are reset after results are
displayed."
  (interactive)
  (let ((curbuf (current-buffer))
	(resultsbuf (if elp-recycle-buffers-p
			(get-buffer-create elp-results-buffer)
		      (generate-new-buffer elp-results-buffer))))
    (set-buffer resultsbuf)
    (erase-buffer)
    (beginning-of-buffer)
    ;; get the length of the longest function name being profiled
    (let* ((longest 0)
	   (title "Function Name")
	   (titlelen (length title))
	   (elp-field-len titlelen)
	   (cc-header "Call Count")
	   (elp-cc-len    (length cc-header))
	   (et-header "Elapsed Time")
	   (elp-et-len    (length et-header))
	   (at-header "Average Time")
	   (elp-at-len    (length at-header))
	   (resvec
	    (mapcar
	     (function
	      (lambda (funsym)
		(let* ((info (get funsym elp-timer-info-property))
		       (symname (format "%s" funsym))
		       (cc (aref info 0))
		       (tt (aref info 1)))
		  (if (not info)
		      (insert "No profiling information found for: "
			      symname)
		    (setq longest (max longest (length symname)))
		    (vector cc tt (if (zerop cc)
				      0.0 ;avoid arithmetic div-by-zero errors
				    (/ (float tt) (float cc)))
			    symname)))))
	     elp-all-instrumented-list))
	   )				; end let*
      (insert title)
      (if (> longest titlelen)
	  (progn
	    (insert-char 32 (- longest titlelen))
	    (setq elp-field-len longest)))
      (insert "  " cc-header "  " et-header "  " at-header "\n")
      (insert-char ?= elp-field-len)
      (insert "  ")
      (insert-char ?= elp-cc-len)
      (insert "  ")
      (insert-char ?= elp-et-len)
      (insert "  ")
      (insert-char ?= elp-at-len)
      (insert "\n")
      ;; if sorting is enabled, then sort the results list. in either
      ;; case, call elp-output-result to output the result in the
      ;; buffer
      (if elp-sort-by-function
	  (setq resvec (sort resvec elp-sort-by-function)))
      (mapcar 'elp-output-result resvec))
    ;; now pop up results buffer
    (set-buffer curbuf)
    (pop-to-buffer resultsbuf)
    ;; copy results to standard-output?
    (if (or elp-use-standard-output noninteractive)
	(princ (buffer-substring (point-min) (point-max))))
    ;; reset profiling info if desired
    (and elp-reset-after-results
	 (elp-reset-all))))


(eval-when-compile
 (require 'reporter))

;;;###autoload
(defun elp-submit-bug-report ()
  "Submit via mail, a bug report on elp."
  (interactive)
  (and
   (y-or-n-p "Do you want to submit a report on elp? ")
   (require 'reporter)
   (reporter-submit-bug-report
    elp-help-address (concat "elp " elp-version)
    '(elp-report-limit
      elp-reset-after-results
      elp-sort-by-function))))

(provide 'elp)

;; elp.el ends here
