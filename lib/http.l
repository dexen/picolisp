# 31mar03abu
# (c) Software Lab. Alexander Burger

# *Home *Allow *Gate *Agent *Host *Port *Sock *MPartLim *MPartEnd *ContLen
# *Url *SesId *ConId *InND *OutN *Frame *U1 *Help *Css

(default *HPorts 0)

(de *Mimes
   (`(chop ".css") "text/css" 86400)
   (`(chop ".gif") "image/gif" 86400)
   (`(chop ".jpg") "image/jpeg" 86400)
   (`(chop ".txt") "text/octet-stream" 1)
   (`(chop ".wav") "audio/x-wav" 1)
   (`(chop ".mp3") "audio/x-mpeg" 86400)
   (`(chop ".pdf") "application/pdf" 1)
   (`(chop ".zip") "application/zip" 1)
   (`(chop ".jar") "application/java-archive" 86400) )


### HTTP-Client ###
(de client ("Host" "Port" "Name" . "Prg")
   (when (connect "Host" (default "Port" 80))
      (let "H" @
         (out "H"
            (prinl "GET /" "Name" " HTTP/1.1")
            (prinl "Connection: close")
            (prinl "User-Agent: PicoLisp")
            (prinl "Host: " "Host" ":" "Port")
            (prinl "Accept:  text/html, text/plain")
            (prinl "Accept-Language: en")
            (prinl "Accept-Charset: utf-8")
            (prinl)
            (flush)
            (prog1
               (in "H" (run "Prg"))
               (close "H") ) ) ) ) )

# Local Password
(de pw ()
   (in ".pw" (read)) )

# Pico Shell
(de psh (Pw Tty)
   (when (and (= Pw (pw)) (in (list "ps" (pack "t" Tty)) (from "/psh ")))
      (ctty Tty)
      (out NIL (load "dbg.l" NIL))
      (bye) ) )

### HTTP-Server ###
(de server (P H)
   (setq
      *Port P
      *Home (cons H (chop H))
      P (port P) )
   (gc)
   (use S
      (loop
         (setq S (listen P))
         (NIL (fork) (close P))
         (close S) )
      (http S)
      (or *Sock (bye))
      (timeout `(* 15 60000))
      (task *Sock
         (http (or (listen *Sock 60000) (quit "Bad Client")))
         (timeout `(* 15 60000)) ) ) )

(de baseHRef ()
   (pack
      (or *Gate "http") "://" *Host
      (if *Gate "/" ":") *Port "/" ) )

(de https @
   (pass pack "https://" *Host "/" *Port "/" *SesId) )

(de software-lab ()
   (<p> T "<A HREF=\"http://www.software-lab.de\">(c) Software Lab.</A>") )

# Init crypt
(de rsa (N)
   (seed (in "/dev/urandom" (rd 20)))
   (setq *InND (rsaKey N))
   (off *OutN) )

# Application startup page
(de app ()
   (unless *Sock
      (setq
         *SesId (pack (% (in "/dev/urandom" (rd 5)) 100000000000) "~")
         *Sock (port *HPorts '*Port) ) ) )

(de allow (F)
   (if *Allow
      (?push '*Allow F)
      F ) )

# Handle HTTP-Transaction
(de http (S)
   (use (L @U)
      (catch "http"
         (in S
            (cond
               ((=T (setq L (line))) (throw "http"))
               ((match '("G" "E" "T" " " "/" @U " " "H" "T" "T" "P" . @) L)
                  (_htHead) )
               ((match '("P" "O" "S" "T" " " "/" @U " " "H" "T" "T" "P" . @) L)
                  (off *MPartLim *MPartEnd)
                  (_htHead)
                  (and *MPartLim *MPartEnd (_htMultipart)) )
               ((quit ": Bad HTTP Request" L)) )
            (setq
               L (split @U "?")
               @U (car L)
               L (mapcan
                  '((L)
                     (ifn (cdr (setq L (split L "=")))
                        (cons (_htArg (car L)))
                        (_htSet (car L) (_htArg (cadr L)))
                        NIL ) )
                  (split (cadr L) "&") ) )
            (unless (setq *Url (htDecode @U))
               (setq  *Url (car *Home)  @U (cdr *Home)) )
            (when
               (or
                  (not *Allow)
                  (format *Url)
                  (tmp? *Url)
                  (member *Url *Allow)
                  (unless (sub? "/../" *Url)
                     (find '((P) (pre? P *Url)) *Allow) ) )
               (out S
                  (cond
                     ((<> *ConId *SesId)
                        (and (call "test" "-r" "void") (httpEcho "void" NIL 86400)) )
                     ((= *Url "0")
                        (html NIL
                           (prinl "<TABLE WIDTH=\"100%\"><TR>")
                           (let N 0
                              (mapc
                                 '((L)
                                    (prin
                                       "<TD ALIGN=\"CENTER\"><A HREF=\""
                                       *SesId
                                       (inc 'N)
                                       "\" TARGET=\"MENU\">"
                                       (cadr L) )
                                    (when (car L)
                                       (prin "<IMG SRC=\"" *SesId (car L) "\">") )
                                    (prinl "</A></TD>") )
                                 *Frame ) )
                           (prinl "</TR></TABLE>") ) )
                     ((<= "1" *Url "9")
                        (html NIL
                           (prEval (nth *Frame (format *Url) 3)) ) )
                     ((member '@ @U)
                        (apply (val (intern (htDecode (cdr @)))) L) )
                     ((= '("." "l") (tail 2 @U))
                        (load *Url) )
                     ((= '("." "h" "t" "m" "l") (tail 5 @U))
                        (httpEcho *Url NIL 86400) )
                     ((assoc (tail 4 @U) *Mimes)
                        (apply httpEcho (cdr @) *Url) )
                     ((call "test" "-d" *Url)
                        (load (pack *Url "default")) )
                     (T (httpEcho *Url "application/octet-stream" 1 T)) ) ) ) ) )
      (close S) ) )

(de _htHead ()
   (use (L @X @Y)
      (if (index "~" @U)
         (setq *ConId (pack (head @ @U))  @U (cdr (nth @U @)))
         (off *ConId) )
      (off *Gate)
      (while (setq L (line))
         (cond
            ((=T L) (throw "http"))
            ((match '(~(chop "Gate: ") @X " " . @Y) L)
               (setq *Gate (pack @X)  *Adr (pack @Y)) )
            ((match '(~(chop "User-@gent: ") . @X) L)
               (setq *Agent @X) )
            ((match '(~(chop "Host: ") . @X) L)
               (setq *Host
                  (pack
                     (cond
                        (*Gate @X)
                        ((index ":" @X) (head (- @ 1) @X))
                        (T @X) ) ) ) )
            ((match '(~(chop "Content-@ype: multipart/form-data; boundary=") . @X) L)
               (setq
                  *MPartLim (append '(- -) @X)
                  *MPartEnd (append *MPartLim '(- -)) ) )
            ((match '(~(chop "Content-@ength: ") . @X) L)
               (setq *ContLen (format (pack @X))) ) ) ) ) )

# rfc1867 multipart/form-data
(de _htMultipart ()
   (use (L @X @N @V)
      (setq L (line))
      (while (= *MPartLim L)
         (unless (match '(~(chop "Content-Disposition: form-data; name=") . @X) (line))
            (throw "http") )
         (while (line)
            (when (=T @)
               (throw "http") ) )
         (cond
            ((not (member ";" @X))
               (match '("\"" @X "\"") @X)
               (_htSet @X
                  (pack
                     (make
                        (until
                           (or
                              (= *MPartLim (setq L (line)))
                              (= *MPartEnd L) )
                           (when (made)
                              (link "^J") )
                           (link L) ) ) ) ) )
            ((match '(@N ~(chop "; filename=") . @V) @X)
               (match '("\"" @N "\"") @N)
               (match '("\"" @V "\"") @V)
               (while (or (member "/" @V) (member "\\" @V))
                  (setq @V (cdr @)) )
               (let F (if (_htSet @N (pack @V)) (tmp @) "/dev/null")
                  (unless (out F (echo (pack "^M^J" *MPartLim)))
                     (call "rm" "-f" F) ) )
               (let C (char)
                  (and (= "^M" C) (setq C (char)))
                  (setq L (if (= "^J" C) *MPartLim *MPartEnd)) ) ) ) ) ) )

(de _htSet ("Var" Val)
   (use (@V @N)
      (off @N)
      (setq "Var"
         (intern
            (pack
               (cond
                  ((or (match '("*" @V "(" @N ")") "Var") (match '("%" "2" "A" @V "(" @N ")") "Var"))
                     (setq @N (_htArg @N))
                     (cons "*" @V) )
                  ((match '("%" "2" "A" . @V) "Var")
                     (cons "*" @V) )
                  ((= "*" (car "Var"))
                     "Var" )
                  (T (throw "http")) ) ) ) )
      (or
         (not *Allow)
         (memq "Var" *Allow)
         (throw "http") )
      (cond
         ((not @N) (set "Var" Val))
         ((assoc @N (val "Var")) (con @ Val))
         (T (queue "Var" (cons @N Val))) ) ) )

(de _htArg (Lst)
   (use @L
      (cond
         ((format (pack Lst)) @)
         ((match '("[" @L "]") Lst)
            (intern (htDecode @L)) )
         ((match '("{" @L "}") Lst)
            (extern (pack @L)) )
         ((match '("(" @L ")") Lst)
            (mapcar _htArg (split @L "_")) )
         (T (htDecode Lst)) ) ) )

(de _htFmt (X)
   (cond
      ((or (num? X) (ext? X))
         X )
      ((str? X)
         (pack (htEncode X)) )
      ((pair X)
         (pack "("
            (maplist
               '((L)
                  (cons
                     (_htFmt (car L))
                     (and (cdr L) "_") ) )
               X )
            ")" ) )
      (T (pack "[" (htEncode X) "]")) ) )

(de htEncode (X)
   (mapcar
      '((C)
         (if (sub? C " \"%&()=?[]_{}")
            (pack "%" (hex (char C)))
            C ) )
      (chop X) ) )

(de htDecode (Lst)
   (pack
      (make
         (while Lst
            (link
               (case (pop 'Lst)
                  ("%"
                     (let N (hex (cut 2 'Lst))
                        (char
                           (cond
                              ((< N 128) N)
                              ((< N 224)
                                 (|
                                    (>> -6 (& 31 N))
                                    (_utf6bit) ) )
                              (T
                                 (|
                                    (>> -12 (& 15 N))
                                    (>> -6 (_utf6bit))
                                    (_utf6bit) ) ) ) ) ) )
                  (T @) ) ) ) ) ) )

(de _utf6bit ()
   (pop 'Lst)
   (& 63 (hex (cut 2 'Lst))) )

(de htFmt @
   (pack
      (make
         (while (args)
            (link (_htFmt (next)))
            (and (args) (link "&")) ) ) ) )

(de htmlVar ("Var")
   (prin "NAME=\"")
   (if (pair "Var")
      (prin (car "Var") "(" (_htFmt (cdr "Var")) ")")
      (prin "Var") )
   (prin "\"") )

(de htmlVal ("Var")
   (if (pair "Var")
      (cdr (assoc (cdr "Var") (val (car "Var"))))
      (val "Var") ) )

# Http Transfer Header
(de _http (Typ Upd)
   (prinl "HTTP/1.1 200 OK")
   (prinl "Server: PicoLisp")
   (prinl "Connection: close")
   (prinl "Cache-Control: max-age=" Upd)
   (when (=0 Upd)
      (prinl "Cache-Control: no-cache") )
   (prinl "Content-Type: " (or Typ "text/html; charset=utf-8")) )

(de httpHead (Typ)
   (_http Typ 0)
   (prinl) )

# Http Echo
(de httpEcho (File Typ Upd Att)
   (_http Typ Upd)
   (prinl "Content-Length: " (car (info File)))
   (when Att
      (let F (chop File)
         (while (member "/" F)
            (setq F (cdr @)) )
         (prinl "Content-Disposition: attachment; filename=\"" F "\"") ) )
   (prinl)
   (in File (echo)) )

# Ouput navigation links
(de navi ()
   (<href> "<<<" "javascript:history.back()" (and *Frame "MAIN"))
   (if *U1
      (<href> "---" *U1 (and *Frame "MAIN"))
      (prin "---") )
   (<href> ">>>" "javascript:history.forward()" (and *Frame "MAIN")) )

(de url1 (Str)
   (setq *U1 Str) )

# Html Template
(de htempl ("File" . "Lst")
   (in "File"
      (while (echo "<BASE HREF" "<HTeMpL>" "<IMG SRC=\"HTeMpL.gif\" ALT=\"")
         (case @
            ("<BASE HREF"
               (till ">" T)
               (prin "<BASE HREF=\"" (baseHRef) "\"") )
            ("<HTeMpL>"
               (let S (till ">")
                  (until (= (tail 8 S) '`(chop "</HTeMpL"))
                     (conc S (cons (char)))
                     (if (till ">")
                        (conc S @)
                        (quit "Bad HTeMpL") ) )
                  (char)
                  (prin (eval (str (pack (head -8 S))))) ) )
            ("<IMG SRC=\"HTeMpL.gif\" ALT=\""
               (let (S (till "\"" T)  L (cddr (split (till ">") "\"")))
                  (char)
                  (apply
                     (cdr (assoc S "Lst"))
                     (mapcar pack (filter prog (cdddr L) '(NIL T .)))
                     (format (pack (car L)))
                     (format (pack (caddr L))) ) ) ) ) ) ) )

