(in-package :function-cache-test)

(defun run-all-tests (&optional (use-debugger t))
  (let ((lisp-unit:*print-failures* t)
        (lisp-unit:*print-errors* t)
        (lisp-unit::*use-debugger* use-debugger))
   (run-tests :all)))

(defvar *thunk-test-count* 0)
(defcached thunk-tester ()
  (incf *thunk-test-count*)
  7)

(define-test thunk-1
  (let ((*thunk-test-count* 0))
    (clear-cache *thunk-tester-cache*)
    (thunk-tester)
    (thunk-tester)
    (assert-eql 7 (thunk-tester))
    (assert-eql 1 *thunk-test-count*)))


(defvar *single-cell-test-count* 0)
(defcached (single-cell-tester
            :cache-class 'single-cell-function-cache)
    (a)
  (incf *single-cell-test-count*)
  a)

(define-test single-cell-test
  (let ((*single-cell-test-count* 0))
    (clear-cache *single-cell-tester-cache*)
    (single-cell-tester 2)
    (assert-equal 2 (single-cell-tester 2))
    (assert-equal 1 *single-cell-test-count*)
    (single-cell-tester 3)
    (assert-equal 3 (single-cell-tester 3))
    (assert-equal 2 *single-cell-test-count*)
    ))

(defvar *hash-test-count* 0)
(defcached fn0 (a0)
  (incf *hash-test-count*)
  a0)

(define-test fn0-test
  (let ((*hash-test-count* 0))
    (clear-cache *fn0-cache*)
    (fn0 1)
    (fn0 1)
    (assert-eql 1 (fn0 1))
    (assert-eql 1 *hash-test-count*)
    (fn0 2)
    (fn0 2)
    (assert-eql 2 (fn0 2))
    (assert-eql 2 *hash-test-count*)))

(defcached fn1 (a &key b c )
  (incf *hash-test-count*)
  (list a b c))

(define-test fn1-test
  (let ((*hash-test-count* 0))
    (clear-cache *fn1-cache*)
    (fn1 1 :b 2)
    (fn1 1 :b 2)
    (assert-equal '(1 2 nil) (fn1 1 :b 2))
    (assert-eql 1 *hash-test-count*)
    (fn1 2)
    (fn1 2 :c 3)
    (assert-equal '(1 2 3) (fn1 1 :b 2 :c 3))
    (assert-eql 4 *hash-test-count*)))


(progn
  (defparameter *shared-cache* (make-hash-table :test 'equal :synchronized t))
  (defparameter *shared-count* 0)
  (defparameter *shared0-count* 0)
  (defparameter *shared1-count* 0)
  (defcached (shared0-test :table *shared-cache*)
      (a &rest them)
    (incf *shared-count*)
    (incf *shared0-count*)
    (cons a them))

  (defcached (shared1-test :table *shared-cache*)
      (a &rest them)
    (incf *shared-count*)
    (incf *shared1-count*)
    (cons a them)))

(define-test shared-test
  (let ((*shared-count* 0)
        (*shared0-count* 0)
        (*shared1-count* 0))
    (clear-cache *shared0-test-cache*)
    (clear-cache *shared1-test-cache*)
    (shared0-test 1 2 3)
    (shared0-test 1 2 3)
    (shared0-test 1 2 3)
    (assert-equal '(1 2 3) (shared0-test 1 2 3))
    (assert-eql 1 *shared0-count*)
    (assert-eql 0 *shared1-count*)
    (assert-eql 1 *shared-count*)
    (shared1-test 1 2 3)
    (shared1-test 1 2 3)
    (assert-equal '(1 2 3) (shared1-test 1 2 3))
    (assert-eql 1 *shared0-count*)
    (assert-eql 1 *shared1-count*)
    (assert-eql 2 *shared-count*)
    ))

(define-test shared-clear-test
  (let ((*shared-count* 0)
        (*shared0-count* 0)
        (*shared1-count* 0))
    (clear-cache *shared0-test-cache*)
    (clear-cache *shared1-test-cache*)
    (shared0-test 1 2 3)
    (shared0-test 2 3 4)
    (assert-eql 2 (cached-results-count *shared-cache*))
    (clear-cache 'shared0-test)
    (assert-eql 0 (cached-results-count *shared-cache*)
                :should-have-removed-the-final-entry
                *shared-cache*)
    (shared0-test 1 2 3)
    (shared0-test 2 3 4)
    (shared1-test 1 2 3)
    (shared1-test 2 3 4)
    (assert-eql 4 (cached-results-count *shared-cache*))
    (clear-cache *shared1-test-cache*)
    (assert-eql 2 (cached-results-count *shared-cache*))
    (clear-cache *shared0-test-cache* (list 2 3 4))
    (assert-eql 1 (cached-results-count *shared-cache*))
    (clear-cache 'shared0-test)
    (assert-eql 0 (cached-results-count *shared-cache*)
                :should-have-removed-the-final-entry
                *shared-cache*)
    ))

(defvar *partial-clear-count* 0)
(defcached partial-clearer (a b)
  (incf *partial-clear-count*)
  (+ a b))

(define-test partial-clear-test
  (let ((*partial-clear-count* 0))
    (clear-cache *partial-clearer-cache*)
    (partial-clearer 1 2)
    (partial-clearer 1 2) ;; no side effect
    (partial-clearer 1 3)
    (partial-clearer 2 2)
    (partial-clearer 2 3)
    ;; check that our cache contains entries we expect and
    ;; that we side effected 4 times
    (assert-eql *partial-clear-count* 4)
    (assert-eql 4 (cached-results-count *partial-clearer-cache*))

    ;; remove all arg lists with 1 as the first arg
    (clear-cache-partial-arguments
     *partial-clearer-cache* 1)
    (assert-eql 2 (cached-results-count *partial-clearer-cache*))

    (partial-clearer 2 2);; no side effect
    ;; we only have the entries that start with 2
    (assert-eql 2 (cached-results-count *partial-clearer-cache*))
    (assert-eql *partial-clear-count* 4) ;; 4 total side effects
    (partial-clearer 1 2)
    (partial-clearer 1 3);; re cache a 2 entries
    (assert-eql *partial-clear-count* 6)
    (assert-eql 4 (cached-results-count *partial-clearer-cache*))

    (clear-cache-partial-arguments
     *partial-clearer-cache* '(dont-care 2))
    (assert-eql 2 (cached-results-count *partial-clearer-cache*))
    (partial-clearer 1 3)
    (assert-eql *partial-clear-count* 6)
    (partial-clearer 1 2)
    (assert-eql *partial-clear-count* 7)
    (assert-eql 3 (cached-results-count *partial-clearer-cache*))

    ))

(progn
  (defparameter *opt-cache* (make-hash-table :test 'equal :synchronized t))
  (defun get-opt-cache () *opt-cache*)
  (defparameter *opt-count* 0)
  (defparameter *opt0-count* 0)
  (defparameter *opt1-count* 0)
  (defcached (opt0-test :table '*opt-cache*)
      (a &rest them)
    (incf *opt-count*)
    (incf *opt0-count*)
    (cons a them))

  (defcached (opt1-test :table #'get-opt-cache)
      (a &rest them)
    (incf *opt-count*)
    (incf *opt1-count*)
    (cons a them)))

(define-test optional-shared-test
  (let ((*opt-count* 0)
        (*opt0-count* 0)
        (*opt1-count* 0))
    (clear-cache *opt0-test-cache*)
    (clear-cache *opt1-test-cache*)
    (opt0-test 1 2 3)
    (opt0-test 1 2 3)
    ;; block cache
    (let (*opt-cache*) (opt0-test 1 2 3))
    (assert-equal '(1 2 3) (opt0-test 1 2 3))
    (assert-eql 2 *opt0-count*)
    (assert-eql 0 *opt1-count*)
    (assert-eql 2 *opt-count*)
    (opt1-test 1 2 3)
    ;; block cache
    (let (*opt-cache*) (opt1-test 1 2 3))
    (assert-equal '(1 2 3) (opt1-test 1 2 3))
    (assert-eql 2 *opt0-count*)
    (assert-eql 2 *opt1-count*)
    (assert-eql 4 *opt-count*)
    ))

(defparameter *purge-count* 0)
(defcached (purge-test :timeout 1) (&rest them)
  (incf *purge-count*)
  them)

(define-test purge-test
  (let ((*purge-count* 0))
    (clear-cache 'purge-test)
    (purge-test 1 2 3)
    (assert-equal '(1 2 3) (purge-test 1 2 3))
    (assert-eql *purge-count* 1)
    (sleep 1.5)
    (assert-equal 1 (cached-results-count (cached-results *purge-test-cache*)))
    (purge-cache 'purge-test)
    (assert-equal 0 (cached-results-count (cached-results *purge-test-cache*)))
    (purge-test 1 2 3)
    (purge-test 1 2 3)
    (assert-equal '(1 2 3) (purge-test 1 2 3))
    (assert-eql *purge-count* 2)
    (sleep 1.5)
    (assert-equal 1 (cached-results-count (cached-results *purge-test-cache*)))
    (purge-cache *purge-test-cache*)
    (assert-equal 0 (cached-results-count (cached-results *purge-test-cache*)))))

