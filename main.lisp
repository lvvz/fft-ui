(uiop:define-package :fft-ui/main
    (:nicknames :fft-ui)
  (:use :cl :hunchentoot :cl-fad)
  (:import-from :alexandria
                #:read-file-into-string)
  (:export #:start-server))


(in-package :fft-ui)


;;;;;;;;;;;;;;;;;;;;;;;;; Server Boilerplate ;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass vhost (tbnl:acceptor)
  ((dispatch-table
    :initform '()
    :accessor dispatch-table
    :documentation "List of dispatch functions"))
  (:default-initargs
   :address (error "Host address must be specified.")
   :document-root nil
   :error-template-directory nil
   :persistent-connections-p t))

(defun create-dispatcher (exact-prefix method handler)
  (check-type exact-prefix string)
  (check-type method symbol)
  (check-type handler (or symbol function))
  (lambda (request)
    (and (eq method (tbnl:request-method request))
         (if (string= exact-prefix (tbnl:script-name request))
             handler
             nil))))

(defmethod tbnl:acceptor-dispatch-request ((vhost vhost) request)
  (mapc (lambda (dispatcher)
          (let ((handler (funcall dispatcher request)))
            (when handler
              (return-from tbnl:acceptor-dispatch-request (funcall handler request)))))
        (dispatch-table vhost))
  (call-next-method))


(defmethod tbnl:acceptor-status-message ((acceptor vhost) (http-status-code (eql #.tbnl:+http-internal-server-error+)) &key error &allow-other-keys)
  (declare (ignore error))
  "the server has dun goofed")


;;;;;;;;;;;;;;;;;;; Functions that will be routed ;;;;;;;;;;;;;;;;;;;;

;;; Each of these functions should take a REQUEST as input.
;;;
;;; POST data can be retrieved with
;;;
;;;     (hunchentoot:raw-post-data :request request :force-text t)

(defun hello (request)
  (declare (ignore request))
  "Hello!")

(defun file-dialog (request)
  (declare (ignore request))
  (read-file-into-string (path:catfile (asdf:system-source-directory :fft-ui)
                                       "fd.html")))

;; (defun generate-network (request)
;;   (let ((stream (make-string-output-stream)))
;;     (apply #'init-network (get-post-request-parameters +network-generate-form+ request))
;;     (encode (alist-hash-table `(("nodes" . ,(prepare-nodes))
;;                              ("edges" . ,(prepare-edges))))
;;          stream)
;;     (get-output-stream-string stream)))

(defvar *audiofile-path* #P"/tmp/audiofile.mp3")

(defun audio-handle-page (path file-name)
  (alexandria:copy-file path *audiofile-path*)
  (format nil "<html>
  <head>
  </head>
  <body style=\"background: #fff;\">
    <p>~A</p>
    <audio controls>
      <source src=\"audiofile\" type=\"audio/mpeg\">
        Your browser does not support the audio tag.
    </audio>
    </div>
  </body>
</html>" file-name))

(defun upload-file (request)
  (destructuring-bind (path file-name content-type) (post-parameter "file" request)
    (declare (ignore content-type))
    (audio-handle-page path file-name)))

(defun get-audiofile (request)
  (declare (ignore request))
  (alexandria:read-file-into-byte-vector *audiofile-path*))

(defun say-number (request)
  (let* ((number-string (tbnl:get-parameter "number" request))
         (parsed (and number-string (parse-integer number-string :junk-allowed t))))
    (cond
      ((null number-string)
       "Provide a number with <tt>?number=</tt><em>n</em>!")
      (parsed
       (format nil "~R" parsed))
      (t
       "You gave me something that really isn't a number."))))

;;;;;;;;;;;;;;;;;;;;;;; Server Initialization ;;;;;;;;;;;;;;;;;;;;;;;;

(defvar *app* nil)

(defparameter *routes* '(("/" :get file-dialog)
                         ("/upload" :post upload-file)
                         ("/audiofile" :get get-audiofile)
                         ;; ("/say" :get say-number)
                         ;; ("/net" :get initialize-network)
                         ;; ("/nodes" :get get-nodes)
                         ;; ("/edges" :get get-edges)
                         ;; ("/gen-net" :post generate-network)
                         ;; ("/rt-cols" :get rt-cols)
                         ;; ("/rt-data" :post rt-data)
                         ;; ("/rt-shortest-paths" :post rt-shortest-paths)
                         ;; ("/send-message" :post send-message)
                         ))

(defun start-server (&optional (port 2020))
  ;; Some optional configuration.
  (setq tbnl:*show-lisp-errors-p* t
        tbnl:*show-lisp-backtraces-p* t
        tbnl:*catch-errors-p* t)
  (tbnl:reset-session-secret)
  (setq tbnl:*default-connection-timeout* 15)
  ;; (Re-)start the app.
  (unless (null *app*)
    (stop-server))
  (setq *app*
        (make-instance 'vhost
                       :address "127.0.0.1"
                       :port port
                       :taskmaster (make-instance 'tbnl:one-thread-per-connection-taskmaster)))
  
  ;; Install the routes onto *APP*.
  (dolist (route *routes*)
    (destructuring-bind (uri method handler) route
      (push (create-dispatcher uri method handler) (dispatch-table *app*))))

  (tbnl:start *app*))

(defun stop-server ()
  (unless (null *app*)
    (tbnl:stop *app*)
    (setq *app* nil)))
