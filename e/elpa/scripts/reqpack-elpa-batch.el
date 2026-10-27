(setq package-enable-at-startup nil)
(setq package-check-signature nil)

(defun reqpack-die (message)
  (princ (concat message "\n") standard-error)
  (kill-emacs 1))

(defun reqpack-arg (index)
  (or (nth index command-line-args-left) ""))

(let* ((action (reqpack-arg 0))
       (data-root (reqpack-arg 1))
       (args (nthcdr 2 command-line-args-left)))
  (unless (and action (not (string-empty-p action)))
    (reqpack-die "missing ELPA action"))
  (unless (and data-root (not (string-empty-p data-root)))
    (reqpack-die "missing ELPA data root"))

  (require 'cl-lib)
  (require 'package)

  (setq package-user-dir (expand-file-name "elpa" data-root))
  (setq package-gnupghome-dir (expand-file-name "gnupg" data-root))
  (setq package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                           ("nongnu" . "https://elpa.nongnu.org/nongnu/")))

  (dolist (dir (list package-user-dir package-gnupghome-dir))
    (make-directory dir t))

  (package-initialize)

  (defun reqpack-field (value)
    (let ((text (cond ((null value) "")
                      ((stringp value) value)
                      ((symbolp value) (symbol-name value))
                      (t (format "%s" value)))))
      (replace-regexp-in-string "[\t\r\n]+" " " text)))

  (defun reqpack-extra (desc key)
    (let ((extras (and desc (package-desc-extras desc))))
      (cond ((plist-member extras key) (plist-get extras key))
            ((and (listp extras) (assq key extras)) (cdr (assq key extras)))
            (t nil))))

  (defun reqpack-version (desc)
    (if desc (package-version-join (package-desc-version desc)) ""))

  (defun reqpack-summary (desc)
    (if desc (reqpack-field (package-desc-summary desc)) ""))

  (defun reqpack-url (desc)
    (reqpack-field (or (reqpack-extra desc :url) (reqpack-extra desc :homepage))))

  (defun reqpack-license (desc)
    (reqpack-field (reqpack-extra desc :license)))

  (defun reqpack-deps (desc)
    (if desc
        (mapconcat (lambda (req) (symbol-name (car req))) (package-desc-reqs desc) ",")
      ""))

  (defun reqpack-archive-name (desc)
    (reqpack-field (or (and desc (package-desc-archive desc)) 'local)))

  (defun reqpack-installed-desc (name)
    (cadr (assq name package-alist)))

  (defun reqpack-archive-desc (name)
    (cadr (assq name package-archive-contents)))

  (defun reqpack-row (name installed archive)
    (let* ((installed-version (reqpack-version installed))
           (archive-version (reqpack-version archive))
           (version (if (string= installed-version "") archive-version installed-version))
           (latest (if (string= archive-version "") version archive-version))
           (status (cond ((and installed archive (version-list-< (package-desc-version installed) (package-desc-version archive))) "outdated")
                         (installed "installed")
                         (t "available")))
           (summary (if (not (string= (reqpack-summary archive) "")) (reqpack-summary archive) (reqpack-summary installed)))
           (description summary)
           (homepage (if (not (string= (reqpack-url archive) "")) (reqpack-url archive) (reqpack-url installed)))
           (deps (if (not (string= (reqpack-deps archive) "")) (reqpack-deps archive) (reqpack-deps installed)))
           (repo (if archive (reqpack-archive-name archive) (reqpack-archive-name installed))))
      (concat
       (mapconcat #'identity
                  (list (symbol-name name)
                        version
                        latest
                        (if installed "true" "false")
                        status
                        summary
                        description
                        homepage
                        deps
                        repo
                        (reqpack-license archive)
                        (reqpack-license installed))
                  "\t")
       "\n")))

  (defun reqpack-search-match (needle desc)
    (let ((query (downcase needle))
          (name (downcase (symbol-name (package-desc-name desc))))
          (summary (downcase (reqpack-summary desc))))
      (or (not (null (string-match-p (regexp-quote query) name)))
          (not (null (string-match-p (regexp-quote query) summary))))))

  (defun reqpack-refresh ()
    (let ((inhibit-message t)
          (message-log-max nil))
      (package-refresh-contents)))

  (defun reqpack-installed-names ()
    (sort (mapcar #'car package-alist)
          (lambda (a b) (string< (symbol-name a) (symbol-name b)))))

  (defun reqpack-install-or-upgrade (name)
    (let ((installed (reqpack-installed-desc name))
          (archive (reqpack-archive-desc name)))
      (unless archive
        (error "Package not found: %s" name))
      (cond
       ((null installed)
        (let ((inhibit-message t) (message-log-max nil))
          (package-install name t)))
       ((version-list-< (package-desc-version installed) (package-desc-version archive))
        (let ((inhibit-message t) (message-log-max nil))
          (package-upgrade name))))))

  (defun reqpack-delete-installed (name)
    (let ((installed (reqpack-installed-desc name)))
      (when installed
        (let ((inhibit-message t) (message-log-max nil))
          (package-delete installed nil t)))))

  (defun reqpack-upgrade-installed (name)
    (let ((installed (reqpack-installed-desc name))
          (archive (reqpack-archive-desc name)))
      (when (and installed archive (version-list-< (package-desc-version installed) (package-desc-version archive)))
        (let ((inhibit-message t) (message-log-max nil))
          (package-upgrade name)))))

  (condition-case err
      (pcase action
        ("list"
         (dolist (name (reqpack-installed-names))
           (princ (reqpack-row name (reqpack-installed-desc name) (reqpack-archive-desc name)))))
        ("outdated"
         (reqpack-refresh)
         (dolist (name (reqpack-installed-names))
           (let ((installed (reqpack-installed-desc name))
                 (archive (reqpack-archive-desc name)))
             (when (and installed archive (version-list-< (package-desc-version installed) (package-desc-version archive)))
               (princ (reqpack-row name installed archive))))))
        ("search"
         (reqpack-refresh)
         (let ((matches '())
               (query (or (car args) "")))
           (dolist (entry package-archive-contents)
             (let ((archive (cadr entry)))
               (when (and archive (reqpack-search-match query archive))
                 (push (car entry) matches))))
           (setq matches (sort matches (lambda (a b) (string< (symbol-name a) (symbol-name b)))))
           (when (> (length matches) 50)
             (setq matches (cl-subseq matches 0 50)))
           (dolist (name matches)
             (princ (reqpack-row name (reqpack-installed-desc name) (reqpack-archive-desc name))))))
        ("info"
         (reqpack-refresh)
         (let* ((symbol (intern (or (car args) "")))
                (installed (reqpack-installed-desc symbol))
                (archive (reqpack-archive-desc symbol)))
           (when (or installed archive)
             (princ (reqpack-row symbol installed archive)))))
        ("install"
         (reqpack-refresh)
         (dolist (name args)
           (reqpack-install-or-upgrade (intern name))))
        ("install-local"
         (let ((inhibit-message t) (message-log-max nil))
           (package-install-file (or (car args) ""))))
        ("remove"
         (dolist (name args)
           (reqpack-delete-installed (intern name))))
        ("update"
         (reqpack-refresh)
         (dolist (name args)
           (reqpack-upgrade-installed (intern name))))
        ("update-all"
         (reqpack-refresh)
         (dolist (name (reqpack-installed-names))
           (reqpack-upgrade-installed name)))
        (_
         (reqpack-die (concat "unsupported ELPA action: " action))))
    (error
     (reqpack-die (error-message-string err)))))
