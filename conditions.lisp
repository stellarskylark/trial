#|
 This file is a part of trial
 (c) 2016 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.fraf.trial)

(defmacro define-simple-condition (name supers slots &optional format &rest args)
  `(define-condition ,name ,supers
     ,(loop for slot in slots
            collect (if (symbolp slot)
                        `(,slot :initarg ,(intern (string slot) "KEYWORD") :initform NIL)
                        slot))
     ,@(when format
         `((:report (lambda (c s) (format s ,format ,@(loop for arg in args
                                                            collect (if (symbolp arg)
                                                                        `(slot-value c ',arg)
                                                                        arg)))))))))

(define-simple-condition trial-error (error) ())

(define-simple-condition thread-did-not-exit (trial-error)
  (thread timeout) "Thread~%  ~a~%did not exit after ~ds." thread timeout)

(define-simple-condition resource-not-allocated (trial-error)
  (resource) "The resource~%  ~s~%is required to be allocated, but was not yet." resource)

(define-simple-condition context-creation-error (trial-error)
  (message context) "Failed to create an OpenGL context~@[:~%~%  ~a~]" message)

(define-simple-condition resource-depended-on (trial-error)
  (resource dependents) "The resource~%  ~a~%cannot be unstaged as it is depended on by~{~%  ~a~}" resource dependents)

(define-simple-condition shader-compilation-error (trial-error)
  (shader log) "Failed to compile ~a:~%  ~a~%~a" shader log (format-with-line-numbers (shader-source (slot-value c 'shader))))

(define-simple-condition initarg-not-supplied (trial-error)
  (initarg) "The initarg~%  ~s~%is required but was not supplied." initarg)

(defun arg! (argument)
  (error 'initarg-not-supplied :initarg argument))
