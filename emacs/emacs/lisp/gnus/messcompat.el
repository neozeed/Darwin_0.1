;;; messcompat.el --- making message mode compatible with mail mode
;; Copyright (C) 1996,97 Free Software Foundation, Inc.

;; Author: Lars Magne Ingebrigtsen <larsi@ifi.uio.no>
;; Keywords: mail, news

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; This file tries to provide backward compatability with sendmail.el
;; for Message mode.  It should be used by simply adding
;;
;; (require 'messcompat)
;;
;; to the .emacs file.  Loading it after Message mode has been
;; loaded will have no effect.

;;; Code:

(require 'sendmail)

(defvar message-from-style mail-from-style
  "*Specifies how \"From\" headers look.

If `nil', they contain just the return address like:
	king@grassland.com
If `parens', they look like:
	king@grassland.com (Elvis Parsley)
If `angles', they look like:
	Elvis Parsley <king@grassland.com>

Otherwise, most addresses look like `angles', but they look like
`parens' if `angles' would need quoting and `parens' would not.")

(defvar message-interactive mail-interactive
  "Non-nil means when sending a message wait for and display errors.
nil means let mailer mail back a message to report errors.")

(defvar message-setup-hook mail-setup-hook
  "Normal hook, run each time a new outgoing message is initialized.
The function `message-setup' runs this hook.")

(defvar message-mode-hook mail-mode-hook
  "Hook run in message mode buffers.")

(defvar message-indentation-spaces mail-indentation-spaces
  "*Number of spaces to insert at the beginning of each cited line.
Used by `message-yank-original' via `message-yank-cite'.")

(defvar message-signature mail-signature
  "*String to be inserted at the end of the message buffer.
If t, the `message-signature-file' file will be inserted instead.
If a function, the result from the function will be used instead.
If a form, the result from the form will be used instead.")

;; Deleted the autoload cookie because this crashes in loaddefs.el.
(defvar message-signature-file mail-signature-file
  "*File containing the text inserted at end of message. buffer.")

(defvar message-default-headers mail-default-headers
  "*A string containing header lines to be inserted in outgoing messages.
It is inserted before you edit the message, so you can edit or delete
these lines.")

(defvar message-send-hook mail-send-hook
  "Hook run before sending messages.")

(provide 'messcompat)

;;; messcompat.el ends here
