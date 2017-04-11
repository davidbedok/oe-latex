;;;;;;;;;;;;<
;
; Extended spell checking support
;
; Dat: RULEZ: UTF-8, minden simán megy! (azért nem: ispell-buffer nem megy végig)
; Dat: SUXX: flyspell-mode nem pirosít ki semmit GNU Emacs 20-ban
; Dat: ispell-word doesn't work for ispell/mspell Hungarian: error "Ispell and its process have different character maps"
; Dat: if the file contains `% Local IspellDict: british' anywhere, the next
;      ispell-buffer command will use the most recent version of it.
; Dat: to spell the current buffer, run pts-shell-hu, flyspell-buffer, flyspell-mode
; Dat: run ispell-change-dictionary to change the spelling language
; Dat: automatic for .tex files: (add-hook 'tex-mode-hook (function (lambda () (setq ispell-parser 'tex))))
; Dat: `-m' is added automatically to `ispell'. Why?
; Dat: flyspell-mode doesn't call flyspell-buffer automatically
; Dat: Gépelés közben nem javít szavakat, kurzort mozgatni kell

;
; copied from new ispell.el
;
(defun pts-valid-dictionary-list ()
  "Returns a list of valid dictionaries.
The variable `ispell-library-path' defines the library location."
  (require 'ispell)
  (let ((dicts ispell-dictionary-alist)
	;; `ispell-library-path' intentionally not defined in autoload
	(path (and (boundp 'ispell-library-path) ispell-library-path))
	(dict-list (cons "default" nil))
	name load-dict)
    (while dicts
      (setq name (car (car dicts))
	    load-dict (car (cdr (member "-d" (nth 5 (car dicts)))))
	    dicts (cdr dicts))
	;; Include if the dictionary is in the library, or path not defined.
	(if (and (stringp name)
		 (or (not path)
		     ;; Debian changes: Check if one of the registered dicts
		     nil ; (member name debian-valid-dictionary-list)
		     ;; End of debian changes
		     (file-exists-p (concat path "/" name ".hash"))
		     (file-exists-p (concat path "/" name ".has"))
		     (and load-dict
			  (or (file-exists-p (concat path "/"
						     load-dict ".hash"))
			      (file-exists-p (concat path "/"
						     load-dict ".has"))))))
	    (setq dict-list (cons name dict-list))))
    dict-list))

(if (fboundp 'valid-dictionary-list) nil
  (fset 'valid-dictionary-list (symbol-function 'pts-valid-dictionary-list)) )
; Dat: also good: (fset 'valid-dictionary-list 'pts-valid-dictionary-list)

;
; Set up Hungarian Ispell dictionaries.
;
; Imp: check availability of various dictionaries
; Dat: the menu containing available languages is wrong until pts-spell-hu is called
; Dat: the user must have the modified ispell Perl script that calls ispell
(setq pts-ispell-hu-chars   "[A-Za-z\341\351\355\363\366\365\372\374\373\301\311\315\323\326\325\332\334\333]")
(setq pts-ispell-hu-nchars "[^A-Za-z\341\351\355\363\366\365\372\374\373\301\311\315\323\326\325\332\334\333]")

(setq pts-ispell-hu-order '( "magyar(hunspell)" "magyar(mspell)" "magyar(ispell)"))

;
; Append to local dictionary, so it will be merged to ispell-dictionary-alist
; when ispell.el is loaded.
;
(setq pts-ispell-hu-dictionary-alist (list
   (list "magyar(best)" pts-ispell-hu-chars pts-ispell-hu-nchars
     "" nil '("-B" "-d" "magyar-best") nil 'iso-8859-2)
   (list "magyar(ispell/magyar)" pts-ispell-hu-chars pts-ispell-hu-nchars
     "" nil '("-B" "-d" "magyar") nil 'iso-8859-2)
   (list "magyar(ispell/hungarian)" pts-ispell-hu-chars pts-ispell-hu-nchars
     "" nil '("-B" "-d" "hungarian") nil 'iso-8859-2) ; Dat: not recommended
   (list "magyar(mspell)" pts-ispell-hu-chars pts-ispell-hu-nchars
     "" nil '("-d" "mspell") nil 'iso-8859-2)
   (list "magyar(hunspell)" pts-ispell-hu-chars pts-ispell-hu-nchars
     "" nil '("-d" "hunspell") nil 'iso-8859-2)
))
;(and (not (fboundp 'pts-spell-hu)) (featurep 'ispell) ; Dat: ispell.el is loaded; Dat: (fboundp 'check-ispell-version) accidentally loads ispell.el
;  (pts-set-varzzz 'ispell-local-dictionary-alist (append ispell-local-dictionary-alist ispell-dictionary-alist)) )

;
; Add Hungarian entries to the beginning of to ispell menu
;
; Dat: idempotent, since define-key is so
(defun pts-fix-ispell-menu ()
  (condition-case nil (progn
    ; !! vvv Dat: only works in Emacs 21
    ; vvv Dat: code from ispell.el
    (let ((dicts (valid-dictionary-list)))   
      ;(setq ispell-menu-map (make-sparse-keymap "Spell"))
      (suppress-keymap ispell-menu-map) ; Imp: does it do something?
      ;; add the dictionaries to the bottom of the list. 
      (while dicts
        (if (string-equal "default" (car dicts))
            (define-key ispell-menu-map (vector 'default)
              (cons "Select Default Dict"
                    (cons "Dictionary for which Ispell was configured"
                          (list 'lambda () '(interactive)
                                (list
                                  'ispell-change-dictionary "default")))))
          (define-key ispell-menu-map (vector (intern (car dicts)))
            (cons (concat "Select " (capitalize (car dicts)) " Dict")
                  (list 'lambda () '(interactive)
                        (list 'pts-spell-change-dictionary (car dicts)))))) ; Dat: was ispell-change-dictionary
        (setq dicts (cdr dicts))))
  ))
)

(defun pts-spell-flyspell-again ()
  (if (featurep 'flyspell) (progn
    (let ((fm flyspell-mode))
      (flyspell-mode-off)
      (if fm (progn (flyspell-buffer) (flyspell-mode))
             (flyspell-mode-off))
    )
  ))
)

;
; Like flyspell-mode, but rechecks the whole buffer when set to yes.
;
(defun pts-flyspell-mode ()
  (interactive)
  "Like flyspell-mode, but rechecks the whole buffer when set to yes."
  (flyspell-mode)
  (pts-spell-flyspell-again)  
)


;
; Like ispell-change-dictionary, but does flyspell-buffer
;
(defun pts-spell-change-dictionary (dict)
  (interactive)
  "Like ispell-change-dictionary, but runs flyspell-buffer if appropriate"
  (ispell-change-dictionary dict)
  (pts-spell-flyspell-again)
)

;
; Load Ispell and set up defaults.
;
; Dat: if you put the same word twice consecutively, the 2nd is an error in Emacs
(defun pts-spell-hu ()
  "Sets up Hungarian spell-checking using Ispell and others."
  (interactive)
  ; vvv !! move down
  (require 'ispell) ; Dat: updates the menu bar if loaded for the 1st time !! reload...?
  (and (featurep 'flyspell) (fboundp 'flyspell-mode-off) (flyspell-mode-off))
  (ispell-kill-ispell t)
  (if (boundp 'ispell-library-path) t ; Dat: missing in GNU Emacs 20
   (let (u)
    (if (string-match "LIBDIR = \\\"\\([^ \t\n]*\\)\\\""
       (setq u (shell-command-to-string "ispell -vv")))
      u (error "Cannot find Ispell library path") )
    (setq ispell-library-path (substring u (match-beginning 1) (match-end 1))) ) )
  (let ((path ispell-library-path) (dicts pts-ispell-hu-order) (error-dict "??") load-dict name dict)
    (while (consp dicts)
      (setq dict (assoc (car dicts) pts-ispell-hu-dictionary-alist)
            load-dict (and dict (car (cdr (member "-d" (nth 5 dict)))))
            dicts
        (if (and dict (or (file-exists-p (concat path "/" load-dict ".hash"))
                          (file-exists-p (concat path "/" load-dict ".has"))))
          t (progn (setq error-dict load-dict) (cdr dicts)) ) ) )
    (if dicts t (error "Missing %s/%s.hash and others" path error-dict))
    ; (setcdr (assoc "magyar" ispell-dictionary-alist) (cdr dict)) ; !! do we need it?
  )
  ; ^^^ Dat: may renew ispell-dictionary-alist
  ; vvv SUXX: even this doesn't refresh the menu

  (set-variable 'ispell-local-dictionary "magyar(best)")
  (set-default  'ispell-local-dictionary "magyar(best)")
  (if (boundp    'ispell-local-dictionary-alist)
    (set-variable 'ispell-local-dictionary-alist pts-ispell-hu-dictionary-alist))
  (if (boundp    'ispell-dictionary-alist)
    (set-variable 'ispell-dictionary-alist
      (append ispell-local-dictionary-alist ; dictionary customizations
          ispell-dictionary-alist-1 ispell-dictionary-alist-2      
          ispell-dictionary-alist-3 ispell-dictionary-alist-4  
          ispell-dictionary-alist-5 ispell-dictionary-alist-6)))
  (pts-fix-ispell-menu)
  (pts-spell-change-dictionary ispell-local-dictionary) ; Dat: also prints a (message ...)
  (pts-spell-flyspell-again)
  ; ^^^ This is the most strange thing: without the line
  ;        (flyspell-mode) (flyspell-mode-off)
  ;     in Emacs 21
  ;     (and maybe Emacs 20) UTF-8 encoded files would fail to typeset with
  ;     strange Ispell misalignment errors. But not complete solution!

  ; vvv SUXX: Debian Emacs preloads (require 'ispell), too late to unload
  ; vvv SUXX: all these don't work
  ;(pts-set-var 'ispell-dictionary-alist (append ispts-ispell-hu-dictionary-alist)
  ;(unload-feature 'ispell)
  ;(custom-set-variables
  ;  '(ispell-local-dictionary-alist pts-ispell-hu-dictionary-alist))
  ;(custom-set-variables
  ;  '(ispell-dictionary-alist pts-ispell-hu-dictionary-alist))
  ;(pts-set-var 'ispell-local-dictionary-alist pts-ispell-hu-dictionary-alist) ; Imp: better append?
  ;(setq         ispell-local-dictionary-alist pts-ispell-hu-dictionary-alist) ; Imp: better append?
  ;(require 'ispell) ; Dat: regenerate the ispell menu
  ;(custom-set-variables
  ;  '(ispell-local-dictionary-alist pts-ispell-hu-dictionary-alist))
  ;(custom-set-variables
  ;  '(ispell-dictionary-alist pts-ispell-hu-dictionary-alist))
  ;; vvv !! fixes
  ;(set-variable 'ispell-local-dictionary "magyar(best)")
  ;(set-default  'ispell-local-dictionary "magyar(best)")
  ;(defvar ispell-local-pdict ispell-personal-dictionary)
  ;(make-variable-buffer-local 'ispell-local-pdict)
  ;(set-variable 'ispell-local-pdict ispell-personal-dictionary
)

(defun pts-fake-ispell-command-loop (miss guess word start end)
  ;(message "bad")
  (setq pts-ispell-bad t)
  nil
)

;
; A replacement for ispell-word that works in GNU Emacs 20 and 21. It just
; reports whether the word is correct.
;
; Dat: with our new ispell.pl, original ispell-word should also work
(defun pts-spell-word (&optional following)
  (interactive (list nil))
  (let ((word-beg-end (ispell-get-word following)) (icl (symbol-function 'ispell-command-loop)) (pts-ispell-bad nil))
    (fset 'ispell-command-loop 'pts-fake-ispell-command-loop)
    (condition-case ()
      (ispell-region (car (cdr word-beg-end)) (car (cdr (cdr word-beg-end))))
      (error (setq pts-ispell-bad 1)) )
    ; ^^^ Dat: SUXX: emits `Spell-checking done'
    (fset 'ispell-command-loop icl)
    ; Dat: if `Local IspellDict:' is invalid, an `Error' happens below
    (message "%s: %s"
      (if pts-ispell-bad (if (numberp pts-ispell-bad) "Error, can't check" "Incorrect") "Spelling OK")
      (buffer-substring-no-properties (car (cdr word-beg-end)) (car (cdr (cdr word-beg-end)))) ) ; Dat: (car word-beg-end)
  )
)

;;;;;;;;;;;;>
