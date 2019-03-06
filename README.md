# aria
data structures and some trival stuffs in common lisp for my lady UK Aria H. Kanzaki

## constructor naming rules 
- begin with `gen-` means a service-like stuff will be start up by the constructor
- begin with `make-` means a data structure will be alloc by the constructor
- begin with nothing means nothing special

## aria.asynchronous.scheduler
a scheduler, works in a separate thread, takes tasks into queue and consume task one by one

### provides
- `(defclass scheduler ())`
- `(defun gen-scheduler (&key (onclose nil) (name "Anonymous scheduler thread")))`
- `(defmethod add ((self scheduler) (task function)))`
- `(defmethod end ((self scheduler)))`

## aria.asynchronous.timer
a timer based on scheduler, basically used for provide a `settimeout`

### provides
- `(defclass timer ())`
- `(defun gen-timer (&key (scheduler (gen-scheduler))))`
- `(defmethod settimeout ((self timer) (callback function) &optional (milliseconds 0)))`
- `(defmethod end ((self timer))`
- `(defmethod cleartimeout ((clear function)))`

## aria.concurrency.caslock
a spin lock based on cas(compare and swap)

### provides
- `(defclass caslock ())`
- `(defmethod caslock ())`
- `(defmacro with-caslock (caslock &rest expr))`
- `(defmacro with-caslock-once (caslock &rest expr))`

## aria.control.rx
frp for cl inspired by [reactivex](http://reactivex.io/)

[staltz's introduce of frp](https://gist.github.com/staltz/868e7e9bc2a7b8c1f754)

### provides

#### observable
- `(defclass observable ())`
- `(defmethod observablep ((self observable)))`
- `(defmethod observablep (self))`
- `(defmethod observable ((revolver function)))`
- `(defmethod subscribe ((self observable) (observer observer)))`
- `(defmethod subscribe ((self observable) (onnext function)))`

#### subscription
- `(defclass subscription ())`
- `(defmethod subscriptionp ((self subscription)))`
- `(defmethod subscriptionp (self))`
- `(defmethod unsubscribe ((self subscription)))`
- `(defmethod isunsubscribed ((self subsription)))`

#### observer
- `(defclass observer ())`
- `(defmethod observerp ((self observer)))`
- `(defmethod observerp (self))`
- `(defmethod observer (&key (onnext #'id) (onfail #'id) (onover #'id)))`
- `(defmethod onnext ((self observer)))`
- `(defmethod onfail ((self observer)))`
- `(defmethod onover ((self observer)))`
- `(defmethod next ((self observer) value))`
- `(defmethod fail ((self observer) reason))`
- `(defmethod over ((self observer)))`

#### subject
- `(defclass subject (observer))`
- `(defmethod subjectp ((self subject)))`
- `(defmethod subjectp (self))`
- `(defmethod subscribe ((self subject) (ob observer)))`
- `(defmethod subscribe ((self subject) (onnext function)))`

### provide for customize operator
- `(defmethod operator ((self observable) (pass function)))`
- `(defmethod operator-with-subscriptions-context ((self observable) (pass function)))`
- `(defmethod subscriptions ((self subscriptions-context)))`
- `(defmethod spin-lock ((self subscriptions-context)))`
- `(defclass subscriptions-context ())`
- `(defmethod subscriptions-context ())`
- `(defmethod register ((self subscriptions-context) (subscription subscription)))`
- `(defmethod register-source ((self subscriptions-context) (subscription subscription)))`
- `(defmethod unregister ((self subscriptions-context) (subscription subscription)))`
- `(defmethod unregister ((self subscriptions-context) (subscription null))))`
- `(defmethod unsubscribe-all ((self subscriptions-context)))`

### provide operators

#### creation
- `(defmethod of (&rest rest))`
- `(defmethod from ((seq sequence)))`
- `(defmethod range ((start number) (count number)))`
- `(defmethod empty ())`
- `(defmethod thrown (reason))`

#### filtering
- `(defmethod debounce ((self observable) (timer function) (clear function)))`
- `(defmethod distinct ((self observable) &optional (compare #'eq)))`
- `(defmethod each ((self observable) (consumer function)))`
- `(defmethod filter ((self observable) (predicate function)))`
- `(defmethod head ((self observable) &optional (predicate #'tautology) (default nil default-supplied)))`
- `(defmethod ignores ((self observable)))`
- `(defmethod sample ((self observable) (sampler observable)))`
- `(defmethod take ((self observable) (count number)))`
- `(defmethod tail ((self observable) &optional (predicate #'tautology) (default nil default-supplied)))`
- `(defmethod throttle ((self observable) (observablefn function)))`
- `(defmethod throttletime ((self observable) (milliseconds number)))`

#### transformation
- `(defmethod flatmap ((self observable) (observablefn function) &optional (concurrent -1)))`
- `(defmethod mapper ((self observable) (function function)))`
- `(defmethod mapto ((self observable) value)))`

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
