#|
 This file is a part of trial
 (c) 2018 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.fraf.trial)

;; FIXME: configurable defaults

(defclass resource ()
  ((generator :initarg :generator :initform NIL :reader generator)
   (name :initarg :name :initform NIL :reader name)))

(defmethod print-object ((resource resource) stream)
  (print-unreadable-object (resource stream :type T :identity T)
    (format stream "~@[~a~]~@[ ~a~]~:[~; ALLOCATED~]" (generator resource) (name resource) (allocated-p resource))))

(defgeneric allocate (resource))
(defgeneric deallocate (resource))
(defgeneric allocated-p (resource))

(defmethod load ((resource resource))
  (unless (allocated-p resource)
    (v:trace :trial.resource "Loading ~a" resource)
    (allocate resource)))

(defmethod allocate :around ((resource resource))
  (call-next-method)
  resource)

(defmethod deallocate :around ((resource resource))
  (call-next-method)
  resource)

(defun check-allocated (resource)
  (unless (allocated-p resource)
    (restart-case
        (error 'resource-not-allocated :resource resource)
      (continue ()
        :report "Allocate the resource now and continue."
        (allocate resource)))))

(defclass foreign-resource (resource)
  ((data-pointer :initform NIL :initarg :data-pointer :accessor data-pointer)))

(defmethod allocated-p ((resource foreign-resource))
  (data-pointer resource))

(defmethod deallocate :after ((resource foreign-resource))
  (setf (data-pointer resource) NIL))

(defclass gl-resource (foreign-resource)
  ((data-pointer :accessor gl-name)))
