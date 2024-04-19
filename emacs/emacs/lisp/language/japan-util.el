;;; japan-util.el ---  utilities for Japanese

;; Copyright (C) 1995 Electrotechnical Laboratory, JAPAN.
;; Licensed to the Free Software Foundation.

;; Keywords: mule, multilingual, Japanese

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

;;; Code:

;;;###autoload
(defun setup-japanese-environment ()
  "Setup multilingual environment (MULE) for Japanese."
  (interactive)
  (setup-english-environment)

  (setq coding-category-iso-8-2 'japanese-iso-8bit)
  (setq coding-category-iso-8-else 'japanese-iso-8bit)

  (set-coding-priority
   '(coding-category-iso-7
     coding-category-iso-8-2
     coding-category-sjis
     coding-category-iso-8-1
     coding-category-iso-7-else
     coding-category-iso-8-else
     coding-category-emacs-mule))

  (set-default-coding-systems
   (if (eq system-type 'ms-dos)
       'japanese-shift-jis
     'iso-2022-jp))

  (setq default-input-method "japanese"))

(defconst japanese-kana-table
  '((?$B$"(B ?$B%"(B ?(I1(B) (?$B$$(B ?$B%$(B ?(I2(B) (?$B$&(B ?$B%&(B ?(I3(B) (?$B$((B ?$B%((B ?(I4(B) (?$B$*(B ?$B%*(B ?(I5(B)
    (?$B$+(B ?$B%+(B ?(I6(B) (?$B$-(B ?$B%-(B ?(I7(B) (?$B$/(B ?$B%/(B ?(I8(B) (?$B$1(B ?$B%1(B ?(I9(B) (?$B$3(B ?$B%3(B ?(I:(B)
    (?$B$5(B ?$B%5(B ?(I;(B) (?$B$7(B ?$B%7(B ?(I<(B) (?$B$9(B ?$B%9(B ?(I=(B) (?$B$;(B ?$B%;(B ?(I>(B) (?$B$=(B ?$B%=(B ?(I?(B)
    (?$B$?(B ?$B%?(B ?(I@(B) (?$B$A(B ?$B%A(B ?(IA(B) (?$B$D(B ?$B%D(B ?(IB(B) (?$B$F(B ?$B%F(B ?(IC(B) (?$B$H(B ?$B%H(B ?(ID(B)
    (?$B$J(B ?$B%J(B ?(IE(B) (?$B$K(B ?$B%K(B ?(IF(B) (?$B$L(B ?$B%L(B ?(IG(B) (?$B$M(B ?$B%M(B ?(IH(B) (?$B$N(B ?$B%N(B ?(II(B)
    (?$B$O(B ?$B%O(B ?(IJ(B) (?$B$R(B ?$B%R(B ?(IK(B) (?$B$U(B ?$B%U(B ?(IL(B) (?$B$X(B ?$B%X(B ?(IM(B) (?$B$[(B ?$B%[(B ?(IN(B)
    (?$B$^(B ?$B%^(B ?(IO(B) (?$B$_(B ?$B%_(B ?(IP(B) (?$B$`(B ?$B%`(B ?(IQ(B) (?$B$a(B ?$B%a(B ?(IR(B) (?$B$b(B ?$B%b(B ?(IS(B)
    (?$B$d(B ?$B%d(B ?(IT(B) (?$B$f(B ?$B%f(B ?(IU(B) (?$B$h(B ?$B%h(B ?(IV(B)
    (?$B$i(B ?$B%i(B ?(IW(B) (?$B$j(B ?$B%j(B ?(IX(B) (?$B$k(B ?$B%k(B ?(IY(B) (?$B$l(B ?$B%l(B ?(IZ(B) (?$B$m(B ?$B%m(B ?(I[(B)
    (?$B$o(B ?$B%o(B ?(I\(B) (?$B$p(B ?$B%p(B nil) (?$B$q(B ?$B%q(B nil) (?$B$r(B ?$B%r(B ?(I&(B)
    (?$B$s(B ?$B%s(B ?(I](B)
    (?$B$,(B ?$B%,(B "(I6^(B") (?$B$.(B ?$B%.(B "(I7^(B") (?$B$0(B ?$B%0(B "(I8^(B") (?$B$2(B ?$B%2(B "(I9^(B") (?$B$4(B ?$B%4(B "(I:^(B")
    (?$B$6(B ?$B%6(B "(I;^(B") (?$B$8(B ?$B%8(B "(I<^(B") (?$B$:(B ?$B%:(B "(I=^(B") (?$B$<(B ?$B%<(B "(I>^(B") (?$B$>(B ?$B%>(B "(I?^(B")
    (?$B$@(B ?$B%@(B "(I@^(B") (?$B$B(B ?$B%B(B "(IA^(B") (?$B$E(B ?$B%E(B "(IB^(B") (?$B$G(B ?$B%G(B "(IC^(B") (?$B$I(B ?$B%I(B "(ID^(B")
    (?$B$P(B ?$B%P(B "(IJ^(B") (?$B$S(B ?$B%S(B "(IK^(B") (?$B$V(B ?$B%V(B "(IL^(B") (?$B$Y(B ?$B%Y(B "(IM^(B") (?$B$\(B ?$B%\(B "(IN^(B")
    (?$B$Q(B ?$B%Q(B "(IJ_(B") (?$B$T(B ?$B%T(B "(IK_(B") (?$B$W(B ?$B%W(B "(IL_(B") (?$B$Z(B ?$B%Z(B "(IM_(B") (?$B$](B ?$B%](B "(IN_(B")
    (?$B$!(B ?$B%!(B ?(I'(B) (?$B$#(B ?$B%#(B ?(I((B) (?$B$%(B ?$B%%(B ?(I)(B) (?$B$'(B ?$B%'(B ?(I*(B) (?$B$)(B ?$B%)(B ?(I+(B)
    (?$B$C(B ?$B%C(B ?(I/(B)
    (?$B$c(B ?$B%c(B ?(I,(B) (?$B$e(B ?$B%e(B ?(I-(B) (?$B$g(B ?$B%g(B ?(I.(B)
    (?$B$n(B ?$B%n(B nil)
    (nil ?$B%t(B "(I3^(B") (nil ?$B%u(B nil) (nil ?$B%v(B nil))
  "Japanese JISX0208 Kana character table.
Each element is of the form (HIRAGANA KATAKANA HANKAKU-KATAKANA), where
HIRAGANA and KATAKANA belong to `japanese-jisx0208',
HANKAKU-KATAKANA belongs to `japanese-jisx0201-kana'.")

;; Put properties 'katakana, 'hiragana, and 'jix0201 to each Japanese
;; kana characters for conversion among them.
(let ((l japanese-kana-table)
      slot hiragana katakana jisx0201)
  (while l
    (setq slot (car l)
	  hiragana (car slot) katakana (nth 1 slot) jisx0201 (nth 2 slot)
	  l (cdr l))
    (if hiragana
	(progn
	  (put-char-code-property hiragana 'katakana katakana)
	  (put-char-code-property katakana 'hiragana hiragana)
	  (if jisx0201
	      (progn
		(put-char-code-property hiragana 'jisx0201 jisx0201)
		(if (integerp jisx0201)
		    (put-char-code-property jisx0201 'hiragana hiragana))))))
    (if jisx0201
	(progn
	  (put-char-code-property katakana 'jisx0201 jisx0201)
	  (if (integerp jisx0201)
	      (put-char-code-property jisx0201 'katakana katakana))))))

(defconst japanese-symbol-table
  '((?\$B!!(B ?\ ) (?$B!"(B ?, ?(I$(B) (?$B!#(B ?. ?(I!(B) (?$B!$(B ?, ?(I$(B) (?$B!%(B ?. ?(I!(B) (?$B!&(B nil ?(I%(B)
    (?$B!'(B ?:) (?$B!((B ?\;) (?$B!)(B ??) (?$B!*(B ?!) (?$B!+(B nil ?(I^(B) (?$B!,(B nil ?(I_(B)
    (?$B!-(B ?') (?$B!.(B ?`) (?$B!0(B ?^) (?$B!2(B ?_) (?$B!<(B ?-) (?$B!=(B ?-) (?$B!>(B ?-)
    (?$B!?(B ?/) (?$B!@(B ?\\) (?$B!A(B ?~)  (?$B!C(B ?|) (?$B!F(B ?`) (?$B!G(B ?') (?$B!H(B ?\") (?$B!I(B ?\")
    (?\$B!J(B ?\() (?\$B!K(B ?\)) (?\$B!N(B ?[) (?\$B!O(B ?]) (?\$B!P(B ?{) (?\$B!Q(B ?})
    (?$B!R(B ?<) (?$B!S(B ?>) (?$B!\(B ?+) (?$B!](B ?-) (?$B!a(B ?=) (?$B!c(B ?<) (?$B!d(B ?>)
    (?$B!l(B ?') (?$B!m(B ?\") (?$B!o(B ?\\) (?$B!p(B ?$) (?$B!s(B ?%) (?$B!t(B ?#) (?$B!u(B ?&) (?$B!v(B ?*)
    (?$B!w(B ?@))
  "Japanese JISX0208 symbol character table.
  Each element is of the form (SYMBOL ASCII HANKAKU), where SYMBOL
belongs to `japanese-jisx0208', ASCII belongs to `ascii', and HANKAKU
belongs to `japanese-jisx0201-kana'.")

;; Put properties 'jisx0208, 'jisx0201, and 'ascii to each Japanese
;; symbol and ASCII characters for conversion among them.
(let ((l japanese-symbol-table)
      slot jisx0208 ascii jisx0201)
  (while l
    (setq slot (car l)
	  jisx0208 (car slot) ascii (nth 1 slot) jisx0201 (nth 2 slot)
	  l (cdr l))
    (if ascii
	(progn
	  (put-char-code-property jisx0208 'ascii ascii)
	  (put-char-code-property ascii 'jisx0208 jisx0208)))
    (if jisx0201
	(progn
	  (put-char-code-property jisx0208 'jisx0201 jisx0201)
	  (put-char-code-property jisx0201 'jisx0208 jisx0208)))))

(defconst japanese-alpha-numeric-table
  '((?$B#0(B . ?0) (?$B#1(B . ?1) (?$B#2(B . ?2) (?$B#3(B . ?3) (?$B#4(B . ?4)
    (?$B#5(B . ?5) (?$B#6(B . ?6) (?$B#7(B . ?7) (?$B#8(B . ?8) (?$B#9(B . ?9)
    (?$B#A(B . ?A) (?$B#B(B . ?B) (?$B#C(B . ?C) (?$B#D(B . ?D) (?$B#E(B . ?E) 
    (?$B#F(B . ?F) (?$B#G(B . ?G) (?$B#H(B . ?H) (?$B#I(B . ?I) (?$B#J(B . ?J)
    (?$B#K(B . ?K) (?$B#L(B . ?L) (?$B#M(B . ?M) (?$B#N(B . ?N) (?$B#O(B . ?O)
    (?$B#P(B . ?P) (?$B#Q(B . ?Q) (?$B#R(B . ?R) (?$B#S(B . ?S) (?$B#T(B . ?T)
    (?$B#U(B . ?U) (?$B#V(B . ?V) (?$B#W(B . ?W) (?$B#X(B . ?X) (?$B#Y(B . ?Y) (?$B#Z(B . ?Z)
    (?$B#a(B . ?a) (?$B#b(B . ?b) (?$B#c(B . ?c) (?$B#d(B . ?d) (?$B#e(B . ?e)
    (?$B#f(B . ?f) (?$B#g(B . ?g) (?$B#h(B . ?h) (?$B#i(B . ?i) (?$B#j(B . ?j)
    (?$B#k(B . ?k) (?$B#l(B . ?l) (?$B#m(B . ?m) (?$B#n(B . ?n) (?$B#o(B . ?o)
    (?$B#p(B . ?p) (?$B#q(B . ?q) (?$B#r(B . ?r) (?$B#s(B . ?s) (?$B#t(B . ?t)
    (?$B#u(B . ?u) (?$B#v(B . ?v) (?$B#w(B . ?w) (?$B#x(B . ?x) (?$B#y(B . ?y) (?$B#z(B . ?z))
  "Japanese JISX0208 alpha numeric character table.
Each element is of the form (ALPHA-NUMERIC ASCII), where ALPHA-NUMERIC
belongs to `japanese-jisx0208', ASCII belongs to `ascii'.")

;; Put properties 'jisx0208 and 'ascii to each Japanese alpha numeric
;; and ASCII characters for conversion between them.
(let ((l japanese-alpha-numeric-table)
      slot jisx0208 ascii)
  (while l
    (setq slot (car l)
	  jisx0208 (car slot) ascii (cdr slot)
	  l (cdr l))
    (put-char-code-property jisx0208 'ascii ascii)
    (put-char-code-property ascii 'jisx0208 jisx0208)))

;; Convert string STR by FUNC and return a resulting string.
(defun japanese-string-conversion (str func &rest args)
  (let ((buf (get-buffer-create " *Japanese work*")))
    (save-excursion
      (set-buffer buf)
      (erase-buffer)
      (insert str)
      (apply func 1 (point) args)
      (buffer-string))))

;;;###autoload
(defun japanese-katakana (obj &optional hankaku)
  "Convert argument to Katakana and return that.
The argument may be a character or string.  The result has the same type.
The argument object is not altered--the value is a copy.
Optional argument HANKAKU t means to convert to `hankaku' Katakana
 \(`japanese-jisx0201-kana'), in which case return value
 may be a string even if OBJ is a character if two Katakanas are
 necessary to represent OBJ."
  (if (stringp obj)
      (japanese-string-conversion obj 'japanese-katakana-region hankaku)
    (or (get-char-code-property obj (if hankaku 'jisx0201 'katakana))
	obj)))

;;;###autoload
(defun japanese-hiragana (obj)
  "Convert argument to Hiragana and return that.
The argument may be a character or string.  The result has the same type.
The argument object is not altered--the value is a copy."
  (if (stringp obj)
      (japanese-string-conversion obj 'japanese-hiragana-region)
    (or (get-char-code-property obj 'hiragana)
	obj)))

;;;###autoload
(defun japanese-hankaku (obj &optional ascii-only)
  "Convert argument to `hankaku' and return that.
The argument may be a character or string.  The result has the same type.
The argument object is not altered--the value is a copy.
Optional argument ASCII-ONLY non-nil means to return only ASCII character."
  (if (stringp obj)
      (japanese-string-conversion obj 'japanese-hankaku-region ascii-only)
    (or (get-char-code-property obj 'ascii)
	(and (not ascii-only)
	     (get-char-code-property obj 'jisx0201))
	obj)))

;;;###autoload
(defun japanese-zenkaku (obj)
  "Convert argument to `zenkaku' and return that.
The argument may be a character or string.  The result has the same type.
The argument object is not altered--the value is a copy."
  (if (stringp obj)
      (japanese-string-conversion obj 'japanese-zenkaku-region)
    (or (get-char-code-property obj 'jisx0208)
	obj)))

;;;###autoload
(defun japanese-katakana-region (from to &optional hankaku)
  "Convert Japanese `hiragana' chars in the region to `katakana' chars.
Optional argument HANKAKU t means to convert to `hankaku katakana' character
of which charset is `japanese-jisx0201-kana'."
  (interactive "r\nP")
  (save-restriction
    (narrow-to-region from to)
    (goto-char (point-min))
    (while (re-search-forward "\\cH\\|\\cK" nil t)
      (let* ((hira (preceding-char))
	     (kata (japanese-katakana hira hankaku)))
	(if kata
	    (progn
	      (delete-region (match-beginning 0) (match-end 0))
	      (insert kata)))))))

;;;###autoload
(defun japanese-hiragana-region (from to)
  "Convert Japanese `katakana' chars in the region to `hiragana'  chars."
  (interactive "r")
  (save-restriction
    (narrow-to-region from to)
    (goto-char (point-min))
    (while (re-search-forward "\\cK\\|\\ck" nil t)
      (let* ((kata (preceding-char))
	     (hira (japanese-hiragana kata)))
	(if hira
	    (progn
	      (delete-region (match-beginning 0) (match-end 0))
	      (insert hira)))))))

;;;###autoload
(defun japanese-hankaku-region (from to &optional ascii-only)
  "Convert Japanese `zenkaku' chars in the region to `hankaku' chars.
`Zenkaku' chars belong to `japanese-jisx0208'
`Hankaku' chars belong to `ascii' or `japanese-jisx0201-kana'.
Optional argument ASCII-ONLY non-nil means to convert only to ASCII char."
  (interactive "r\nP")
  (save-restriction
    (narrow-to-region from to)
    (goto-char (point-min))
    (while (re-search-forward "\\cj" nil t)
      (let* ((zenkaku (preceding-char))
	     (hankaku (japanese-hankaku zenkaku ascii-only)))
	(if hankaku
	    (progn
	      (delete-region (match-beginning 0) (match-end 0))
	      (insert hankaku)))))))

;;;###autoload
(defun japanese-zenkaku-region (from to)
  "Convert hankaku' chars in the region to Japanese `zenkaku' chars.
`Zenkaku' chars belong to `japanese-jisx0208'
`Hankaku' chars belong to `ascii' or `japanese-jisx0201-kana'."
  (interactive "r")
  (save-restriction
    (narrow-to-region from to)
    (goto-char (point-min))
    (while (re-search-forward "\\ca\\|\\ck" nil t)
      (let* ((hankaku (preceding-char))
	     (zenkaku (japanese-zenkaku hankaku)))
	(if zenkaku
	    (progn
	      (delete-region (match-beginning 0) (match-end 0))
	      (insert zenkaku)))))))

;;;###autoload
(defun read-hiragana-string (prompt &optional initial-input)
  "Read a Hiragana string from the minibuffer, prompting with string PROMPT.
If non-nil, second arg INITIAL-INPUT is a string to insert before reading."
  (read-multilingual-string prompt initial-input "japanese-hiragana"))

;;
(provide 'japan-util)

;;; japan-util.el ends here
