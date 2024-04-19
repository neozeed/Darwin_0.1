;;; nngateway.el --- posting news via mail gateways
;; Copyright (C) 1996,97 Free Software Foundation, Inc.

;; Author: Lars Magne Ingebrigtsen <larsi@ifi.uio.no>
;; Keywords: news, mail

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

;;; Code:

(require 'nnoo)
(require 'message)

(nnoo-declare nngateway)

(defvoo nngateway-address nil
  "Address of the mail-to-news gateway.")

(defvoo nngateway-header-transformation 'nngateway-simple-header-transformation
  "Function to be called to rewrite the news headers into mail headers.
It is called narrowed to the headers to be transformed with one
parameter -- the gateway address.")

;;; Interface functions

(nnoo-define-basics nngateway)

(deffoo nngateway-open-server (server &optional defs)
  (if (nngateway-server-opened server)
      t
    (unless (assq 'nngateway-address defs)
      (setq defs (append defs (list (list 'nngateway-address server)))))
    (nnoo-change-server 'nngateway server defs)))

(deffoo nngateway-request-post (&optional server)
  (when (or (nngateway-server-opened server)
	    (nngateway-open-server server))
    ;; Rewrite the header.
    (let ((buf (current-buffer)))
      (nnheader-temp-write nil
	(insert-buffer-substring buf)
	(message-narrow-to-head)
	(funcall nngateway-header-transformation nngateway-address)
	(widen)
	(let (message-required-mail-headers)
	  (message-send-mail))))))

;;; Internal functions

(defun nngateway-simple-header-transformation (gateway)
  "Transform the headers to use GATEWAY."
  (let ((newsgroups (mail-fetch-field "newsgroups")))
    (message-remove-header "to")
    (message-remove-header "cc")
    (goto-char (point-min))
    (insert "To: " (nnheader-replace-chars-in-string newsgroups ?. ?-)
	    "@" gateway "\n")))

(nnoo-define-skeleton nngateway)

(provide 'nngateway)

;;; nngateway.el ends here
