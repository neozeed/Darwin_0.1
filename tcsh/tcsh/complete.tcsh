#
# $Id: complete.tcsh,v 1.1.1.2 1998/11/05 01:13:03 wsanchez Exp $
# example file using the new completion code
#

onintr -
if (! $?prompt) goto end

if ($?tcsh) then
    if ($tcsh != 1) then
   	set rev=$tcsh:r
	set rel=$rev:e
	set pat=$tcsh:e
	set rev=$rev:r
    endif
    if ($rev > 5 && $rel > 1) then
	set complete=1
    endif
    unset rev rel pat
endif

if ($?complete) then
    set noglob
    set hosts
    foreach f ($HOME/.hosts /usr/local/etc/csh.hosts $HOME/.rhosts /etc/hosts.equiv)
        if ( -r $f ) then
	    set hosts = ($hosts `grep -v "+" $f | tr -s " " "	" | cut -f 1`)
	endif
    end
    if ( -r $HOME/.netrc ) then
	set f=`awk '/machine/ { print $2 }' < $HOME/.netrc` >& /dev/null
	set hosts=($hosts $f)
    endif
    unset f
    if ( ! $?hosts ) then
	set hosts=(hyperion.ee.cornell.edu phaeton.ee.cornell.edu \
		   guillemin.ee.cornell.edu vangogh.cs.berkeley.edu \
		   ftp.uu.net prep.ai.mit.edu export.lcs.mit.edu \
		   labrea.stanford.edu sumex-aim.stanford.edu \
		   tut.cis.ohio-state.edu)
    endif

    complete ywho  	n/*/\$hosts/	# argument from list in $hosts
    complete rsh	p/1/\$hosts/ c/-/"(l n)"/   n/-l/u/ N/-l/c/ n/-/c/ p/2/c/ p/*/f/
    complete xrsh	p/1/\$hosts/ c/-/"(l 8 e)"/ n/-l/u/ N/-l/c/ n/-/c/ p/2/c/ p/*/f/
    complete rlogin 	p/1/\$hosts/ c/-/"(l 8 e)"/ n/-l/u/
    complete telnet 	p/1/\$hosts/ p/2/x:'<port>'/ n/*/n/

    complete cd  	p/1/d/		# Directories only
    complete chdir 	p/1/d/
    complete pushd 	p/1/d/
    complete popd 	p/1/d/
    complete pu 	p/1/d/
    complete po 	p/1/d/
    complete complete 	p/1/X/		# Completions only
    complete uncomplete	n/*/X/
    complete exec 	p/1/c/		# Commands only
    complete trace 	p/1/c/
    complete strace 	p/1/c/
    complete which	n/*/c/
    complete where	n/*/c/
    complete skill 	p/1/c/
    complete dde	p/1/c/ 
    complete adb	c/-I/d/ n/-/c/ N/-/"(core)"/ p/1/c/ p/2/"(core)"/
    complete sdb	p/1/c/
    complete dbx	c/-I/d/ n/-/c/ N/-/"(core)"/ p/1/c/ p/2/"(core)"/
    complete xdb	p/1/c/
    complete gdb	n/-d/d/ n/*/c/
    complete ups	p/1/c/
    complete set	'c/*=/f/' 'p/1/s/=' 'n/=/f/'
    complete unset	n/*/s/
    complete alias 	p/1/a/		# only aliases are valid
    complete unalias	n/*/a/
    complete xdvi 	n/*/f:*.dvi/	# Only files that match *.dvi
    complete dvips 	n/*/f:*.dvi/
    complete tex 	n/*/f:*.tex/	# Only files that match *.tex
    complete latex 	n/*/f:*.{tex,ltx}/
    complete su		c/--/"(login fast preserve-environment command shell \
			help version)"/	c/-/"(f l m p c s -)"/ \
			n/{-c,--command}/c/ \
			n@{-s,--shell}@'`cat /etc/shells`'@ n/*/u/
    complete cc 	c/-[IL]/d/ \
              c@-l@'`\ls -1 /usr/lib/lib*.a | sed s%^.\*/lib%%\;s%\\.a\$%%`'@ \
			c/-/"(o l c g L I D U)"/ n/*/f:*.[coasi]/
    complete acc 	c/-[IL]/d/ \
       c@-l@'`\ls -1 /usr/lang/SC1.0/lib*.a | sed s%^.\*/lib%%\;s%\\.a\$%%`'@ \
			c/-/"(o l c g L I D U)"/ n/*/f:*.[coasi]/
    complete gcc 	c/-[IL]/d/ \
		 	c/-f/"(caller-saves cse-follow-jumps delayed-branch \
		               elide-constructors expensive-optimizations \
			       float-store force-addr force-mem inline \
			       inline-functions keep-inline-functions \
			       memoize-lookups no-default-inline \
			       no-defer-pop no-function-cse omit-frame-pointer \
			       rerun-cse-after-loop schedule-insns \
			       schedule-insns2 strength-reduce \
			       thread-jumps unroll-all-loops \
			       unroll-loops syntax-only all-virtual \
			       cond-mismatch dollars-in-identifiers \
			       enum-int-equiv no-asm no-builtin \
			       no-strict-prototype signed-bitfields \
			       signed-char this-is-variable unsigned-bitfields \
			       unsigned-char writable-strings call-saved-reg \
			       call-used-reg fixed-reg no-common \
			       no-gnu-binutils nonnull-objects \
			       pcc-struct-return pic PIC shared-data \
			       short-enums short-double volatile)"/ \
		 	c/-W/"(all aggregate-return cast-align cast-qual \
		      	       comment conversion enum-clash error format \
		      	       id-clash-len implicit missing-prototypes \
		      	       no-parentheses pointer-arith return-type shadow \
		      	       strict-prototypes switch uninitialized unused \
		      	       write-strings)"/ \
		 	c/-m/"(68000 68020 68881 bitfield fpa nobitfield rtd \
			       short c68000 c68020 soft-float g gnu unix fpu \
			       no-epilogue)"/ \
		 	c/-d/"(D M N)"/ \
		 	c/-/"(f W vspec v vpath ansi traditional \
			      traditional-cpp trigraphs pedantic x o l c g L \
			      I D U O O2 C E H B b V M MD MM i dynamic \
			      nodtdlib static nostdinc undef)"/ \
		 	c/-l/f:*.a/ \
		 	n/*/f:*.{c,C,cc,o,a,s,i}/
    complete g++ 	n/*/f:*.{C,cc,o,s,i}/
    complete CC 	n/*/f:*.{C,cc,o,s,i}/
    complete rm 	c/--/"(directory force interactive verbose \
			recursive help version)"/ c/-/"(d f i v r R -)"/ \
			n/*/f:^*.{c,cc,C,h,in}/	# Protect precious files
    complete vi 	n/*/f:^*.[oa]/
    complete bindkey    N/-a/b/ N/-c/c/ n/-[ascr]/'x:<key-sequence>'/ \
			n/-[svedlr]/n/ c/-[vedl]/n/ c/-/"(a s k c v e d l r)"/\
			n/-k/"(left right up down)"/ p/2-/b/ \
			p/1/'x:<key-sequence or option>'/

    complete find 	n/-fstype/"(nfs 4.2)"/ n/-name/f/ \
		  	n/-type/"(c b d f p l s)"/ n/-user/u/ n/-group/g/ \
			n/-exec/c/ n/-ok/c/ n/-cpio/f/ n/-ncpio/f/ n/-newer/f/ \
		  	c/-/"(fstype name perm prune type user nouser \
		  	     group nogroup size inum atime mtime ctime exec \
			     ok print ls cpio ncpio newer xdev depth \
			     daystart follow maxdepth mindepth noleaf version \
			     anewer cnewer amin cmin mmin true false uid gid \
			     ilname iname ipath iregex links lname empty path \
			     regex used xtype fprint fprint0 fprintf \
			     print0 printf not a and o or)"/ \
			     n/*/d/

    complete -%*	c/%/j/			# fill in the jobs builtin
    complete {fg,bg,stop}	c/%/j/ p/1/"(%)"//

    complete limit	c/-/"(h)"/ n/*/l/
    complete unlimit	c/-/"(h)"/ n/*/l/

    complete -co*	p/0/"(compress)"/	# make compress completion
						# not ambiguous
    complete zcat	n/*/f:*.Z/
    complete nm		n/*/f:^*.{h,C,c,cc}/

    complete finger	c/*@/\$hosts/ n/*/u/@ 
    complete ping	p/1/\$hosts/
    complete traceroute	p/1/\$hosts/

    complete {talk,ntalk,phone}	p/1/'`users | tr " " "\012" | uniq`'/ \
		n/*/\`who\ \|\ grep\ \$:1\ \|\ awk\ \'\{\ print\ \$2\ \}\'\`/

    complete ftp	c/-/"(d i g n v)"/ n/-/\$hosts/ p/1/\$hosts/ n/*/n/

    # this one is simple...
    #complete rcp c/*:/f/ C@[./\$~]*@f@ n/*/\$hosts/:
    # From Michael Schroeder <mlschroe@immd4.informatik.uni-erlangen.de> 
    # This one will rsh to the file to fetch the list of files!
    complete rcp 'c%*@*:%`set q=$:-0;set q="$q:s/@/ /";set q="$q:s/:/ /";set q=($q " ");rsh $q[2] -l $q[1] ls -dp $q[3]\*`%' 'c%*:%`set q=$:-0;set q="$q:s/:/ /";set q=($q " ");rsh $q[1] ls -dp $q[2]\*`%' 'c%*@%$hosts%:' 'C@[./$~]*@f@'  'n/*/$hosts/:'

    complete dd c/--/"(help version)"/ c/[io]f=/f/ \
		c/conv=*,/"(ascii ebcdic ibm block unblock \
			    lcase ucase swab noerror sync)"/,\
		c/conv=/"(ascii ebcdic ibm block unblock \
			  lcase ucase swab noerror sync)"/,\
	        c/*=/x:'<number>'/ \
		n/*/"(if of conv ibs obs bs cbs files skip file seek count)"/=

    complete nslookup   p/1/x:'<host>'/ p/2/\$hosts/

    complete ar c/[dmpqrtx]/"(c l o u v a b i)"/ p/1/"(d m p q r t x)"// \
		p/2/f:*.a/ p/*/f:*.o/

    complete {refile,sprev,snext,scan,pick,rmm,inc,folder,show} \
		c@+@F:$HOME/Mail/@

    # these and interrupt handling from Jaap Vermeulen <jaap@sequent.com>
    complete {rexec,rxexec,rxterm,rmterm} \
			'p/1/$hosts/' 'c/-/(l L E)/' 'n/-l/u/' 'n/-L/f/' \
			'n/-E/e/' 'n/*/c/'
    complete kill	'c/-/S/' 'c/%/j/' \
			'n/*/`ps -u $LOGNAME | awk '"'"'{print $1}'"'"'`/'

    # these from Marc Horowitz <marc@cam.ov.com>
    complete attach 'n/-mountpoint/d/' 'n/-m/d/' 'n/-type/(afs nfs rvd ufs)/' \
		    'n/-t/(afs nfs rvd ufs)/' 'n/-user/u/' 'n/-U/u/' \
		    'c/-/(verbose quiet force printpath lookup debug map \
			  nomap remap zephyr nozephyr readonly write \
			  mountpoint noexplicit explicit type mountoptions \
			  nosetuid setuid override skipfsck lock user host)/' \
		    'n/-e/f/' 'n/*/()/'
    complete hesinfo	'p/1/u/' \
			'p/2/(passwd group uid grplist pcap pobox cluster \
			      filsys sloc service)/'

    # these from E. Jay Berkenbilt <ejb@ERA.COM>
    complete ./configure 'c/--*=/f/' 'c/--{cache-file,prefix,srcdir}/(=)//' \
			 'c/--/(cache-file verbose prefix srcdir)//'
    complete gs 'c/-sDEVICE=/(x11 cdjmono cdj550 epson eps9high epsonc \
			      dfaxhigh dfaxlow laserjet ljet4 sparc pbm \
			      pbmraw pgm pgmraw ppm ppmraw bit)/' \
		'c/-sOutputFile=/f/' 'c/-s/(DEVICE OutputFile)/=' \
		'c/-d/(NODISPLAY NOPLATFONTS NOPAUSE)/' 'n/*/f/'
    complete perl	'n/-S/c/'
    complete printenv	'n/*/e/'
    complete sccs	p/1/"(admin cdc check clean comb deledit delget \
			delta diffs edit enter fix get help info \
			print prs prt rmdel sccsdiff tell unedit \
			unget val what)"/
    complete setenv	'p/1/e/' 'c/*:/f/'

    # these and method of setting hosts from Kimmo Suominen <kim@tac.nyc.ny.us>
    if ( -f $HOME/.mh_profile && -x "`which folders`" ) then 

    if ( ! $?FOLDERS ) setenv FOLDERS "`folders -fast -recurse`"
    if ( ! $?MHA )     setenv MHA     "`ali | sed -e '/^ /d' -e 's/:.*//'`"

    set folders = ( $FOLDERS )
    set mha = ( $MHA )

    complete ali \
        'c/-/(alias nolist list nonormalize normalize nouser user help)/' \
        'n,-alias,f,'

    complete anno \
        'c/-/(component noinplace inplace nodate date text help)/' \
        'c,+,$folders,'  \
        'n,*,`(mark | sed "s/:.*//";echo next cur prev first last)|tr " " "\12" | sort -u`,'

    complete burst \
        'c/-/(noinplace inplace noquiet quiet noverbose verbose help)/' \
        'c,+,$folders,'  \
        'n,*,`(mark | sed "s/:.*//";echo next cur prev first last)|tr " " "\12" | sort -u`,'

    complete comp \
        'c/-/(draftfolder draftmessage nodraftfolder editor noedit file form nouse use whatnowproc nowhatnowproc help)/' \
        'c,+,$folders,'  \
        'n,-whatnowproc,c,'  \
        'n,-file,f,'\
        'n,-form,f,'\
        'n,*,`(mark | sed "s/:.*//";echo next cur prev first last)|tr " " "\12" | sort -u`,'

    complete dist \
        'c/-/(noannotate annotate draftfolder draftmessage nodraftfolder editor noedit form noinplace inplace whatnowproc nowhatnowproc help)/' \
        'c,+,$folders,'  \
        'n,-whatnowproc,c,'  \
        'n,-form,f,'\
        'n,*,`(mark | sed "s/:.*//";echo next cur prev first last)|tr " " "\12" | sort -u`,'

    complete folder \
        'c/-/(all nofast fast noheader header nopack pack noverbose verbose norecurse recurse nototal total noprint print nolist list push pop help)/' \
        'c,+,$folders,'  \
        'n,*,`(mark | sed "s/:.*//";echo next cur prev first last)|tr " " "\12" | sort -u`,'

    complete folders \
        'c/-/(all nofast fast noheader header nopack pack noverbose verbose norecurse recurse nototal total noprint print nolist list push pop help)/' \
        'c,+,$folders,'  \
        'n,*,`(mark | sed "s/:.*//";echo next cur prev first last)|tr " " "\12" | sort -u`,'

    complete forw \
        'c/-/(noannotate annotate draftfolder draftmessage nodraftfolder editor noedit filter form noformat format noinplace inplace digest issue volume whatnowproc nowhatnowproc help)/' \
        'c,+,$folders,'  \
        'n,-whatnowproc,c,'  \
        'n,-filter,f,'\
        'n,-form,f,'\
        'n,*,`(mark | sed "s/:.*//";echo next cur prev first last)|tr " " "\12" | sort -u`,'

    complete inc \
        'c/-/(audit file noaudit nochangecur changecur file form format nosilent silent notruncate truncate width help)/' \
        'c,+,$folders,'  \
        'n,-audit,f,'\
        'n,-form,f,'

    complete mark \
        'c/-/(add delete list sequence nopublic public nozero zero help)/' \
        'c,+,$folders,'  \
        'n,*,`(mark | sed "s/:.*//";echo next cur prev first last)|tr " " "\12" | sort -u`,'

    complete mhmail \
        'c/-/(body cc from subject help)/' \
        'n,-cc,$mha,'  \
        'n,-from,$mha,'  \
        'n/*/$mha/'

    complete mhpath \
        'c/-/(help)/' \
        'c,+,$folders,'  \
        'n,*,`(mark | sed "s/:.*//";echo next cur prev first last)|tr " " "\12" | sort -u`,'

    complete msgchk \
        'c/-/(nodate date nonotify notify help)/' 

    complete msh \
        'c/-/(prompt noscan scan notopcur topcur help)/' 

    complete next \
        'c/-/(draft form moreproc nomoreproc length width showproc noshowproc header noheader help)/' \
        'c,+,$folders,'  \
        'n,-moreproc,c,'  \
        'n,-showproc,c,'  \
        'n,-form,f,'

    complete packf \
        'c/-/(file help)/' \
        'c,+,$folders,'  \
        'n,*,`(mark | sed "s/:.*//";echo next cur prev first last)|tr " " "\12" | sort -u`,'

    complete pick \
        'c/-/(and or not lbrace rbrace cc date from search subject to othercomponent after before datefield sequence nopublic public nozero zero nolist list help)/' \
        'c,+,$folders,'  \
        'n,*,`(mark | sed "s/:.*//";echo next cur prev first last)|tr " " "\12" | sort -u`,'

    complete prev \
        'c/-/(draft form moreproc nomoreproc length width showproc noshowproc header noheader help)/' \
        'c,+,$folders,'  \
        'n,-moreproc,c,'  \
        'n,-showproc,c,'  \
        'n,-form,f,'

    complete prompter \
        'c/-/(erase kill noprepend prepend norapid rapid nodoteof doteof help)/' 

    complete refile \
        'c/-/(draft nolink link nopreserve preserve src file help)/' \
        'c,+,$folders,'  \
        'n,-file,f,'\
        'n,*,`(mark | sed "s/:.*//";echo next cur prev first last)|tr " " "\12" | sort -u`,'

    complete rmf \
        'c/-/(nointeractive interactive help)/' \
        'c,+,$folders,'  

    complete rmm \
        'c/-/(help)/' \
        'c,+,$folders,'  \
        'n,*,`(mark | sed "s/:.*//";echo next cur prev first last)|tr " " "\12" | sort -u`,'

    complete scan \
        'c/-/(noclear clear form format noheader header width noreverse reverse file help)/' \
        'c,+,$folders,'  \
        'n,-form,f,'\
        'n,-file,f,'\
        'n,*,`(mark | sed "s/:.*//";echo next cur prev first last)|tr " " "\12" | sort -u`,'

    complete send \
        'c/-/(alias draft draftfolder draftmessage nodraftfolder filter nofilter noformat format noforward forward nomsgid msgid nopush push noverbose verbose nowatch watch width help)/' \
        'n,-alias,f,'\
        'n,-filter,f,'

    complete show \
        'c/-/(draft form moreproc nomoreproc length width showproc noshowproc header noheader help)/' \
        'c,+,$folders,'  \
        'n,-moreproc,c,'  \
        'n,-showproc,c,'  \
        'n,-form,f,'\
        'n,*,`(mark | sed "s/:.*//";echo next cur prev first last)|tr " " "\12" | sort -u`,'

    complete sortm \
        'c/-/(datefield textfield notextfield limit nolimit noverbose verbose help)/' \
        'c,+,$folders,'  \
        'n,*,`(mark | sed "s/:.*//";echo next cur prev first last)|tr " " "\12" | sort -u`,'

    complete vmh \
        'c/-/(prompt vmhproc novmhproc help)/' \
        'n,-vmhproc,c,'  

    complete whatnow \
        'c/-/(draftfolder draftmessage nodraftfolder editor noedit prompt help)/' 

    complete whom \
        'c/-/(alias nocheck check draft draftfolder draftmessage nodraftfolder help)/' \
        'n,-alias,f,'

    complete plum \
        'c/-/()/' \
        'c,+,$folders,'  \
        'n,*,`(mark | sed "s/:.*//";echo next cur prev first last)|tr " " "\12" | sort -u`,'

    complete mail \
        'c/-/()/' \
        'n/*/$mha/'

    endif

    # these from Tom Warzeka <waz@quahog.npt.nuwc.navy.mil>
    # you may need to set the following variables for your host
    set _elispdir = /usr/local/share/emacs/20.2/lisp # GNU Emacs lisp directory
    set _maildir = /var/spool/mail  # Post Office: /var/spool/mail or /usr/mail
    set _ypdir  = /var/yp	# directory where NIS (YP) maps are kept
    set _domain = "`domainname`"

    # this one works but is slow and doesn't descend into subdirectories
    # complete	cd	C@[./\$~]*@d@ \
    #			p@1@'`\ls -1F . $cdpath | grep /\$ | sort -u`'@ n@*@n@

    if ( -r /etc/shells ) then
        complete setenv	p@1@e@ n@DISPLAY@\$hosts@: n@SHELL@'`cat /etc/shells`'@
    else
	complete setenv	p@1@e@ n@DISPLAY@\$hosts@:
    endif
    complete unsetenv	n/*/e/

    if (-r $HOME/.mailrc) then
        complete mail	c/-/"(e i f n s u v)"/ c/*@/\$hosts/ \
			c@+@F:$HOME/Mail@ C@[./\$~]@f@ n/-s/x:'<subject>'/ \
			n@-u@T:$_maildir@ n/-f/f/ \
			n@*@'`sed -n s/alias//p $HOME/.mailrc | tr -s " " "	" | cut -f 2`'@
    else
        complete mail	c/-/"(e i f n s u v)"/ c/*@/\$hosts/ \
			c@+@F:$HOME/Mail@ C@[./\$~]@f@ n/-s/x:'<subject>'/ \
			n@-u@T:$_maildir@ n/-f/f/ n/*/u/
    endif

    complete man	    n@1@'`\ls -1 /usr/man/man1 | sed s%\\.1.\*\$%%`'@ \
			    n@2@'`\ls -1 /usr/man/man2 | sed s%\\.2.\*\$%%`'@ \
			    n@3@'`\ls -1 /usr/man/man3 | sed s%\\.3.\*\$%%`'@ \
			    n@4@'`\ls -1 /usr/man/man4 | sed s%\\.4.\*\$%%`'@ \
			    n@5@'`\ls -1 /usr/man/man5 | sed s%\\.5.\*\$%%`'@ \
			    n@6@'`\ls -1 /usr/man/man6 | sed s%\\.6.\*\$%%`'@ \
			    n@7@'`\ls -1 /usr/man/man7 | sed s%\\.7.\*\$%%`'@ \
			    n@8@'`\ls -1 /usr/man/man8 | sed s%\\.8.\*\$%%`'@ \
    n@9@'`[ -r /usr/man/man9 ] && \ls -1 /usr/man/man9 | sed s%\\.9.\*\$%%`'@ \
    n@0@'`[ -r /usr/man/man0 ] && \ls -1 /usr/man/man0 | sed s%\\.0.\*\$%%`'@ \
  n@new@'`[ -r /usr/man/mann ] && \ls -1 /usr/man/mann | sed s%\\.n.\*\$%%`'@ \
  n@old@'`[ -r /usr/man/mano ] && \ls -1 /usr/man/mano | sed s%\\.o.\*\$%%`'@ \
