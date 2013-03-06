(library
  (harlan middle annotate-free-vars)
  (export annotate-free-vars)
  (import
   (rnrs)
   (harlan helpers)
   (except (elegant-weapons helpers) ident?))

(define-match annotate-free-vars
  ((module . ,[annotate-decl* -> decl*])
   `(module . ,decl*)))

(define-match annotate-decl*
  (((,tag* ,name* . ,rest*) ...)
   (map (annotate-decl name*)
        `((,tag* ,name* . ,rest*) ...))))

(define-match (annotate-decl globals)
  ((fn ,name ,args ,type ,[(annotate-stmt globals) -> stmt fv*])
   (let ((fv* (fold-right remove/var fv* (append globals args))))
     (unless (null? fv*)
       (error 'annotate-decl "unbound variables" fv*))
     `(fn ,name ,args ,type ,stmt)))
  ((typedef ,name ,t) `(typedef ,name ,t))
  ((extern ,name ,arg-types -> ,type)
   `(extern ,name ,arg-types -> ,type))
  ((global ,name ,type ,[expr-fv -> e _])
   `(global ,name ,type ,e)))

(define-match (annotate-stmt globals)
  ((begin ,[stmt* fv**] ...)
   (values `(begin . ,stmt*)
     (apply union/var fv**)))
  ((kernel ,type ,dims ,[stmt fv*])
   (let* ((fv-expr (fold-right remove/var fv* globals))
          (fv-expr (map (lambda (p) `(,(caddr p) ,(cadr p))) fv-expr)))
     (values `(kernel ,type ,dims (free-vars . ,fv-expr) ,stmt)
             (apply union/var fv* (map expr-fv dims)))))
  ((error ,x) (values `(error ,x) `()))
  ((return) (values `(return) `()))
  ((return ,e)
   (values `(return ,e) (expr-fv e)))
  ((if ,t ,[c cfv*])
   (values `(if ,t ,c)
     (union/var (expr-fv t) cfv*)))
  ((if ,t ,[c cfv*] ,[a afv*])
   (values `(if ,t ,c ,a)
     (union/var (expr-fv t) cfv* afv*)))
  ((do ,e)
   (values `(do ,e) (expr-fv e)))
  ((let ((,x* ,t* ,e*) ...) ,[stmt fv*])
   (let ((fv* (fold-right remove/var fv* x*)))
     (values `(let ((,x* ,t* ,e*) ...) ,stmt)
       (apply union/var fv*
         (map expr-fv e*)))))
  ((let ((,x* ,t*) ...) ,[stmt fv*])
   (let ((fv* (fold-right remove/var fv* x*)))
     (values `(let ((,x* ,t*) ...) ,stmt)
             fv*)))
  ((let-region (,r ...) ,[stmt fv*])
   (values `(let-region (,r ...) ,stmt) fv*))
  ((while ,e ,[stmt sfv*])
   (values `(while ,e ,stmt)
     (union/var (expr-fv e) sfv*)))
  ((for (,x ,start ,end ,step) ,[stmt fv*])
   (let ((fv* (remove/var x fv*)))
     (values `(for (,x ,start ,end ,step) ,stmt)
       (union/var fv* (expr-fv start) (expr-fv end)
         (expr-fv step)))))
  ((set! ,x ,e)
   (values `(set! ,x ,e)
     (union/var (expr-fv x)
       (expr-fv e))))
  ((print ,e ...)
   (values `(print . ,e)
     (apply union/var (map expr-fv e))))
  ((assert ,e)
   (values `(assert ,e) (expr-fv e))))

(define-match expr-fv
  ((,t ,n) (guard (scalar-type? t)) `())
  ((var ,t ,x) `((var ,t ,x)))
  ((int->float ,[fv*]) fv*)
  ((length ,[fv*]) fv*)
  ((addressof ,[fv*]) fv*)
  ((not ,[e]) e)
  ((deref ,[fv*]) fv*)
  ((c-expr ,t ,x) `())
  ((call ,[fv*] ,[fv**] ...)
   (apply union/var fv* fv**))
  ((make-vector ,t ,r ,[fv*]) fv*)
  ((vector ,t ,r ,[fv**] ...)
   (apply union/var fv**))
  ((let ((,x* ,t* ,[fv**]) ...) ,[fv*])
   (let ((fv* (fold-right remove/var fv* x*)))
     (apply union/var fv* fv**)))
  ((if ,[tfv*] ,[cfv*] ,[afv*])
   (union/var tfv* cfv* afv*))
  ((sizeof ,t) `())
  ((,op ,[lfv*] ,[rfv*])
   (guard (or (binop? op) (relop? op)))
   (union/var lfv* rfv*))
  ((field ,[e] ,x) e)
  ((empty-struct) '())
  ((vector-ref ,t ,[vfv*] ,[ifv*])
   (union/var vfv* ifv*)))

;; end library
)
