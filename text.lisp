#|
 This file is a part of trial
 (c) 2017 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.fraf.trial)

(define-asset (trial ascii) image
    #p"ascii.png"
  :min-filter :nearest
  :mag-filter :nearest)

(defun print-ascii-text (text array &optional (glyph-width 9) (glyph-height 17))
  (let ((i -1) (x 0.0)
        (gw (float glyph-width))
        (gh (float glyph-height)))
    (adjust-array array (* 4 6 (length text)))
    (macrolet ((vertex (&rest vals)
                 `(progn ,@(loop for val in vals
                                 collect `(setf (aref array (incf i)) ,val)))))
      (flet ((print-letter (char)
               (let* ((c (clamp 0 (- (char-code char) (char-code #\Space)) 95))
                      (u0 (* gw (+ 0 c)))
                      (u1 (* gw (+ 1 c))))
                 (vertex (+ x 0.0) 0.0 u0 0.0)
                 (vertex (+ x  gw) 0.0 u1 0.0)
                 (vertex (+ x  gw)  gh u1  gh)
                 (vertex (+ x  gw)  gh u1  gh)
                 (vertex (+ x 0.0)  gh u0  gh)
                 (vertex (+ x 0.0) 0.0 u0 0.0)
                 (incf x gw))))
        (loop for char across text
              do (print-letter char))))
    array))

(define-shader-entity debug-text (located-entity vertex-entity textured-entity)
  ((texture :initarg :font :initform (// 'trial 'ascii) :accessor font)
   (text :initarg :text :initform "" :accessor text)
   (foreground :initarg :foreground :initform (vec4 0 0 0 1) :accessor foreground)
   (background :initarg :background :initform (vec4 0 0 0 0) :accessor background))
  (:inhibit-shaders (textured-entity :fragment-shader)))

(defmethod initialize-instance :after ((text debug-text) &key)
  (let* ((array (make-array 0 :element-type 'single-float :adjustable T))
         (vbo (make-instance 'vertex-buffer :buffer-data array))
         (vao (make-instance 'vertex-array :bindings `((,vbo :size 2 :offset 0 :stride 16)
                                                       (,vbo :size 2 :offset 8 :stride 16))
                                           :size (* 6 (length (text text))))))
    (print-ascii-text (text text) array)
    (setf (vertex-array text) vao)))

(defmethod (setf text) :after (_ (text debug-text))
  (when (allocated-p (vertex-array text))
    (let* ((vao (vertex-array text))
           (vbo (caar (bindings vao)))
           (array (buffer-data vbo))
           (text (text text)))
      (print-ascii-text text array)
      (setf (size vao) (* 6 (length text)))
      (resize-buffer vbo (* 4 (length array)) :data array))))

(defmethod render :before ((text debug-text) (program shader-program))
  (setf (uniform program "foreground") (foreground text))
  (setf (uniform program "background") (background text)))

(define-class-shader (debug-text :vertex-shader)
  "out vec2 texcoord;
uniform sampler2D texture_image;

void main(){
  texcoord /= textureSize(texture_image, 0).rg;
}")

(define-class-shader (debug-text :fragment-shader)
  "in vec2 texcoord;
out vec4 color;
uniform sampler2D texture_image;
uniform vec4 foreground;
uniform vec4 background;

void main(){
  float fg_bg = texture(texture_image, texcoord, 0).r;
  color = mix(foreground, background, fg_bg);
}")