### Html Output ###
(de html ("Ttl" . "Prg")
   (httpHead)
   (prinl
      "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 "
      (if (num? (car "Prg")) "Frameset" "Transitional")
      "//EN\" \"http://www.w3.org/TR/REC-html40/loose.dtd\">" )
   (prinl "<HTML>")
   (prinl "<HEAD>")
   (prinl "<BASE HREF=\"" (baseHRef) "\">")
   (and "Ttl" (prinl "<TITLE>" "Ttl" "</TITLE>"))
   (when *Css
      (prinl
         "<link rel=\"stylesheet\" type=\"text/css\" href=\""
         *SesId *Css "\">" ) )
   (prinl "</HEAD>")
   (cond
      ((not (num? (car "Prg")))
         (prin "<BODY MARGINHEIGHT=\"0\"")
         (while (and (pair (car "Prg")) (=T (caar "Prg")))
            (prin " " (eval (cdr (pop '"Prg")))) )
         (prinl ">")
         (prEval "Prg")
         (prinl "</BODY>") )
      ((= 3 (length "Prg"))
         (prinl
            "<FRAMESET COLS=\""
            (eval (car "Prg"))
            ",*\"><FRAME NAME=\"MENU\" SRC=\""
            *SesId
            "1\"><FRAME NAME=\"MAIN\" SRC=\""
            *SesId
            (eval (cadr "Prg"))
            "\"></FRAMESET>" )
         (setq  *Frame (cons "Prg")) )
      (T
         (prinl
            "<FRAMESET ROWS=\""
            (eval (car "Prg"))
            ",*\"><FRAME SRC=\""
            *SesId
            "0\" MARGINHEIGHT=\"0\" SCROLLING=\"NO\"><FRAMESET COLS=\""
            (eval (cadr "Prg"))
            ",*\"><FRAME NAME=\"MENU\" SRC=\""
            *SesId
            "1\"><FRAME NAME=\"MAIN\" SRC=\""
            *SesId
            (eval (caddr "Prg"))
            "\"></FRAMESET></FRAMESET>" )
         (setq  *Frame (cdddr "Prg")) ) )
   (prinl "</HTML>") )

### HTML Generators ###
(de _htAlign (X)
   (cond
      ((not X))
      ((=T X) " ALIGN=\"RIGHT\"")
      ((=0 X) " ALIGN=\"CENTER\"")
      (T X) ) )

(de _sesId (Url)
   (if
      (or
         (pre? "http:" Url)
         (pre? "https:" Url)
         (pre? "mailto:" Url)
         (pre? "javascript:" Url) )
      Url
      (pack *SesId Url) ) )

(de <item> ("X")
   (cond
      ((atom "X") (prinl "X"))
      ((=T (car "X")) (apply <href> (cdr "X")))
      (T (eval "X")) ) )

(de <head> (S N X)
   (if N
      (prinl "<H" N (_htAlign X) ">" S "</H" N ">")
      (prin
         "<TABLE WIDTH=\"100%\"><TR><TD ALIGN=\"LEFT\"><H3>"
         S
         "</H3></TD><TD ALIGN=\"RIGHT\">" )
      (navi)
      (prinl "</TD></TR></TABLE>") ) )

(de <font> ("Col" "Siz" . "Prg")
   (prin "<FONT")
   (and "Col" (prin " COLOR=\"" "Col" "\""))
   (and "Siz" (prin " SIZE=\"" "Siz" "\""))
   (prin ">")
   (prEval "Prg")
   (prinl "</FONT>") )

(de <b> "Prg"
   (prin "<b>")
   (prEval "Prg")
   (prinl "</b>") )

(de <br> @
   (when (args)
      (<item> (next))
      (while (args)
         (prin " ")
         (<item> (next)) ) )
   (prinl "<br>") )

(de <center> "Prg"
   (prin "<center>")
   (prEval "Prg")
   (prinl "</center>") )

(de <p> ("X" . "Prg")
   (prin "<p" (_htAlign "X") ">")
   (prEval "Prg")
   (prinl "</p>") )

(de <name> ("Name" . "Prg")
   (prin "<a NAME=\"" "Name" "\">")
   (prEval "Prg")
   (prinl "</a>") )

(de <href> (S Url Tar)
   (prin "<A HREF=\"" (_sesId Url))
   (cond
      (Tar (prin "\" TARGET=\"" Tar))
      (*Frame (prin "\" TARGET=\"MAIN\"")) )
   (prin "\">" S "</A>") )

(de <button> @
   (prin "[")
   (pass <href>)
   (prinl "]") )

(de <img> (S A Url X)
   (and Url (prin "<A HREF=\"" (_sesId Url)  "\">"))
   (prin "<IMG SRC=\"" (_sesId S) "\" ALT=\"" A "\"" (_htAlign X) ">")
   (and Url (prin "</A>")) )

(de <list> @
   (prinl "<UL>")
   (while (args)
      (prin "<LI>")
      (<item> (next)) )
   (prinl "</UL>") )

(de <pre> "Prg"
   (prinl "<PRE>")
   (prEval "Prg")
   (prinl "</PRE>") )


# Tables
(de <table> ("Body" "Ttl" "Head" . "Prg")
   (prin "<TABLE")
   (cond
      ((=T "Body") (prin " BORDER=\"1\""))
      ("Body" (prin " " "Body")) )
   (prinl ">")
   (when "Ttl"
      (prinl "<CAPTION>" "Ttl" "</CAPTION>") )
   (when "Head"
      (prin "<TR>")
      (mapc
         '((L)
            (prin
               "<TH ALIGN="
               (case (car L)
                  ((- ^) "LEFT")
                  (+ "RIGHT")
                  (T "CENTER") )
               (and (caddr L) (pack " WIDTH=" @))
               (cadddr L)
               ">"
               (cadr L) )
            (prin "</TH>") )
         "Head" )
      (prinl "</TR>") )
   (prEval "Prg")
   (prinl "</TABLE>") )

(de <row> @
   (prinl "<TR>")
   (map
      '((X H)
         (unless (memq (car X) '(T -))
            (prinl
               "<TD ALIGN="
               (if (== '+ (caar H)) "RIGHT" "LEFT")
               (and (== '^ (caar H)) " VALIGN=TOP")
               (when (== '- (cadr X))
                  (pack
                     " COLSPAN="
                     (-
                        (length X)
                        (length
                           (seek
                              '((L) (n== '- (car L)))
                              (cdr X) ) ) ) ) )
               ">" )
            (<item> (car X))
            (prinl "</TD>") ) )
      (rest)
      "Head" )
   (prinl "</TR>") )

(de <grid> ("Head" . @)
   (<table> NIL "" "Head"
      (while (args)
         (apply <row> (next)) ) ) )

(de <th> "Prg"
   (prinl "<TR>")
   (while "Prg"
      (prin "<TH")
      (while (and (pair (car "Prg")) (=T (caar "Prg")))
         (prin " " (eval (cdr (pop '"Prg")))) )
      (prin ">")
      (<item> (eval (pop '"Prg")))
      (prinl "</TH>") )
   (prinl "</TR>") )

(de <td> "Prg"
   (prinl "<TR>")
   (while "Prg"
      (prin "<TD")
      (while (and (pair (car "Prg")) (=T (caar "Prg")))
         (prin " " (eval (cdr (pop '"Prg")))) )
      (prin ">")
      (<item> (eval (pop '"Prg")))
      (prinl "</TD>") )
   (prinl "</TR>") )


### HTML Form ###
(de <post> ("S" . "Prg")
   (prinl
      "<FORM ENCTYPE=\"multipart/form-data\" ACTION=\""
      (_sesId "S")
      "\" METHOD=POST"
      (and *Frame " TARGET=\"MAIN\"")
      ">" )
   (prEval "Prg")
   (prinl "</FORM>") )

(de <field> (N S "Var" Url X)
   (when S
      (if Url (<href> S Url) (prin S))
      (space) )
   (prin "<INPUT" (_htAlign X) " TYPE=TEXT ")
   (htmlVar "Var")
   (prinl " VALUE=\"" (htmlVal "Var") "\" SIZE=" N ">") )

(de <hidden> ("Var" "Val")
   (prin "<INPUT TYPE=HIDDEN ")
   (htmlVar "Var")
   (prinl " VALUE=\"" "Val" "\">") )

(de <passwd> (N S "Var" X)
   (when S
      (prin S)
      (space) )
   (prin "<INPUT" (_htAlign X) " TYPE=PASSWORD ")
   (htmlVar "Var")
   (prinl " VALUE=\"" (htmlVal "Var") "\" SIZE=" N ">") )

(de <upload> (N S "Var" Url)
   (when S
      (if Url (<href> S Url) (prin S))
      (space) )
   (prin "<INPUT TYPE=FILE ")
   (htmlVar "Var")
   (prinl " VALUE=\"" (htmlVal "Var") "\" SIZE=" N ">") )

(de <area> (Cols Rows S "Var" Url)
   (when S
      (if Url (<href> S Url) (prin S))
      (space) )
   (prin "<TEXTAREA ")
   (htmlVar "Var")
   (prin " COLS=" Cols " ROWS=" Rows ">" (htmlVal "Var"))
   (prinl "</TEXTAREA>") )

(de <select> (S Lst "Var")
   (when S
      (prin S)
      (space) )
   (prin "<SELECT ")
   (htmlVar "Var")
   (prin ">")
   (mapc
      '((X)
         (prin
            (if (= X (htmlVal "Var")) "<OPTION SELECTED>" "<OPTION>")
            X ) )
      Lst )
   (prinl "</SELECT>") )

(de <check> ("Var" S)
   (prin "<INPUT TYPE=HIDDEN ")
   (htmlVar "Var")
   (prinl " VALUE=\"\">")
   (prin "<INPUT TYPE=CHECKBOX ")
   (htmlVar "Var")
   (prinl " VALUE=\"T\"" (and (htmlVal "Var") " CHECKED") "> " S) )

(de <radio> ("Var" Val S)
   (prin "<INPUT TYPE=RADIO ")
   (htmlVar "Var")
   (prin " VALUE=\"" Val "\"" (and (= Val (htmlVal "Var")) " CHECKED") "> " S) )

(de <submit> (S)
   (prinl "<INPUT TYPE=SUBMIT VALUE=\"" S "\">") )

(de <reset> (S)
   (prinl "<INPUT TYPE=RESET VALUE=\"" S "\">") )