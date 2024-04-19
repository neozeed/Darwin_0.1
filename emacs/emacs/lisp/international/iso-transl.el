;;; iso-transl.el --- keyboard input definitions for ISO 8859/1.

;; Copyright (C) 1987, 1993, 1994, 1995 Free Software Foundation, Inc.

;; Author: Howard Gayle
;; Maintainer: FSF
;; Keywords: i18n

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

;; Loading this package defines three ways of entering the non-ASCII
;; printable characters with codes above 127: the prefix C-x 8, or the
;; Alt key, or a dead accent key.  For example, you can enter uppercase
;; A-umlaut as `C-x 8 " A' or `Alt-" A' (if you have an Alt key) or
;; `umlaut A' (if you have an umlaut/diaeresis key).

;;; Code:

(defvar iso-transl-dead-key-alist
  '((?\' . mute-acute)
    (?\` . mute-grave)
    (?\" . mute-diaeresis)
    (?^ . mute-asciicircum)
    (?\~ . mute-asciitilde)
    (?\' . dead-acute)
    (?\` . dead-grave)
    (?\" . dead-diaeresis)
    (?^ . dead-asciicircum)
    (?\~ . dead-asciitilde)
    (?^ . dead-circum)
    (?^ . dead-circumflex)
    (?\~ . dead-tilde)
    ;; Someone reports that these keys don't work if shifted.
    ;; This might fix it--no word yet.
    (?\' . S-dead-acute)
    (?\` . S-dead-grave)
    (?\" . S-dead-diaeresis)
    (?^ . S-dead-asciicircum)
    (?\~ . S-dead-asciitilde)
    (?^ . S-dead-circum)
    (?^ . S-dead-circumflex)
    (?\~ . S-dead-tilde))
  "Mapping of ASCII characters to their corresponding dead-key symbols.")

;; The two-character mnemonics are intended to be available in all languages.
;; The ones beginning with `*' have one-character synonyms, but a
;; language-specific table might override the short form for its own use.
(defvar iso-transl-char-map
  '(("* "   . [160])(" "   . [160])
    ("*!"   . [161])("!"   . [161])
    ("\"\"" . [168])
    ("\"A"  . [196])
    ("\"E"  . [203])
    ("\"I"  . [207])
    ("\"O"  . [214])
    ("\"U"  . [220])
    ("\"a"  . [228])
    ("\"e"  . [235])
    ("\"i"  . [239])
    ("\"o"  . [246])
    ("\"s"  . [223])
    ("\"u"  . [252])
    ("\"y"  . [255])
    ("''"   . [180])
    ("'A"   . [193])
    ("'E"   . [201])
    ("'I"   . [205])
    ("'O"   . [211])
    ("'U"   . [218])
    ("'Y"   . [221])
    ("'a"   . [225])
    ("'e"   . [233])
    ("'i"   . [237])
    ("'o"   . [243])
    ("'u"   . [250])
    ("'y"   . [253])
    ("*$"   . [164])("$"   . [164])
    ("*+"   . [177])("+"   . [177])
    (",,"   . [184])
    (",C"   . [199])
    (",c"   . [231])
    ("*-"   . [173])("-"   . [173])
    ("*."   . [183])("."   . [183])
    ("//"   . [247])
    ("/A"   . [197])
    ("/E"   . [198])
    ("/O"   . [216])
    ("/a"   . [229])
    ("/e"   . [230])
    ("/o"   . [248])
    ("1/2"  . [189])
    ("1/4"  . [188])
    ("3/4"  . [190])
    ("*<"   . [171])("<"   . [171])
    ("*="   . [175])("="   . [175])
    ("*>"   . [187])(">"   . [187])
    ("*?"   . [191])("?"   . [191])
    ("*C"   . [169])("C"   . [169])
    ("*L"   . [163])("L"   . [163])
    ("*P"   . [182])("P"   . [182])
    ("*R"   . [174])("R"   . [174])
    ("*S"   . [167])("S"   . [167])
    ("*Y"   . [165])("Y"   . [165])
    ("^1"   . [185])
    ("^2"   . [178])
    ("^3"   . [179])
    ("^A"   . [194])
    ("^E"   . [202])
    ("^I"   . [206])
    ("^O"   . [212])
    ("^U"   . [219])
    ("^a"   . [226])
    ("^e"   . [234])
    ("^i"   . [238])
    ("^o"   . [244])
    ("^u"   . [251])
    ("_a"   . [170])
    ("_o"   . [186])
    ("`A"   . [192])
    ("`E"   . [200])
    ("`I"   . [204])
    ("`O"   . [210])
    ("`U"   . [217])
    ("`a"   . [224])
    ("`e"   . [232])
    ("`i"   . [236])
    ("`o"   . [242])
    ("`u"   . [249])
    ("*c"   . [162])("c"   . [162])
    ("*o"   . [176])("o"   . [176])
    ("*u"   . [181])("u"   . [181])
    ("*m"   . [181])("m"   . [181])
    ("*x"   . [215])("x"   . [215])
    ("*|"   . [166])("|"   . [166])
    ("~A"   . [195])
    ("~D"   . [208])
    ("~N"   . [209])
    ("~O"   . [213])
    ("~T"   . [222])
    ("~a"   . [227])
    ("~d"   . [240])
    ("~n"   . [241])
    ("~o"   . [245])
    ("~t"   . [254])
    ("~~"   . [172])
    ("' "   . "'")
    ("` "   . "`")
    ("\" "  . "\"")
    ("^ "   . "^")
    ("~ "   . "~"))
  "Alist of character translations for entering ISO characters.
