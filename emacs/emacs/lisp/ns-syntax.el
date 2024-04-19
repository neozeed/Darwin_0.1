;;; ns-syntax.el --- set up case-conversion and syntax tables for NeXTstep encoding

;; Copyright (C) 1988 Free Software Foundation, Inc.

;; Author: Carl Edman
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
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

;;; Commentary:

;; Written by Carl Edman.  See case-table.el for details.

;;; Code:

;(defun show-char ()
;  (interactive)
;  (prin1 (char-to-string (string-to-number (current-word)))))

(require 'case-table)

(let ((downcase (standard-case-table)))
  (set-case-syntax 128 "w" downcase)	  ; NBSP (no-break space)
  (set-case-syntax-pair 129 213 downcase) ; A with grave accent  
  (set-case-syntax-pair 130 214 downcase) ; A with acute accent
  (set-case-syntax-pair 131 215 downcase) ; A with circumflex accent
  (set-case-syntax-pair 132 216 downcase) ; A with tilde
  (set-case-syntax-pair 133 217 downcase) ; A with diaeresis or umlaut mark
  (set-case-syntax-pair 134 218 downcase) ; A with ring
  (set-case-syntax-pair 135 219 downcase) ; C with cedilla
  (set-case-syntax-pair 136 220 downcase) ; E with grave accent
  (set-case-syntax-pair 137 221 downcase) ; E with acute accent
  (set-case-syntax-pair 138 222 downcase) ; E with circumflex accent
  (set-case-syntax-pair 139 223 downcase) ; E with diaeresis or umlaut mark
  (set-case-syntax-pair 140 224 downcase) ; I with grave accent
  (set-case-syntax-pair 141 226 downcase) ; I with acute accent
  (set-case-syntax-pair 142 228 downcase) ; I with circumflex accent
  (set-case-syntax-pair 143 229 downcase) ; I with diaeresis or umlaut mark
  (set-case-syntax-pair 144 230 downcase) ; D with stroke, Icelandic eth
  (set-case-syntax-pair 145 231 downcase) ; N with tilde
  (set-case-syntax-pair 146 236 downcase) ; O with grave accent
  (set-case-syntax-pair 147 237 downcase) ; O with acute accent
  (set-case-syntax-pair 148 238 downcase) ; O with circumflex accent
  (set-case-syntax-pair 149 239 downcase) ; O with tilde
  (set-case-syntax-pair 150 240 downcase) ; O with diaeresis or umlaut mark
  (set-case-syntax-pair 151 242 downcase) ; U with grave accent
  (set-case-syntax-pair 152 243 downcase) ; U with acute accent
  (set-case-syntax-pair 153 244 downcase) ; U with circumflex accent
  (set-case-syntax-pair 154 246 downcase) ; U with diaeresis or umlaut mark
  (set-case-syntax-pair 155 247 downcase) ; Y with acute accent
  (set-case-syntax-pair 156 252 downcase) ; thorn, Icelandic
  (set-case-syntax 157 "_" downcase)      ; micro sign
  (set-case-syntax 158 "_" downcase)      ; multiplication sign
  (set-case-syntax 159 "_" downcase)      ; division sign
  (set-case-syntax 160 "_" downcase)      ; copyright sign
  (set-case-syntax 161 "." downcase)      ; inverted exclamation mark
  (set-case-syntax 162 "w" downcase)      ; cent sign
  (set-case-syntax 163 "w" downcase)      ; pound sign
  (set-case-syntax 164 "_" downcase)      ; fraction sign
  (set-case-syntax 165 "w" downcase)      ; yen sign
  (set-case-syntax 166 "w" downcase)      ; florin sign
  (set-case-syntax 167 "w" downcase)      ; section sign
  (set-case-syntax 168 "w" downcase)      ; general currency sign
  (set-case-syntax 169 "." downcase)      ; single quote
  (set-case-syntax-delims 170 186 downcase) ; double quotation marks
  (set-case-syntax-delims 171 187 downcase) ; double angle quotation marks
  (set-case-syntax-delims 172 173 downcase) ; single angle quotation marks
  (set-case-syntax 174 "_" downcase)      ; fi
  (set-case-syntax 175 "_" downcase)      ; fl
  (set-case-syntax 176 "_" downcase)      ; registered sign
  (set-case-syntax 177 "_" downcase)      ; soft hyphen
  (set-case-syntax 178 "_" downcase)      ; dagger
  (set-case-syntax 179 "_" downcase)      ; double dagger
  (set-case-syntax 180 "_" downcase)      ; middle dot
  (set-case-syntax 181 "_" downcase)      ; broken vertical line
  (set-case-syntax 182 "w" downcase)      ; paragraph
  (set-case-syntax 183 "w" downcase)      ; bullet
  (set-case-syntax 184 "." downcase)      ; base single quote
  (set-case-syntax 185 "." downcase)      ; base double quote
  (set-case-syntax 188 "_" downcase)      ; ellipsis
  (set-case-syntax 189 "_" downcase)      ; permille
  (set-case-syntax 190 "_" downcase)      ; not sign
  (set-case-syntax 191 "." downcase)      ; inverted question mark
  (set-case-syntax 192 "w" downcase)      ; superscript one
  (set-case-syntax 193 "w" downcase)      ; grave accent
  (set-case-syntax 194 "w" downcase)      ; acute accent
  (set-case-syntax 195 "w" downcase)      ; circumflex accent
  (set-case-syntax 196 "w" downcase)      ; tilde accent
  (set-case-syntax 197 "w" downcase)      ; macron
  (set-case-syntax 198 "w" downcase)      ; breve accent
  (set-case-syntax 199 "w" downcase)      ; dot accent
  (set-case-syntax 200 "w" downcase)      ; diaeresis
  (set-case-syntax 201 "w" downcase)      ; superscript two
  (set-case-syntax 202 "_" downcase)      ; degree sign
  (set-case-syntax 203 "w" downcase)      ; cedilla
  (set-case-syntax 204 "w" downcase)      ; superscript three
  (set-case-syntax 205 "w" downcase)      ; hungarumlaut
  (set-case-syntax 206 "w" downcase)      ; ogonek
  (set-case-syntax 207 "w" downcase)      ; caron
  (set-case-syntax 208 "_" downcase)      ; em dash
  (set-case-syntax 209 "_" downcase)      ; plus or minus sign
  (set-case-syntax 210 "_" downcase)      ; fraction one-quarter
  (set-case-syntax 211 "_" downcase)      ; fraction one-half
  (set-case-syntax 212 "_" downcase)      ; fraction three-quarters
  (set-case-syntax-pair 225 241 downcase) ; AE diphthong
  (set-case-syntax 227 "w" downcase)      ; ordinal indicator, feminine
  (set-case-syntax-pair 232 248 downcase) ; L with slash
  (set-case-syntax-pair 233 249 downcase) ; O with slash
  (set-case-syntax-pair 234 250 downcase) ; OE diphthong
  (set-case-syntax 235 "w" downcase)      ; ordinal indicator, masculine
  (set-case-syntax 245 "w" downcase)      ; dotless i
  (set-case-syntax 251 "w" downcase)      ; small sharp s, German
  (set-case-syntax 253 "w" downcase)      ; small y with diaeresis or umlaut mark
  (set-case-syntax 254 "_" downcase)      ; space
  (set-case-syntax 255 "_" downcase)      ; space
  )

(provide 'ns-syntax)

;;; ns-syntax.el ends here