n@local@'`[ -r /usr/man/manl ] && \ls -1 /usr/man/manl | sed s%\\.l.\*\$%%`'@ \
n@public@'`[ -r /usr/man/manp ]&& \ls -1 /usr/man/manp | sed s%\\.p.\*\$%%`'@ \
		c/-/"(- f k P s t)"/ n/-f/c/ n/-k/x:'<keyword>'/ n/-P/d/ \
		N@-P@'`\ls -1 $:-1/man? | sed s%\\..\*\$%%`'@ n/*/c/

    complete ps	        c/-t/x:'<tty>'/ c/-/"(a c C e g k l S t u v w x)"/ \
			n/-k/x:'<kernel>'/ N/-k/x:'<core_file>'/ n/*/x:'<PID>'/
    complete compress	c/-/"(c f v b)"/ n/-b/x:'<max_bits>'/ n/*/f:^*.Z/
    complete uncompress	c/-/"(c f v)"/                        n/*/f:*.Z/

    complete xhost	c/[+-]/\$hosts/ n/*/\$hosts/

    # these conform to the latest GNU versions available at press time ...

    complete emacs	c/-/"(batch d f funcall i insert kill l load \
			no-init-file nw q t u user)"/ c/+/x:'<line_number>'/ \
			n/-d/x:'<display>'/ n/-f/x:'<lisp_function>'/ n/-i/f/ \
			n@-l@F:$_elispdir@ n/-t/x:'<terminal>'/ \
			n/-u/u/ n/*/f:^*[\#~]/

    complete gzcat	c/--/"(force help license quiet version)"/ \
			c/-/"(f h L q V -)"/ n/*/f:*.{gz,Z,z,zip}/
    complete gzip	c/--/"(stdout to-stdout decompress uncompress \
			force help list license no-name quiet recurse \
			suffix test verbose version fast best)"/ \
			c/-/"(c d f h l L n q r S t v V 1 2 3 4 5 6 7 8 9 -)"/\
			n/{-S,--suffix}/x:'<file_name_suffix>'/ \
			n/{-d,--{de,un}compress}/f:*.{gz,Z,z,zip,taz,tgz}/ \
			N/{-d,--{de,un}compress}/f:*.{gz,Z,z,zip,taz,tgz}/ \
			n/*/f:^*.{gz,Z,z,zip,taz,tgz}/
    complete {gunzip,ungzip} c/--/"(stdout to-stdout force help list license \
			no-name quiet recurse suffix test verbose version)"/ \
			c/-/"(c f h l L n q r S t v V -)"/ \
			n/{-S,--suffix}/x:'<file_name_suffix>'/ \
			n/*/f:*.{gz,Z,z,zip,taz,tgz}/
    complete zgrep	c/-*A/x:'<#_lines_after>'/ c/-*B/x:'<#_lines_before>'/\
			c/-/"(A b B c C e f h i l n s v V w x)"/ \
			p/1/x:'<limited_regular_expression>'/ N/-*e/f/ \
			n/-*e/x:'<limited_regular_expression>'/ n/-*f/f/ n/*/f/
    complete zegrep	c/-*A/x:'<#_lines_after>'/ c/-*B/x:'<#_lines_before>'/\
			c/-/"(A b B c C e f h i l n s v V w x)"/ \
			p/1/x:'<full_regular_expression>'/ N/-*e/f/ \
			n/-*e/x:'<full_regular_expression>'/ n/-*f/f/ n/*/f/
    complete zfgrep	c/-*A/x:'<#_lines_after>'/ c/-*B/x:'<#_lines_before>'/\
			c/-/"(A b B c C e f h i l n s v V w x)"/ \
			p/1/x:'<fixed_string>'/ N/-*e/f/ \
			n/-*e/x:'<fixed_string>'/ n/-*f/f/ n/*/f/
    complete znew	c/-/"(f t v 9 P K)"/ n/*/f:*.Z/
    complete zmore	n/*/f:*.{gz,Z,z,zip}/
    complete zfile	n/*/f:*.{gz,Z,z,zip,taz,tgz}/
    complete ztouch	n/*/f:*.{gz,Z,z,zip,taz,tgz}/
    complete zforce	n/*/f:^*.{gz,tgz}/

    complete grep	c/-*A/x:'<#_lines_after>'/ c/-*B/x:'<#_lines_before>'/\
			c/-/"(A b B c C e f h i l n s v V w x)"/ \
			p/1/x:'<limited_regular_expression>'/ N/-*e/f/ \
			n/-*e/x:'<limited_regular_expression>'/ n/-*f/f/ n/*/f/
    complete egrep	c/-*A/x:'<#_lines_after>'/ c/-*B/x:'<#_lines_before>'/\
			c/-/"(A b B c C e f h i l n s v V w x)"/ \
			p/1/x:'<full_regular_expression>'/ N/-*e/f/ \
			n/-*e/x:'<full_regular_expression>'/ n/-*f/f/ n/*/f/
    complete fgrep	c/-*A/x:'<#_lines_after>'/ c/-*B/x:'<#_lines_before>'/\
			c/-/"(A b B c C e f h i l n s v V w x)"/ \
			p/1/x:'<fixed_string>'/ N/-*e/f/ \
			n/-*e/x:'<fixed_string>'/ n/-*f/f/ n/*/f/

    complete users	c/--/"(help version)"/ p/1/x:'<accounting_file>'/
    complete who	c/--/"(heading mesg idle count help message version \
			writable)"/ c/-/"(H T w i u m q s -)"/ \
			p/1/x:'<accounting_file>'/ n/am/"(i)"/ n/are/"(you)"/

    complete chown	c/--/"(changes silent quiet verbose recursive help \
			version)"/ c/-/"(c f v R -)"/ C@[./\$~]@f@ c/*[.:]/g/ \
			n/-/u/. p/1/u/. n/*/f/
    complete chgrp	c/--/"(changes silent quiet verbose recursive help \
			version)"/ c/-/"(c f v R -)"/ n/-/g/ p/1/g/ n/*/f/

    complete cat	c/--/"(number-nonblank number squeeze-blank show-all \
			show-nonprinting show-ends show-tabs help version)"/ \
			c/-/"(b e n s t u v A E T -)"/ n/*/f/
    complete mv		c/--/"(backup force interactive update verbose suffix \
			version-control help version)"/ \
			c/-/"(b f i u v S V -)"/ \
			n/{-S,--suffix}/x:'<suffix>'/ \
			n/{-V,--version-control}/"(t numbered nil existing \
			never simple)"/ n/-/f/ N/-/d/ p/1/f/ p/2/d/ n/*/f/
    complete cp		c/--/"(archive backup no-dereference force interactive \
			link preserve symbolic-link update verbose parents \
			one-file-system recursive suffix version-control help \
			version)"/ c/-/"(a b d f i l p r s u v x P R S V -)"/ \
			n/-*r/d/ n/{-S,--suffix}/x:'<suffix>'/ \
			n/{-V,--version-control}/"(t numbered nil existing \
			never simple)"/ n/-/f/ N/-/d/ p/1/f/ p/2/d/ n/*/f/
    complete ln		c/--/"(backup directory force interactive symbolic \
			verbose suffix version-control help version)"/ \
			c/-/"(b d F f i s v S V -)"/ \
			n/{-S,--suffix}/x:'<suffix>'/ \
			n/{-V,--version-control}/"(t numbered nil existing \
			never simple)"/ n/-/f/ N/-/x:'<link_name>'/ \
			p/1/f/ p/2/x:'<link_name>'/
    complete touch	c/--/"(date file help time version)"/ \
			c/-/"(a c d f m r t -)"/ \
			n/{-d,--date}/x:'<date_string>'/ \
			c/--time/"(access atime mtime modify use)"/ \
			n/{-r,--file}/f/ n/-t/x:'<time_stamp>'/ n/*/f/
    complete mkdir	c/--/"(parents help version mode)"/ c/-/"(p m -)"/ \
			n/{-m,--mode}/x:'<mode>'/ n/*/d/
    complete rmdir	c/--/"(parents help version)"/ c/-/"(p -)"/ n/*/d/

    complete tar	c/-[Acru]*/"(b B C f F g G h i l L M N o P \
			R S T v V w W X z Z)"/ \
			c/-[dtx]*/"( B C f F g G i k K m M O p P \
			R s S T v w x X z Z)"/ \
			p/1/"(A c d r t u x -A -c -d -r -t -u -x \
			--catenate --concatenate --create --diff --compare \
			--delete --append --list --update --extract --get \
			--help --version)"/ \
			c/--/"(catenate concatenate create diff compare \
			delete append list update extract get atime-preserve \
			block-size read-full-blocks directory checkpoint file \
			force-local info-script new-volume-script incremental \
			listed-incremental dereference ignore-zeros \
			ignore-failed-read keep-old-files starting-file \
			one-file-system tape-length modification-time \
			multi-volume after-date newer old-archive portability \
			to-stdout same-permissions preserve-permissions \
			absolute-paths preserve record-number remove-files \
			same-order preserve-order same-owner sparse \
			files-from null totals verbose label version \
			interactive confirmation verify exclude exclude-from \
			compress uncompress gzip ungzip use-compress-program \
			block-compress help version)"/ \
			c/-/"(b B C f F g G h i k K l L m M N o O p P R s S \
			T v V w W X z Z 0 1 2 3 4 5 6 7 -)"/ \
			n/-c*f/x:'<new_tar_file, device_file, or "-">'/ \
			n/{-[Adrtux]*f,--file}/f:*.tar/ \
			N/{-x*f,--file}/'`tar -tf $:-1`'/ \
			n/--use-compress-program/c/ \
			n/{-b,--block-size}/x:'<block_size>'/ \
			n/{-V,--label}/x:'<volume_label>'/ \
			n/{-N,--{after-date,newer}}/x:'<date>'/ \
			n/{-L,--tape-length}/x:'<tape_length_in_kB>'/ \
			n/{-C,--directory}/d/ \
			N/{-C,--directory}/'`\ls $:-1`'/ \
			n/-[0-7]/"(l m h)"/

    # SVR4 filesystems
    #complete  mount	c/-/"(a F m o O p r v V)"/ n/-p/n/ n/-v/n/ \
    #			n/-o/x:'<FSType_options>'/ \
    #			n@-F@'`\ls -1 /usr/lib/fs`'@ \
    #			n@*@'`grep -v "^#" /etc/vfstab | tr -s " " "	 " | cut -f 3`'@
    #complete umount	c/-/"(a o V)"/ n/-o/x:'<FSType_options>'/ \
    #			n/*/'`mount | cut -d " " -f 1`'/
    #complete  mountall	c/-/"(F l r)"/ n@-F@'`\ls -1 /usr/lib/fs`'@
    #complete umountall	c/-/"(F h k l r s)"/ n@-F@'`\ls -1 /usr/lib/fs`'@ \
    #			n/-h/'`df -k | cut -s -d ":" -f 1 | sort -u`'/
    # BSD 4.3 filesystems
    complete  mount	c/-/"(a r t v)"/ n/-t/"(4.2 nfs)"/ \
			n@*@'`grep -v "^#" /etc/fstab | tr -s " " "	" | cut -f 2`'@
    complete umount	c/-/"(a h t v)"/ n/-t/"(4.2 nfs)"/ \
			n/-h/'`df | cut -s -d ":" -f 1 | sort -u`'/ \
			n/*/'`mount | cut -d " " -f 3`'/
    # BSD 4.2 filesystems
    #complete  mount	c/-/"(a r t v)"/ n/-t/"(ufs nfs)"/ \
    #			n@*@'`cut -d ":" -f 2 /etc/fstab`'@
    #complete umount	c/-/"(a h t v)"/ n/-t/"(ufs nfs)"/ \
    #			n/-h/'`df | cut -s -d ":" -f 1 | sort -u`'/ \
    #			n/*/'`mount | cut -d " " -f 3`'/

    # these deal with NIS (formerly YP); if it's not running you don't need 'em
    complete domainname	p@1@D:$_ypdir@" " n@*@n@
    complete ypcat	c@-@"(d k t x)"@ n@-x@n@ n@-d@D:$_ypdir@" " \
	    N@-d@\`\\ls\ -1\ $_ypdir/\$:-1\ \|\ sed\ -n\ s%\\\\.pag\\\$%%p\`@ \
	  n@*@\`\\ls\ -1\ $_ypdir/$_domain\ \|\ sed\ -n\ s%\\\\.pag\\\$%%p\`@
    complete ypmatch	c@-@"(d k t x)"@ n@-x@n@ n@-d@D:$_ypdir@" " \
	            N@-d@x:'<key ...>'@ n@-@x:'<key ...>'@ p@1@x:'<key ...>'@ \
	  n@*@\`\\ls\ -1\ $_ypdir/$_domain\ \|\ sed\ -n\ s%\\\\.pag\\\$%%p\`@
    complete ypwhich	c@-@"(d m t x V1 V2)"@ n@-x@n@ n@-d@D:$_ypdir@" " \
	 n@-m@\`\\ls\ -1\ $_ypdir/$_domain\ \|\ sed\ -n\ s%\\\\.pag\\\$%%p\`@ \
			N@-m@n@ n@*@\$hosts@

    # there's no need to clutter the user's shell with these
    unset _elispdir _maildir _ypdir _domain

    complete make \
	'n/-f/f/' \
      	'c/*=/f/' \
	'n@*@`cat -s GNUmakefile Makefile makefile |& sed -n -e "/No such file/d" -e "/^[^     #].*:/s/:.*//p"`@'

    if ( -f /etc/printcap ) then
	set printers=(`sed -n -e "/^[^     #].*:/s/:.*//p" /etc/printcap`)

	complete lpr    'c/-P/$printers/'
	complete lpq    'c/-P/$printers/'
	complete lprm   'c/-P/$printers/'
	complete lpquota        'p/1/(-Qprlogger)/' 'c/-P/$printers/'
	complete dvips  'c/-P/$printers/' 'n/-o/f:*.{ps,PS}/' 'n/*/f:*.dvi/'
    endif

    unset noglob
    unset complete
endif

end:
	onintr
