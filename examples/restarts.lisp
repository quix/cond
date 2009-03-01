;;
;; http://c2.com/cgi/wiki?LispRestartExample
;;

(define-condition restartable-gethash-error (error)
  ((key  :initarg :key)
   (hash :initarg :hash))
  (:report (lambda (condition stream)
             (format stream "~A error getting ~A from ~A."
                     'restartable-gethash 
                     (slot-value condition 'key)
                     (slot-value condition 'hash)))))

(defun read-new-value (what)
  (format t "Enter a new ~A: " what)
  (multiple-value-list (eval (read))))

(defun restartable-gethash (key hash &optional default)
  (loop (block try-gethash
          (restart-case
           (multiple-value-bind (value present)
               (gethash key hash default)
             (if present
                 (return-from restartable-gethash (values value present))
               (error 'restartable-gethash-error :key key :hash hash)))
           (continue ()
                     :report "Return not having found the value."
                     (return-from restartable-gethash (values default nil)))
           (try-again ()
                      :report "Try getting the key from the hash again."
                      (return-from try-gethash))
           (use-new-key (new-key)
                        :report "Use a new key."
                        :interactive (lambda () (read-new-value "key"))
                        (setq key new-key))
           (use-new-hash (new-hash)
                         :report "Use a new hash."
                         :interactive (lambda () (read-new-value "hash"))
                         (setq hash new-hash))))))

(defun make-and-initialize-hash-table (plist &rest options)
  (loop with hash-table = (apply #'make-hash-table options)
        for (key value) on plist by #'cddr
        do (setf (gethash key hash-table) value)
        finally (return hash-table)))

(defparameter *fruits-and-vegetables*
  (make-and-initialize-hash-table
   '(apple   fruit 
     orange  fruit
     lettuce vegetable
     tomato  depends-on-who-you-ask)))

(restartable-gethash 'mango *fruits-and-vegetables*)

