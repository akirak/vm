;;; vm-thread.el ---  Thread support for VM
;;;
;;; This file is part of VM
;;
;; Copyright (C) 1994, 2001 Kyle E. Jones
;; Copyright (C) 2003-2006 Robert Widhopf-Fenk
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License along
;; with this program; if not, write to the Free Software Foundation, Inc.,
;; 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

;;; Code:

(defun vm-th-youngest-date-of (id-sym)
  (get id-sym 'youngest-date))

(defun vm-th-set-youngest-date-of (id-sym date)
  (put id-sym 'youngest-date date))

(defun vm-th-oldest-date-of (id-sym)
  (get id-sym 'oldest-date))

(defun vm-th-set-oldest-date-of (id-sym date)
  (put id-sym 'oldest-date date))

(defsubst vm-th-message-of (id-sym)
  (and (boundp id-sym) (symbol-value id-sym)))

(defsubst vm-th-set-message-of (id-sym m)
  (set id-sym m))

(defsubst vm-th-messages-of (id-sym)
  (get id-sym 'messages))

(defsubst vm-th-set-messages-of (id-sym ml)
  (put id-sym 'messages ml))

(defsubst vm-th-children-of (id-sym)
  (get id-sym 'children))

(defun vm-th-child-messages-of (id-sym)
  (let ((kids (vm-th-children-of id-sym))
	(result nil)
	m)
    (while kids
      (setq m (vm-th-message-of (car kids)))
      (if m
	  (setq result (cons m result)))
      (setq kids (cdr kids)))
    (nreverse result)))

(defsubst vm-th-set-children-of (id-sym ml)
  (put id-sym 'children ml))

(defsubst vm-th-descendants-of (id-sym)
  (get id-sym 'descendants))

(defsubst vm-th-set-descendants-of (id-sym ml)
  (put id-sym 'descendants ml))

;; (defsubst vm-th-parent-of (id-sym)
;;   (and (boundp id-sym) (symbol-value id-sym)))

;; (defsubst vm-th-set-parent-of (id-sym p-sym)
;;   (set id-sym p-sym))

(defsubst vm-th-parent-of (id-sym)
  (get id-sym 'parent))

(defsubst vm-th-set-parent-of (id-sym p-sym)
  ;; For safety, set the symbol-value to nil
  (unless (boundp id-sym)
    (set id-sym nil))
  (put id-sym 'parent p-sym))

(defsubst vm-th-date-of (id-sym)
  (get id-sym 'date))

(defsubst vm-th-set-date-of (id-sym date)
  (put id-sym 'date date))

(defsubst vm-th-thread-subtree-of (id-sym)
  (get id-sym 'thread-subtree))

(defsubst vm-th-set-thread-subtree-of (id-sym ml)
  (put id-sym 'thread-subtree ml))


;;;###autoload
(defun vm-toggle-threads-display ()
  "Toggle the threads display on and off.
When the threads display is on, the folder will be sorted by
thread and thread indentation (via the %I summary format specifier)
will be visible."
  (interactive)
  (vm-select-folder-buffer-and-validate)
  ;; get numbering of new messages done now
  ;; so that the sort code only has to worry about the
  ;; changes it needs to make.
  (vm-update-summary-and-mode-line)
  (vm-set-summary-redo-start-point t)
  (setq vm-summary-show-threads (not vm-summary-show-threads))
  (if vm-summary-show-threads
      (vm-sort-messages "thread")
    (vm-sort-messages "physical-order")))

;;;###autoload
(defun vm-build-threads (message-list)
  "For all messages in MESSAGE-LIST, build thread information in the
`vm-thread-obarray' and `vm-thread-subject-obarray'.  If MESSAGE-LIST
is nil, do it for all the messages in the folder.  USR, 2010-07-15"
  (if (not (vectorp vm-thread-obarray))
      (setq vm-thread-obarray (make-vector 641 0)
	    vm-thread-subject-obarray (make-vector 641 0)))
  (let ((mp (or message-list vm-message-list))
	(n 0)
	;; Just for laughs, make the update interval vary.
	(modulus (+ (% (vm-abs (random)) 11) 40))
	;; no need to schedule reindents of reparented messages
	;; unless there were already messages present.
	(schedule-reindents message-list)
	m parent parent-sym id id-sym date refs old-parent-sym)
    ;; Build threads using references
    (while mp
      (setq m (car mp)
	    parent (vm-parent m)
	    id (vm-su-message-id m)
	    id-sym (intern id vm-thread-obarray)
	    date (vm-so-sortable-datestring m))
      (vm-th-set-message-of id-sym m)
      (vm-th-set-messages-of id-sym (cons m (vm-th-messages-of id-sym)))
      (vm-th-set-date-of id-sym date)
      (if (and schedule-reindents (null (cdr (vm-th-messages-of id-sym))))
	  (vm-thread-mark-for-summary-update 
	   (cons m (vm-th-child-messages-of id-sym))))
      (vm-th-set-parent-of id-sym nil)
      (when parent
	(setq parent-sym (intern parent vm-thread-obarray))
	(cond ((or (null (vm-th-parent-of id-sym))
		   (eq (vm-th-parent-of id-sym) parent-sym))
	       (vm-th-set-parent-of id-sym parent-sym))
	      (t
	       (let ((kids (vm-th-children-of old-parent-sym ))
		     (msgs (vm-th-messages-of id-sym))
		     (msg-sym nil))
		 (setq old-parent-sym (vm-th-parent-of id-sym))
		 (while msgs
		   (setq msg-sym (vm-th-thread-symbol (car msgs)))
		   (setq kids (delq msg-sym kids)
			 msgs (cdr msgs)))
		 (vm-th-set-children-of old-parent-sym kids)
		 (vm-th-set-parent-of id-sym parent-sym)
		 (if schedule-reindents
		     (vm-thread-mark-for-summary-update
		      (vm-th-messages-of id-sym))))))
	(vm-th-set-children-of 
	 parent-sym (cons id-sym (vm-th-children-of parent-sym))))
	;; FIXME is the parent property automatically set to nil?
        ;; (if (not (boundp id-sym))
	;;   (vm-th-set-parent-of id-sym nil))
      ;; use the references header to set parenting information
      ;; for ancestors of this message.  This does not override
      ;; a parent pointer for a message if it already exists.
      (if (cdr (setq refs (vm-references m)))
	  (let (parent-sym id-sym msgs msg-syms)
	    (setq parent-sym (intern (car refs) vm-thread-obarray)
		  refs (cdr refs))
	    (while refs
	      (setq id-sym (intern (car refs) vm-thread-obarray))
	      (if (vm-th-parent-of id-sym)
		  nil
		(vm-th-set-parent-of id-sym parent-sym)
		(setq msgs (vm-th-messages-of id-sym))
		(setq msg-syms 
		      (mapcar 'vm-th-thread-symbol msgs))
;; 		(if msgs
;; 		    (vm-th-set-children-of 
;; 		     parent-sym 
;; 		     (append msg-syms (vm-th-children-of parent-sym))
;; 		     ))
		(vm-th-set-children-of 
		 parent-sym 
		 (cons id-sym (vm-th-children-of parent-sym)))
		(if schedule-reindents
		    (vm-thread-mark-for-summary-update msgs)))
	      (setq parent-sym id-sym
		    refs (cdr refs)))))
      (setq mp (cdr mp) n (1+ n))
      (if (zerop (% n modulus))
	  (message "Building threads (by reference)... %d" n)))

    ;; Build threads using subject
    (when vm-thread-using-subject
      (let (subject subject-sym)
	(setq n 0 mp (or message-list vm-message-list))
	(while mp
	  (setq m (car mp)
		parent (vm-parent m)
		id (vm-su-message-id m)
		id-sym (intern id vm-thread-obarray)
		date (vm-so-sortable-datestring m))
	  (setq subject (vm-so-sortable-subject m)
		subject-sym (intern subject vm-thread-subject-obarray))
	  ;; inhibit-quit because we need to make sure the asets
	  ;; below are an atomic group.
	  (let* ((inhibit-quit t))
	    ;; if this subject was never seen before create the
	    ;; information vector.
	    (if (not (boundp subject-sym))
		(set subject-sym
		     (vector id-sym date nil (list m)))
	      ;; this subject seen before 
	      (aset (symbol-value subject-sym) 3
		    (cons m (aref (symbol-value subject-sym) 3)))
	      (if (string< date (aref (symbol-value subject-sym) 1))
		  (let* ((vect (symbol-value subject-sym))
			 (i-sym (aref vect 0)))
		    ;; optimization: if we know that this message
		    ;; already has a parent, then don't bother
		    ;; adding it to the list of child messages
		    ;; since we know that it will be threaded and
		    ;; unthreaded using the parent information.
		    (unless (and (vm-th-parent-of i-sym)
				 (vm-th-messages-of (vm-th-parent-of i-sym)))
		      (aset vect 2 (cons i-sym (aref vect 2))))
		    (aset vect 0 id-sym)
		    (aset vect 1 date)
		    ;; this loops _and_ recurses and I'm worried
		    ;; about it going into a spin someday.  So I
		    ;; unblock interrupts here.  It's not critical
		    ;; that it finish... the summary will just be out
		    ;; of sync.
		    (when schedule-reindents
		      (let ((inhibit-quit nil))
			(vm-thread-mark-for-summary-update (aref vect 2)))))
		;; optimization: if we know that this message
		;; already has a parent, then don't bother adding
		;; it to the list of child messages, since we
		;; know that it will be threaded and unthreaded
		;; using the parent information.
		(unless (and parent 
			     (vm-th-messages-of 
			      (intern parent vm-thread-obarray)))
		  (aset (symbol-value subject-sym) 2
			(cons id-sym (aref (symbol-value subject-sym) 2)))))))
	  (setq mp (cdr mp) n (1+ n))
	  (when (zerop (% n modulus))
	    (message "Building threads (by subject)... %d" n)))))

    ;; Calculate thread-subtrees for all the known message ID's
    (mapatoms
     (lambda (id-sym)
       (vm-th-thread-subtree id-sym))
     vm-thread-obarray)

    (when (> n modulus)
      (message "Building threads... done"))))

;; used by the thread sort code.
;;
;; vm-th-thread-list initializes the oldest-date property on
;; the message-id symbols.  Since this property is used as an
;; ordering key by the thread sort the oldest-date properties
;; must be computed before the sort begins, not during it.
;; Otherwise the sort won't be stable and there will be chaos.

;;;###autoload
(defun vm-build-thread-lists ()
  (let ((mp vm-message-list))
    (while mp
      (vm-th-thread-list (car mp))
      (setq mp (cdr mp)))))

(defun vm-thread-mark-for-summary-update (message-list)
  (let (m)
    (while message-list
      (setq m (car message-list))
      ;; if thread-list is null then we've already marked this
      ;; message, or it doesn't need marking.
      (if (null (vm-thread-list-of m))
	  nil
	(vm-mark-for-summary-update m t)
	(vm-set-thread-list-of m nil)
	(vm-set-thread-indentation-of m nil)
	(vm-thread-mark-for-summary-update
	 (vm-th-child-messages-of (intern 
				   (vm-su-message-id m) vm-thread-obarray))))
      (setq message-list (cdr message-list)))))

(defun vm-thread-list (message)
  "Returns the thread-list, i.e., the lineage of MESSAGE, as a list of
symbols interned in vm-thread-obarray."
  (let ((done nil)
	(m message)
	(loop-recovery-point nil)
	(date (vm-so-sortable-datestring message))
	thread-list id-sym subject-sym loop-sym root-date youngest-date)
    (save-excursion
      (set-buffer (vm-buffer-of m))
      (fillarray vm-thread-loop-obarray 0)
      (setq id-sym (intern (vm-su-message-id m) vm-thread-obarray)
	    thread-list (list id-sym))
      (set (intern (symbol-name id-sym) vm-thread-loop-obarray) t)
      (while (not done)
	;; save the date of the oldest message in this thread
	(setq root-date (vm-th-oldest-date-of id-sym))
	(if (or (null root-date)
		(string< date root-date))
	    (vm-th-set-oldest-date-of id-sym date))
	;; save the date of the youngest message in this thread
	(setq youngest-date (vm-th-youngest-date-of id-sym))
	(if (or (null root-date)
		(string< youngest-date date))
	    (vm-th-set-youngest-date-of id-sym date))
	(if (vm-th-parent-of id-sym)
	    (progn
	      (setq id-sym (vm-th-parent-of id-sym)
		    loop-sym (intern (symbol-name id-sym)
				     vm-thread-loop-obarray))
	      (if (boundp loop-sym)
		  ;; loop detected, bail...
		  (setq done t
			thread-list (or loop-recovery-point thread-list))
		(set loop-sym t)
		(setq thread-list (cons id-sym thread-list)
		      m (car (vm-th-messages-of id-sym)))))
	  (if (null m)
	      (setq done t)
	    (if (null vm-thread-using-subject)
		(setq done t)
	      (setq subject-sym
		    (intern (vm-so-sortable-subject m)
			    vm-thread-subject-obarray))
	      (if (or (not (boundp subject-sym))
		      (eq (aref (symbol-value subject-sym) 0) id-sym))
		  (setq done t)
		(setq id-sym (aref (symbol-value subject-sym) 0)
;; seems to cause more trouble than it fixes
;; revisit this later.
;;		      loop-recovery-point (or loop-recovery-point
;;					      thread-list)
		      loop-sym (intern (symbol-name id-sym)
				       vm-thread-loop-obarray))
		(if (boundp loop-sym)
		    ;; loop detected, bail...
		    (setq done t
			  thread-list (or loop-recovery-point thread-list))
		  (set loop-sym t)
		  (setq thread-list (cons id-sym thread-list)
			m (car (vm-th-messages-of id-sym)))))))))
      thread-list )))

;; remove message struct from thread data.
;;
;; optional second arg non-nil means forget information that
;; might be different if the message contents changed.
;;
;; message must be a real (non-virtual) message

;;;###autoload
(defun vm-unthread-message (message &optional message-changing)
  "Removes MESSAGE from its current thread.  If optional argument
MESSAGE-CHANGING is non-nil, then its thread data is removed from
the thread database so that it can be recalculated.  Otherwise,
the message's thread data still stores the original thread, even
though the message itself is removed from those threads.  (A bit odd,
but works when the message is getting expunged from its folder.)

MESSAGE should be a real (non-virtual) message.

The full functionality of this function is not entirely clear.  
						USR, 2010-03-13"
  (save-excursion
    (let ((mp (cons message (vm-virtual-messages-of message)))
	  m date id-sym subject-sym vect p-sym)
      (while mp
	(setq m (car mp))
	(set-buffer (vm-buffer-of m))
	(if (not (vectorp vm-thread-obarray))
	    nil
	  (let ((inhibit-quit t))
	    ;; discard cached thread properties
	    (vm-set-thread-list-of m nil)
	    (vm-set-thread-indentation-of m nil)
	    ;; handles for the thread and thread-subject databases
	    (setq id-sym (intern (vm-su-message-id m) vm-thread-obarray)
		  subject-sym (intern (vm-so-sortable-subject m)
				      vm-thread-subject-obarray))
	    (if (boundp id-sym)
		(progn
		  ;; remove m from its erstwhile thread
		  (vm-th-set-messages-of 
		   id-sym (delq m (vm-th-messages-of id-sym)))
		  ;; remove m from the children list of its erstwhile parent
		  (vm-thread-mark-for-summary-update 
		   (vm-th-child-messages-of id-sym))
		  (setq p-sym (vm-th-parent-of id-sym))
		  (and p-sym 
		       (vm-th-set-children-of 
			p-sym (delq id-sym (vm-th-children-of p-sym))))
		  ;; teset the thread dates of the m
		  (setq date (vm-so-sortable-datestring message))
		  (vm-th-set-youngest-date-of id-sym date)
		  (vm-th-set-oldest-date-of id-sym date)
		  ;; if message changed, reset its thread to nil
		  (if message-changing
		      (set id-sym nil))))
	    (if (and (boundp subject-sym)
		     (setq vect (symbol-value subject-sym)))
		(if (not (eq id-sym (aref vect 0)))
		    (aset vect 2 (delq m (aref vect 2)))
		  (if message-changing
		      (if (null (cdr (aref vect 3)))
			  (makunbound subject-sym)
			(let ((p (aref vect 3))
			      oldest-msg oldest-date children)
			  (setq oldest-msg (car p)
				oldest-date (vm-so-sortable-datestring (car p))
				p (cdr p))
			  (while p
			    (if (and (string-lessp 
				      (vm-so-sortable-datestring (car p))
				      oldest-date)
				     (not (eq m (car p))))
				(setq oldest-msg (car p)
				      oldest-date 
				      (vm-so-sortable-datestring (car p))))
			    (setq p (cdr p)))
			  (aset vect 0 (intern (vm-su-message-id oldest-msg)
					       vm-thread-obarray))
			  (aset vect 1 oldest-date)
			  (setq children (delq oldest-msg (aref vect 2)))
			  (aset vect 2 children)
			  (aset vect 3 (delq m (aref vect 3)))
			  ;; I'm not sure there aren't situations
			  ;; where this might loop forever.
			  (let ((inhibit-quit nil))
			    (vm-thread-mark-for-summary-update children)))))))))
	  (setq mp (cdr mp))))))

;;;###autoload
(defun vm-references (m)
  "Returns the cached references list of message M.  If the cache is
nil, retrieves the references list from the headers and caches it.
USR, 2010-03-13"
  (or (vm-references-of m)
      (vm-set-references-of
       m
       (let (references)
	 (setq references (vm-get-header-contents m "References:" " "))
	 (and references (vm-parse references "[^<]*\\(<[^>]+>\\)"))))))

;;;###autoload
(defun vm-parent (m)
  "Returns the cached parent message of message M (in its thread).  If
the cache is nil, calculates the parent and caches it.  USR, 2010-03-13"
  (or (vm-parent-of m)
      (vm-set-parent-of
       m
       (or (car (vm-last (vm-references m)))
	   (let (in-reply-to ids id)
	     (setq in-reply-to (vm-get-header-contents m "In-Reply-To:" " ")
		   ids (and in-reply-to (vm-parse in-reply-to
						  "[^<]*\\(<[^>]+>\\)")))
	     (while ids
	       (if (< (length id) (length (car ids)))
		   (setq id (car ids)))
	       (setq ids (cdr ids)))
	     (and id (vm-set-references-of m (list id)))
	     id )))))

;;;###autoload
(defun vm-th-thread-indentation (m)
  "Returns the cached thread-indentation of message M.  If the cache is
nil, calculates the thread-indentation and caches it.  USR, 2010-03-13"
  (or (vm-thread-indentation-of m)
      (let ((p (vm-th-thread-list m)))
	(while (and p (null (vm-th-messages-of (car p))))
	  (setq p (cdr p)))
	(vm-set-thread-indentation-of m (1- (length p)))
	(vm-thread-indentation-of m))))

;;;###autoload
(defun vm-th-thread-list (m)
  "Returns the cached thread-list of message M.  If the cache is nil,
calculates the thread-list and caches it.  USR, 2010-03-13"
  (or (vm-thread-list-of m)
      (progn
	(vm-set-thread-list-of m (vm-thread-list m))
	(vm-thread-list-of m))))

;;;###autoload
(defun vm-th-thread-subtree (m-sym)
  "Returns a list of messages that are in the thread subtree of
an interned message id M-SYM.  Threads should have been built
for this function to work.  Otherwise it returns nil."
    (if (not (vectorp vm-thread-obarray))
	nil
      (or (vm-th-thread-subtree-of m-sym)
	  ;; otherwise calcuate the thread-subtree
	  (let ((list (list m-sym))
		(loop-obarray (make-vector 29 0))
		subject-sym id-sym
		result)
	    (while list
	      (setq id-sym (car list))
	      (if (and (vm-th-messages-of id-sym)
		       (not (memq (car (vm-th-messages-of id-sym)) result)))
		  (setq result (append (vm-th-messages-of id-sym) result)))
	      (when (null (intern-soft (symbol-name id-sym) loop-obarray))
		(intern (symbol-name id-sym) loop-obarray)
		(nconc list (copy-sequence (vm-th-children-of id-sym)))
		(mapc
		 (lambda (m)
		   (setq subject-sym (intern (vm-so-sortable-subject m)
					     vm-thread-subject-obarray))
		   (if (and (boundp subject-sym) 
			    (eq id-sym (aref (symbol-value subject-sym) 0)))
		       (nconc list (copy-sequence
				    (aref (symbol-value subject-sym)
					  2)))))
		 (vm-th-messages-of id-sym)))
	      (setq list (cdr list)))
	    (vm-th-set-thread-subtree-of m-sym result)
	    result))))

;;;###autoload
(defun vm-th-thread-count (m)
  "Returns the number of messages in the thread-subtree of message M.
Threads should have been built for this function to work."
  (with-current-buffer (vm-buffer-of m)
    (length (vm-th-thread-subtree 
	     (intern (vm-su-message-id m) vm-thread-obarray)))))

;;;###autoload
(defun vm-th-thread-symbol (m)
  "Returns the interned symbol of message M which carries the
threading information."
  (with-current-buffer (vm-buffer-of m)
    (intern (vm-su-message-id m) vm-thread-obarray)))

;;;###autoload
(defun vm-th-thread-subject-symbol (m)
  "Returns the interned symbol of message M which carries the
subject-based threading information."
  (with-current-buffer (vm-buffer-of m)
    (intern (vm-su-subject m) vm-thread-subject-obarray)))



(provide 'vm-thread)

;;; vm-thread.el ends here
