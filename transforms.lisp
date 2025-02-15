#|
 This file is a part of trial
 (c) 2017 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.fraf.trial)

(declaim (type mat4
               *view-matrix*
               *projection-matrix*
               *model-matrix*))

(declaim (inline view-matrix (setf view-matrix)
                 projection-matrix (setf projection-matrix)
                 model-matrix (setf model-matrix)
                 push-matrix pop-matrix
                 translate translate-by
                 rotate rotate-by
                 scale scale-by))

(declaim (ftype (function () mat4)
                projection-matrix
                view-matrix
                model-matrix))

(defvar *view-matrix* (meye 4))
(defvar *projection-matrix* (meye 4))
(defvar *model-matrix* (meye 4))
(define-global +matrix-index+ 0)
(define-global +matrix-stack+
    (let ((stack (make-array 30)))
      (dotimes (i (length stack) stack)
        (setf (aref stack i) (meye 4)))))

(defun view-matrix ()
  *view-matrix*)

(defun (setf view-matrix) (mat4)
  (setf *view-matrix* mat4))

(defun projection-matrix ()
  *projection-matrix*)

(defun (setf projection-matrix) (mat4)
  (setf *projection-matrix* mat4))

(defun model-matrix ()
  *model-matrix*)

(defun (setf model-matrix) (mat4)
  (setf *model-matrix* mat4))

(defun look-at (eye target up)
  (setf *view-matrix* (mlookat eye target up)))

(defun perspective-projection (fovy aspect near far)
  (setf *projection-matrix* (mperspective fovy aspect near far)))

(defun orthographic-projection (left right bottom top near far)
  (setf *projection-matrix* (mortho left right bottom top near far)))

(defun push-matrix ()
  (replace (marr4 (aref +matrix-stack+ (+ 0 +matrix-index+))) (marr4 *projection-matrix*))
  (replace (marr4 (aref +matrix-stack+ (+ 1 +matrix-index+))) (marr4 *view-matrix*))
  (replace (marr4 (aref +matrix-stack+ (+ 2 +matrix-index+))) (marr4 *model-matrix*))
  (incf +matrix-index+ 3))

(defun pop-matrix ()
  (decf +matrix-index+ 3)
  (replace (marr4 *projection-matrix*) (marr4 (aref +matrix-stack+ (+ 0 +matrix-index+))))
  (replace (marr4 *view-matrix*) (marr4 (aref +matrix-stack+ (+ 1 +matrix-index+))))
  (replace (marr4 *model-matrix*) (marr4 (aref +matrix-stack+ (+ 2 +matrix-index+)))))

(defmacro with-pushed-matrix (specs &body body)
  (let ((specs (or specs '(((model-matrix) :copy)))))
    `(let ,(loop for spec in specs
                 for (accessor fill) = (enlist spec :copy)
                 for variable = (ecase (unlist accessor)
                                  ((*view-matrix* view-matrix) '*view-matrix*)
                                  ((*projection-matrix* projection-matrix) '*projection-matrix*)
                                  ((*model-matrix* model-matrix) '*model-matrix*))
                 collect `(,variable
                           ,(case fill
                              (:zero `(mat4))
                              (:identity `(meye 4))
                              ((:copy NIL) `(mcopy4 ,variable))
                              (T fill))))
       ,@body)))

(defun translate (v &optional (matrix (model-matrix)))
  (declare (type vec3 v) (type mat4 matrix))
  (nmtranslate matrix v))

(defun translate-by (x y z &optional (matrix (model-matrix)))
  (let ((vec (3d-vectors::%vec3 (float x 0f0) (float y 0f0) (float z 0f0))))
    (declare (dynamic-extent vec))
    (nmtranslate matrix vec)))

(defun rotate (v angle &optional (matrix (model-matrix)))
  (declare (type vec3 v) (type mat4 matrix))
  (nmrotate matrix v angle))

(defun rotate-by (x y z angle &optional (matrix (model-matrix)))
  (let ((vec (3d-vectors::%vec3 (float x 0f0) (float y 0f0) (float z 0f0))))
    (declare (dynamic-extent vec))
    (nmrotate matrix vec angle)))

(defun scale (v &optional (matrix (model-matrix)))
  (declare (type vec3 v) (type mat4 matrix))
  (nmscale matrix v))

(defun scale-by (x y z &optional (matrix (model-matrix)))
  (let ((vec (3d-vectors::%vec3 (float x 0f0) (float y 0f0) (float z 0f0))))
    (declare (dynamic-extent vec))
    (nmscale matrix vec)))

(defun reset-matrix (&optional (matrix (model-matrix)))
  (with-fast-matref (a matrix 4)
    (setf (a 0 0) 1.0 (a 0 1) 0.0 (a 0 2) 0.0 (a 0 3) 0.0
          (a 1 0) 0.0 (a 1 1) 1.0 (a 1 2) 0.0 (a 1 3) 0.0
          (a 2 0) 0.0 (a 2 1) 0.0 (a 2 2) 1.0 (a 2 3) 0.0
          (a 3 0) 0.0 (a 3 1) 0.0 (a 3 2) 0.0 (a 3 3) 1.0)
    matrix))

(defun vec->screen (vec width height)
  (let ((clip-pos (m* (projection-matrix) (view-matrix) (model-matrix) (vxyz_ vec))))
    (let ((w (vw clip-pos)))
      (if (= 0.0f0 w)
          (vec -1 -1 0)
          (let* ((norm-pos (nv+ (nv* (vxyz clip-pos) (/ 0.5f0 w)) 0.5f0)))
            (vsetf norm-pos
                   (* width (vx norm-pos))
                   (* height (- 1 (vy norm-pos)))
                   0.0f0))))))

(defun screen->vec (vec width height)
  (let* ((x (- (* 2 (/ (vx vec) width)) 1))
         (y (+ (* -2 (/ (vy vec) height)) 1))
         (inv (minv (m* (projection-matrix) (view-matrix))))
         (res (m* inv (vec4 x y 0 1))))
    (vec3 (/ (vx res) (vw res))
          (/ (vy res) (vw res))
          0)))
