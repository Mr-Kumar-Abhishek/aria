# aria
data structures and some trival stuffs in common lisp for my lady UK Aria H. Kanzaki

## constructor naming rules 
- begin with `gen-` means a service-like stuff will be start up by the constructor
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
Reactive Extensions for common lisp inspired by [reactivex](http://reactivex.io/)

[staltz's introduce of Reactive Programming](https://gist.github.com/staltz/868e7e9bc2a7b8c1f754)

### provides

#### observable
- `(defmethod observable ((revolver function)))`

#### observer
- `(defmethod observer (&key onnext onfail onover))`

#### subject
- `(defmethod subject ())`

#### subscriber
- `(defmethod next ((self subscriber) value))`
- `(defmethod fail ((self subscriber) reason))`
- `(defmethod over ((self subscriber)))`

#### subscribe
- `(defmethod subscribe ((self observable) (observer observer)))`
- `(defmethod subscribe ((self observable) (onnext function)))`
- `(defmethod subscribe ((self subject) (onnext function)))`
- `(defmethod subscribe ((self subject) (ob observer)))`
- `(defmethod unsubscribe ((self subscriber)))`
- `(defmethod isunsubscribed ((self subscriber)))`

### operation
- `(defmacro pipe (&rest rest))`
- `(defmacro with-pipe (observable &rest rest))`

### provide operators

#### creation
- `(defmethod empty ())`
- `(defmethod from ((seq sequence)))`
- `(defmethod of (&rest rest))`
- `(defmethod range ((start integer) (count integer)))`
- `(defmethod start ((supplier function)))`
- `(defmethod thrown (reason))`

#### error-handling
- `(defmethod catcher ((self observable) (observablefn function)))`
- `(defmethod retry ((self observable) (number integer)))`
- `(defmethod retryuntil ((self observable) (predicate function)))`
- `(defmethod retrywhen ((self observable) (notifier observable)))`
- `(defmethod retrywhile ((self observable) (predicate function)))`

#### filtering
- `(defmethod debounce ((self observable) (observablefn function)))`
- `(defmethod distinct ((self observable) &optional (compare #'eq)))`
- `(defmethod filter ((self observable) (predicate function)))`
- `(defmethod head ((self observable) &optional (predicate #'tautology) (default nil default-supplied)))`
- `(defmethod ignores ((self observable)))`
- `(defmethod sample ((self observable) (sampler observable)))`
- `(defmethod single ((self observable) (predicate function)))`
- `(defmethod skip ((self observable) (integer integer)))`
- `(defmethod skipuntil ((self observable) (predicate function)))`
- `(defmethod skipuntil ((self observable) (notifier observable)))`
- `(defmethod skipwhile ((self observable) (predicate function)))`
- `(defmethod tail ((self observable) &optional (predicate #'tautology) (default nil default-supplied)))`
- `(defmethod take ((self observable) (count integer)))`
- `(defmethod tap ((self observable) (consumer function)))`
- `(defmethod tap ((self observable) (observer observer)))`
- `(defmethod tapfail ((self observable) (consumer function)))`
- `(defmethod tapnext ((self observable) (consumer function)))`
- `(defmethod tapover ((self observable) (consumer function)))`
- `(defmethod throttle ((self observable) (observablefn function)))`
- `(defmethod throttletime ((self observable) (milliseconds integer)))`

#### transformation
- `(defmethod buffer ((self observable) (notifier observable)))`
- `(defmethod buffercount ((self observable) (count integer) &optional (overlap count)))`
- `(defmethod concatmap ((self observable) (observablefn function)))`
- `(defmethod concatmapto ((self observable) (observable observable)))`
- `(defmethod exhaustmap ((self observable) (observablefn function)))`
- `(defmethod expand ((self observable) (observablefn function) &optional (concurrent -1)))`
- `(defmethod flatmap ((self observable) (observablefn function) &optional (concurrent -1)))`
- `(defmethod groupby ((self observable) (keyselector function)))`
- `(defmethod mapper ((self observable) (function function)))`
- `(defmethod mapto ((self observable) value)))`
- `(defmethod reducer ((self observable) (function function) initial-value))`
- `(defmethod scan ((self observable) (function function) initial-value))`
- `(defmethod switchmap ((self observable) (observablefn function)))`

## aria.structure.queue
Just a normal queue

### provides
- `(defstruct queue)`
- `(defmethod queue ())`
- `(defmethod en ((self queue) e))`
- `(defmethod de ((self queue)))`
- `(defmethod emptyp ((self queue))`

## aria.structure.miso-queue
A multi-in-single-out queue

### about
This miso queue is designed for Multi-In-Single-Out situation, the operation `de`(means dequeue) is not thread safe due to it should only be excuted in a single thread

### provides
- `(defstruct queue)`
- `(defstruct (miso-queue (:include queue)))`
- `(defmethod miso-queue ())`
- `(defmethod en ((self miso-queue) e))`
- `(defmethod de ((self queue)))`
- `(defmethod emptyp ((self queue))`

## aria.structure.mimo-queue
A multi-in-multi-out queue

### about
This miso queue is designed for Multi-In-Multi-Out situation, methods `en`, `de`, `emptyp` are all thread safe.

### provides
- `(defstruct queue)`
- `(defstruct (mimo-queue (:include miso-queue)))`
- `(defmethod mimo-queue ())`
- `(defmethod en ((self miso-queue) e))`
- `(defmethod de ((self mimo-queue)))`
- `(defmethod emptyp ((self mimo-queue)))`

## aria.structure.pair-heap
A pairing heap, [wiki](https://en.wikipedia.org/wiki/Pairing_heap)

### about
In default options, `(pair-heap)` will generate a min pairing heap with number type elements.

With the help of `(pair-heap)`'s option `:compare` and `:accessor`, the heap could expand to sort by a user defined way.

### provides
- `(defstruct pair-heap)`
- `(defmethod pair-heap (&key (element nil) (compare (lambda (x y) (< x y)) (accessor (lambda (x) x)))`
- `(defmethod en ((self pair-heap) e))`
- `(defmethod de ((self pair-heap)))`
- `(defmethod emptyp ((self pair-heap)))`
- `(defmethod find-top ((self pair-heap)))`

## aria.structure.ring
A circular array

### about
The first element will be erased when add element into a full circular array.

Elements could be add to the circular array in both direction.

### provides
- `(defstruct ring)`
- `(defmethod ring ((size integer)))`
- `(defmethod en ((self ring) value))`
- `(defmethod de ((self ring)))`
- `(defmethod enr ((self ring) value))`
- `(defmethod der ((self ring)))`
- `(defmethod size ((self ring)))`
- `(defmethod emptyp ((self ring)))`
- `(defmethod tolist ((self ring)))`
