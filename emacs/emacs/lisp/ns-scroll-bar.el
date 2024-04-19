;;; ns-scroll-bar.el --- NS scroll bar support.

;;; Copyright (C) 1993 Free Software Foundation, Inc.

;; Maintainer: FSF
;; Keywords: hardware

;;; This file is part of GNU Emacs.

;;; GNU Emacs is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 2, or (at your option)
;;; any later version.

;;; GNU Emacs is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.

;;; You should have received a copy of the GNU General Public License
;;; along with GNU Emacs; see the file COPYING.  If not, write to
;;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

;;; Code:

;;; Commentary:

;; NS bindings of mouse clicks on the scroll bar.
;;; Code:

(require 'mouse)


;;;; Utilities.

(defun scroll-bar-scale (num-denom whole)
  "Given a pair (NUM . DENOM) and WHOLE, return (/ (* NUM WHOLE) DENOM).
This is handy for scaling a position on a scroll bar into real units,
like buffer positions.  If SCROLL-BAR-POS is the (PORTION . WHOLE) pair
from a scroll bar event, then (scroll-bar-scale SCROLL-BAR-POS
\(buffer-size)) is the position in the current buffer corresponding to
that scroll bar position."
  ;; We multiply before we divide to maintain precision.
  ;; We use floating point because the product of a large buffer size
  ;; with a large scroll bar portion can easily overflow a lisp int.
  (truncate (/ (* (float (car num-denom)) whole) (cdr num-denom))))


;;;; Helpful functions for enabling and disabling scroll bars.

(defun scroll-bar-mode (flag)
  "Toggle display of vertical scroll bars on each frame.
This command applies to all frames that exist and frames to be
created in the future.
With a numeric argument, if the argument is negative,
turn off scroll bars; otherwise, turn on scroll bars."
  (interactive "P")
  (if flag (setq flag (prefix-numeric-value flag)))

  ;; Obtain the current setting by looking at default-frame-alist.
  (let ((scroll-bar-mode
	 (let ((assq (assq 'vertical-scroll-bars default-frame-alist)))
	   (if assq (cdr assq) t))))

    ;; Tweedle it according to the argument.
    (setq scroll-bar-mode (if (null flag) (not scroll-bar-mode)
			    (or (not (numberp flag)) (>= flag 0))))

    ;; Apply it to default-frame-alist.
    (mapcar
     (function
      (lambda (param-name)
	(let ((parameter (assq param-name default-frame-alist)))
	  (if (consp parameter)
	      (setcdr parameter scroll-bar-mode)
	    (setq default-frame-alist
		  (cons (cons param-name scroll-bar-mode)
			default-frame-alist))))))
     '(vertical-scroll-bars horizontal-scroll-bars))

    ;; Apply it to existing frames.
    (let ((frames (frame-list)))
      (while frames
	(modify-frame-parameters
	 (car frames)
	 (list (cons 'vertical-scroll-bars scroll-bar-mode)
	       (cons 'horizontal-scroll-bars scroll-bar-mode)))
	(setq frames (cdr frames))))))

;;;; Buffer navigation using the scroll bar.

(defun ns-scroll-bar-move (event)
  "Scroll the frame according to a NS scroller event."
  (interactive "e")
  (let* ((pos (event-end event))
         (window (nth 0 pos))
         (scale (nth 2 pos))
         (old-window (selected-window)))
;    (prin1 (cons window (nth 2 pos)))
    (select-window window)
    (set-buffer (window-buffer window))
    (cond
     ((eq (car scale) (cdr scale))
      (goto-char (point-max))
      (beginning-of-line)
      (recenter -1))
     ((= (car scale) 0)
      (goto-char (point-min))
      (beginning-of-line)
      (recenter 0))
     (t
      (goto-char (+ (point-min) 1
                    (scroll-bar-scale scale (- (point-max) (point-min)))))
      (beginning-of-line)
      (recenter 0)))
    (select-window old-window)))


;;;; Bindings.

(global-set-key [vertical-scroll-bar] 'ns-scroll-bar-move)

(provide 'ns-scroll-bar)

;;; ns-scroll-bar.el ends here