Each element has the form (STRING . VECTOR).
The sequence STRING of ASCII chars translates into the
sequence VECTOR.  (VECTOR is normally one character long.)")

;; Language-specific translation lists.
(defvar iso-transl-language-alist
  '(("Esperanto"
     ("C"  . [198])
     ("G"  . [216])
     ("H"  . [166])
     ("J"  . [172])
     ("S"  . [222])
     ("U"  . [221])
     ("c"  . [230])
     ("g"  . [248])
     ("h"  . [182])
     ("j"  . [188])
     ("s"  . [254])
     ("u"  . [253]))
    ("French"
     ("C"  . [199])
     ("c"  . [231]))
    ("German"
     ("A"  . [196])
     ("O"  . [214]) 
     ("U"  . [220])
     ("a"  . [228])
     ("o"  . [246])
     ("s"  . [223])
     ("u"  . [252]))
    ("Portuguese"
     ("C"  . [199])
     ("c"  . [231]))
    ("Spanish"
     ("!"  . [161])
     ("?"  . [191])
     ("N"  . [241])
     ("n"  . [209]))))

(defvar iso-transl-ctl-x-8-map nil
  "Keymap for C-x 8 prefix.")
(or iso-transl-ctl-x-8-map
    (setq iso-transl-ctl-x-8-map (make-sparse-keymap)))
(or key-translation-map
    (setq key-translation-map (make-sparse-keymap)))
(define-key key-translation-map "\C-x8" iso-transl-ctl-x-8-map)

;; For each entry in the alist, we'll make up to three ways to generate
;; the character in question: the prefix `C-x 8'; the ALT modifier on
;; the first key of the sequence; and (if applicable) replacing the first
;; key of the sequence with the corresponding dead key.  For example, a
;; character associated with the string "~n" can be input with `C-x 8 ~ n'
;; or `Alt-~ n' or `mute-asciitilde n'.
(defun iso-transl-define-keys (alist)
  (while alist
    (let ((translated-vec
	   (if enable-multibyte-characters
	       (vector (+ (aref (cdr (car alist)) 0)
			  nonascii-insert-offset))
	     (cdr (car alist)))))
      (define-key iso-transl-ctl-x-8-map (car (car alist)) translated-vec)
      (let ((inchar (aref (car (car alist)) 0))
	    (vec (vconcat (car (car alist))))
	    (tail iso-transl-dead-key-alist))
	(aset vec 0 (logior (aref vec 0) ?\A-\^@))
	(define-key key-translation-map vec translated-vec)
	(define-key isearch-mode-map (vector (aref vec 0)) nil)
	(while tail
	  (if (eq (car (car tail)) inchar)
	      (let ((deadvec (copy-sequence vec))
		    (deadkey (cdr (car tail))))
		(aset deadvec 0 deadkey)
		(define-key isearch-mode-map (vector deadkey) nil)
		(define-key key-translation-map deadvec translated-vec)))
	  (setq tail (cdr tail)))))
    (setq alist (cdr alist))))

(defun iso-transl-set-language (lang)
  (interactive (list (let ((completion-ignore-case t))
		       (completing-read "Set which language? "
					iso-transl-language-alist nil t))))
  (iso-transl-define-keys (cdr (assoc lang iso-transl-language-alist))))


;; The standard mapping comes automatically.  You can partially overlay it
;; with a language-specific mapping by using `M-x iso-transl-set-language'.
(iso-transl-define-keys iso-transl-char-map)

(define-key isearch-mode-map "\C-x" nil)
(define-key isearch-mode-map [?\C-x t] 'isearch-other-control-char)
(define-key isearch-mode-map "\C-x8" nil)


(provide 'iso-transl)

;;; iso-transl.el ends here
