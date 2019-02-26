# aria
data structures and some trival stuffs in common lisp for my lady UK Aria H. Kanzaki

## aria.structure.queue
Just a normal queue

### provides
- `(defstruct queue)`
- `(defun make-queue())`
- `(defmethod en ((self queue) e))`
- `(defmethod de ((self queue)))`
- `(defmethod queue-empty-p ((self queue))`

## aria.structure.miso-queue
A multi-in-single-out queue

### about
This miso queue is designed for Multi-In-Single-Out situation, the operation `de`(means dequeue) is not thread safe due to it should only be excuted in a single thread

### provides
- `(defstruct queue)`
- `(defun make-queue())`
- `(defmethod en ((self queue) e))`
- `(defmethod de ((self queue)))`
- `(defmethod queue-empty-p ((self queue))`

## aria.structure.mimo-queue
A multi-in-multi-out queue

### about
This miso queue is designed for Multi-In-Multi-Out situation, methods `en`, `de`, `queue-empty-p` are all thread safe.

### provides
- `(defstruct queue)`
- `(defun make-queue())`
- `(defmethod en ((self queue) e))`
- `(defmethod de ((self queue)))`
- `(defmethod queue-empty-p ((self queue))`

## aria.structure.pair-heap
A pairing heap, [wiki](https://en.wikipedia.org/wiki/Pairing_heap)

### about
In default options, `(make-heap)` will generate a min pairing heap with number type elements.

With the help of `(make-heap)`'s option `:compare` and `:accessor`, the heap could expand to sort by a user defined way.

### provides
- `(defstruct pair-heap)`
- `(defmethod make-heap (&key (element nil) (compare (lambda (x y) (< x y)) (accessor (lambda (x) x)))`
- `(defmethod en ((self pair-heap) e))`
- `(defmethod de ((self pair-heap)))`
- `(defmethod heap-empty-p ((self pair-heap)))`
- `(defmethod find-top ((self pair-heap)))`
