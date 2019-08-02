#|
 This file is a part of trial
 (c) 2019 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.fraf.trial)

;; TODO: Make the attributes extensible
(defun make-particle-storage (particle-geometry &key (max-particles 1024) (vertex-attributes T))
  (let* ((vao (change-class particle-geometry 'vertex-array :vertex-attributes vertex-attributes))
         (idx (loop for i from 0
                    for binding in (bindings vao)
                    when (listp binding)
                    maximize (getf (rest binding) :index i)))
         (data (make-array (* (+ 1 3 3) max-particles) :element-type 'single-float
                                                       :initial-element 0.0f0))
         (vbo (make-instance 'vertex-buffer :buffer-data data :data-usage :stream-draw)))
    (push (list vbo :index (+ 1 idx) :offset (* 0 4) :size 2 :stride (* 8 4) :instancing 1) (bindings vao))
    (push (list vbo :index (+ 2 idx) :offset (* 2 4) :size 3 :stride (* 8 4) :instancing 1) (bindings vao))
    (push (list vbo :index (+ 3 idx) :offset (* 5 4) :size 3 :stride (* 8 4) :instancing 1) (bindings vao))
    (values vao (+ 1 idx))))

(define-shader-subject particle-emitter (bakable)
  ((live-particles :initform 0 :accessor live-particles)
   (vertex-array :initarg :vertex-array :accessor vertex-array)
   (vertex-buffer  :initform NIL :accessor vertex-buffer)))

(defmethod bake ((emitter particle-emitter))
  (let ((array (etypecase (vertex-array emitter)
                 (mesh (input (vertex-array emitter)))
                 (vertex-array (vertex-array emitter)))))
    (setf (vertex-buffer emitter)
          (loop for binding in (bindings array)
                do (when (and (listp binding)
                              (eql 1 (getf (rest binding) :instancing)))
                     (return (first binding)))
                finally (error "No instanced binding found in ~a" array)))))

(defmethod paint ((emitter particle-emitter) pass)
  (let ((vao (vertex-array emitter)))
    (gl:bind-vertex-array (gl-name vao))
    (%gl:draw-elements-instanced (vertex-form vao) (size vao) :unsigned-int 0 (live-particles emitter))))

(defgeneric initial-particle-state (emitter tick location velocity lifetime))
(defgeneric update-particle-state (emitter tick location velocity lifetime))
(defgeneric new-particle-count (emitter tick)) ; => N

(define-handler (particle-emitter tick) (ev)
  (declare (optimize speed))
  (let* ((vbo (vertex-buffer particle-emitter))
         (data (buffer-data vbo))
         (location (vec 0 0 0))
         (velocity (vec 0 0 0))
         (lifetime (vec 0 0))
         (write-offset 0))
    (declare (type (simple-array single-float (*)) data))
    (declare (type (unsigned-byte 32) write-offset))
    (labels ((read-particle (offset)
               (setf (vx3 location) (aref data (+ 2 offset)))
               (setf (vy3 location) (aref data (+ 3 offset)))
               (setf (vz3 location) (aref data (+ 4 offset)))
               (setf (vx3 velocity) (aref data (+ 5 offset)))
               (setf (vy3 velocity) (aref data (+ 6 offset)))
               (setf (vz3 velocity) (aref data (+ 7 offset))))
             (write-particle (offset)
               (setf (aref data (+ 0 offset)) (vx2 lifetime))
               (setf (aref data (+ 1 offset)) (vy2 lifetime))
               (setf (aref data (+ 2 offset)) (vx3 location))
               (setf (aref data (+ 3 offset)) (vy3 location))
               (setf (aref data (+ 4 offset)) (vz3 location))
               (setf (aref data (+ 5 offset)) (vx3 velocity))
               (setf (aref data (+ 6 offset)) (vy3 velocity))
               (setf (aref data (+ 7 offset)) (vz3 velocity))
               (incf write-offset 8)))
      (loop for read-offset from 0 below (* 8 (live-particles particle-emitter)) by 8
            do (setf (vx2 lifetime) (aref data (+ 0 read-offset)))
               (setf (vy2 lifetime) (aref data (+ 1 read-offset)))
               (when (< (vx2 lifetime) (vy2 lifetime))
                 (read-particle read-offset)
                 (update-particle-state particle-emitter ev location velocity lifetime)
                 (when (< (vx2 lifetime) (vy2 lifetime))
                   (write-particle write-offset))))
      (loop repeat (new-particle-count particle-emitter ev)
            while (< write-offset (length data))
            do (initial-particle-state particle-emitter ev location velocity lifetime)
               (write-particle write-offset))
      (setf (live-particles particle-emitter) (/ write-offset 8))
      (update-buffer-data vbo data))))
