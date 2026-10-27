(require 'cl-lib)

(setq package-enable-at-startup nil)
(setq package-check-signature nil)
(setq package-gnupghome-dir nil)

(let* ((archive-url (or (getenv "REQPACK_MELPA_ARCHIVE_URL") "https://melpa.org/packages/"))
       (package-user-dir (or (getenv "REQPACK_MELPA_PACKAGE_USER_DIR") package-user-dir))
       (xdg-cache-home (or (getenv "REQPACK_MELPA_XDG_CACHE_HOME") (getenv "XDG_CACHE_HOME") temporary-file-directory))
       (xdg-config-home (or (getenv "REQPACK_MELPA_XDG_CONFIG_HOME") (getenv "XDG_CONFIG_HOME") temporary-file-directory))
       (tmpdir (or (getenv "REQPACK_MELPA_TMPDIR") (getenv "TMPDIR") temporary-file-directory))
       (action (or (getenv "REQPACK_MELPA_ACTION") "list"))
       (names-raw (or (getenv "REQPACK_MELPA_NAMES") ""))
       (prompt (or (getenv "REQPACK_MELPA_PROMPT") ""))
       (local-path (or (getenv "REQPACK_MELPA_LOCAL_PATH") "")))
  (dolist (dir (list package-user-dir xdg-cache-home xdg-config-home tmpdir))
    (make-directory dir t))
  (setenv "XDG_CACHE_HOME" xdg-cache-home)
  (setenv "XDG_CONFIG_HOME" xdg-config-home)
  (setenv "TMPDIR" tmpdir)
  (setq package-archives `(("melpa" . ,archive-url)))
  (package-initialize)

  (defun reqpack-melpa-field (value)
    (let ((text (cond
                 ((null value) "")
                 ((stringp value) value)
                 ((symbolp value) (symbol-name value))
                 (t (format "%s" value)))))
      (replace-regexp-in-string "[\t\r\n]+" " " text)))

  (defun reqpack-melpa-version (desc)
    (if desc (package-version-join (package-desc-version desc)) ""))

  (defun reqpack-melpa-summary (desc)
    (if desc (reqpack-melpa-field (package-desc-summary desc)) ""))

  (defun reqpack-melpa-url (desc)
    (let* ((extras (and desc (package-desc-extras desc)))
           (url (or (and (listp extras) (plist-get extras :url))
                    (and (listp extras) (cdr (assq :url extras))))))
      (reqpack-melpa-field url)))

  (defun reqpack-melpa-deps (desc)
    (if desc
        (mapconcat (lambda (req) (symbol-name (car req)))
                   (package-desc-reqs desc)
                   ",")
      ""))

  (defun reqpack-melpa-installed-desc (name)
    (cadr (assq name package-alist)))

  (defun reqpack-melpa-archive-desc (name)
    (cadr (assq name package-archive-contents)))

  (defun reqpack-melpa-row (name installed archive)
    (let* ((installed-version (reqpack-melpa-version installed))
           (archive-version (reqpack-melpa-version archive))
           (version (if (string= installed-version "") archive-version installed-version))
           (latest (if (string= archive-version "") version archive-version))
           (status (cond
                    ((and installed archive
                          (version-list-< (package-desc-version installed)
                                           (package-desc-version archive)))
                     "outdated")
                    (installed "installed")
                    (t "available")))
           (summary (if (not (string= (reqpack-melpa-summary archive) ""))
                        (reqpack-melpa-summary archive)
                      (reqpack-melpa-summary installed)))
           (homepage (if (not (string= (reqpack-melpa-url archive) ""))
                         (reqpack-melpa-url archive)
                       (reqpack-melpa-url installed)))
           (deps (if (not (string= (reqpack-melpa-deps archive) ""))
                     (reqpack-melpa-deps archive)
                   (reqpack-melpa-deps installed))))
      (concat
       (mapconcat #'identity
                  (list (symbol-name name)
                        version
                        latest
                        (if installed "true" "false")
                        status
                        summary
                        summary
                        homepage
                        deps
                        "melpa")
                  "\t")
       "\n")))

  (defun reqpack-melpa-names ()
    (if (string= names-raw "")
        nil
      (mapcar #'intern (split-string names-raw "," t))))

  (defun reqpack-melpa-refresh ()
    (let ((inhibit-message t)
          (message-log-max nil))
      (package-refresh-contents)))

  (defun reqpack-melpa-install-or-upgrade (name)
    (let ((installed (reqpack-melpa-installed-desc name))
          (archive (reqpack-melpa-archive-desc name)))
      (unless archive
        (error "Package not found: %s" name))
      (cond
       ((null installed)
        (let ((inhibit-message t)
              (message-log-max nil))
          (package-install name)))
       ((version-list-< (package-desc-version installed)
                        (package-desc-version archive))
        (let ((inhibit-message t)
              (message-log-max nil))
          (package-upgrade name))))))

  (defun reqpack-melpa-delete-installed (name)
    (let ((installed (reqpack-melpa-installed-desc name)))
      (when installed
        (let ((inhibit-message t)
              (message-log-max nil))
          (package-delete installed t)))))

  (defun reqpack-melpa-upgrade-installed (name)
    (let ((installed (reqpack-melpa-installed-desc name))
          (archive (reqpack-melpa-archive-desc name)))
      (when (and installed archive
                 (version-list-< (package-desc-version installed)
                                 (package-desc-version archive)))
        (let ((inhibit-message t)
              (message-log-max nil))
          (package-upgrade name)))))

  (defun reqpack-melpa-emit-installed-list ()
    (let ((names (sort (mapcar #'car package-alist)
                       (lambda (a b) (string< (symbol-name a) (symbol-name b))))))
      (dolist (name names)
        (princ (reqpack-melpa-row name
                                  (reqpack-melpa-installed-desc name)
                                  (reqpack-melpa-archive-desc name))))))

  (defun reqpack-melpa-emit-outdated-list ()
    (let ((names (sort (mapcar #'car package-alist)
                       (lambda (a b) (string< (symbol-name a) (symbol-name b))))))
      (dolist (name names)
        (let ((installed (reqpack-melpa-installed-desc name))
              (archive (reqpack-melpa-archive-desc name)))
          (when (and installed archive
                     (version-list-< (package-desc-version installed)
                                     (package-desc-version archive)))
            (princ (reqpack-melpa-row name installed archive)))))))

  (defun reqpack-melpa-search-match (needle desc)
    (let ((query (downcase needle))
          (name (downcase (symbol-name (package-desc-name desc))))
          (summary (downcase (reqpack-melpa-summary desc))))
      (or (string-match-p (regexp-quote query) name)
          (string-match-p (regexp-quote query) summary))))

  (defun reqpack-melpa-emit-search (query)
    (let ((matches '()))
      (dolist (entry package-archive-contents)
        (let ((archive (cadr entry)))
          (when (and archive (reqpack-melpa-search-match query archive))
            (push (car entry) matches))))
      (setq matches (sort matches (lambda (a b) (string< (symbol-name a) (symbol-name b)))))
      (when (> (length matches) 50)
        (setq matches (cl-subseq matches 0 50)))
      (dolist (name matches)
        (princ (reqpack-melpa-row name
                                  (reqpack-melpa-installed-desc name)
                                  (reqpack-melpa-archive-desc name))))))

  (defun reqpack-melpa-emit-info (name)
    (let* ((symbol (intern name))
           (installed (reqpack-melpa-installed-desc symbol))
           (archive (reqpack-melpa-archive-desc symbol)))
      (when (or installed archive)
        (princ (reqpack-melpa-row symbol installed archive)))))

  (pcase action
    ("list"
     (reqpack-melpa-emit-installed-list))
    ("outdated"
     (reqpack-melpa-refresh)
     (reqpack-melpa-emit-outdated-list))
    ("search"
     (reqpack-melpa-refresh)
     (reqpack-melpa-emit-search prompt))
    ("info"
     (reqpack-melpa-refresh)
     (reqpack-melpa-emit-info prompt))
    ("install"
     (reqpack-melpa-refresh)
     (dolist (name (reqpack-melpa-names))
       (reqpack-melpa-install-or-upgrade name)))
    ("install-local"
     (reqpack-melpa-refresh)
     (let ((inhibit-message t)
           (message-log-max nil))
       (package-install-file local-path)))
    ("remove"
     (dolist (name (reqpack-melpa-names))
       (reqpack-melpa-delete-installed name)))
    ("update"
     (reqpack-melpa-refresh)
     (dolist (name (reqpack-melpa-names))
       (reqpack-melpa-upgrade-installed name)))
    (_
     (error "Unsupported MELPA action: %s" action))))
