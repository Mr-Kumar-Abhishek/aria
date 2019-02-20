## aria.structures.miso-queue
a multi-in-single-out queue for common lisp

## about
this miso queue is designed for Multi-In-Single-Out situation, the operation `de`(means dequeue) is not thread safe due to it should only be excuted in a single thread

## provides
- `(defstruct queue)`
- `(defun make-queue())`
- `(defmethod en ((queue queue) e))`
- `(defmethod de ((queue queue)))`
- `(defmethod queue-empty-p ((queue queue))`
