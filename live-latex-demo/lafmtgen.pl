#! /bin/sh
eval '(exit $?0)' && eval 'PERL_BADLANG=x;PATH="$PATH:.";export PERL_BADLANG\
;exec perl -x -S -- "$0" ${1+"$@"};#'if 0;eval 'setenv PERL_BADLANG x\
;setenv PATH "$PATH":.;exec perl -x -S -- "$0" $argv:q;#'.q
#!perl -w
+push@INC,'.';$0=~/(.*)/s;do(index($1,"/")<0?"./$1":$1);die$@if$@__END__+if 0
;#Don't touch/remove lines 1--7: http://www.inf.bme.hu/~pts/Magic.Perl.Header
#
# lafmtgen. pl -- generates latex.fmt and pdflatex.fmt on the fly
# by pts@fazekas.hu at Tue Dec 30 16:46:50 CET 2003
# -- Thu May 13 11:33:29 CEST 2004
#
# Imp: install >2 *.fmt
# 
BEGIN { eval { require integer } and import integer }
BEGIN { eval { require strict  } and import strict  }  # go on if missing

my $SELF=[$0=~m@[^/]*\Z(?!\n)@g]->[0];

#** @return $_[0] quoted for /bin/sh
sub shq($) {
  my $S=$_[0];
  return $S if $S!~y@A-Za-z0-9_,:./-@@c and length($S)>0;
  $S=~s@'@'\\''@g;
  return "'$S'"
}

my $check_latex='latex';
my $check_fmt='latex.fmt';

#** @param $_[0] a .tex filename
#** @return arrayref of lang
sub get_babel_langs($) {
  my $qfn=shq($_[0]);
  my $latex=$_[1];
  my $extra=q~'\makeatletter
\let\@OFWO\@onefilewithoptions
\def\@onefilewithoptions#1[#2][#3]#4{\typeout{--\string\usepackage[#2]{#1}}\@OFWO{#1}[#2][#3]{#4}}
\let\document\@@end
\input'~;
  $extra=~y@\n@ @;
  my @rename;
  if (!-f $check_fmt) {
  } elsif (rename $check_fmt, "$check_fmt.lafmtgen") {
    # Dat: rename so a local .fmt file doesn't cause confusion
    push @rename, "$check_fmt.lafmtgen", "$check_fmt";
  } else {
    print STDERR "$SELF: warning: cannot rename $check_fmt\n";
  }
  # vvv Dat: no $latex; fine
  my $ret=qx($check_latex $extra $qfn </dev/null 2>&1);
  $ret=~s@^(.{79})\n@$1@mg; # remove extra line breaks
  if (@rename and !rename $rename[0], $rename[1]) {
    print STDERR "$SELF: warning: cannot rename back $check_fmt\n";
  }
  die "$SELF: babel test of LaTeX ($check_latex $qfn) failed -- do you have a good $check_latex on \$PATH?\n" unless $ret=~/^This is (?:pdf)?TeXk?\b/i and $ret=~/^LaTeX/m;
  die "$SELF: got output pages\n" unless $ret=~/^No pages of output[.]$/m;
  my @languages;
  my @deflangs;
  if ($ret=~/^--\\usepackage\[,*([^\]]*?),*\]\{babel\}$/m) {
    my %H=qw(activeacute 1 activegrave 1 KeepShorthandsActive 1);
    push @languages, grep {not exists $H{$_}} split/,+/, $1;
  } elsif ($ret=~/^! I can't find file /m) {
    die "$SELF: LaTeX cannot find file: $_[0]\n";
  } elsif ($ret=~/^! Patterns can be loaded only by INITEX[.]$/m) { # lafmtgen.pl huhyph.tex
    my $S=$_[0]; $S.=".tex" if $S!~m@[.][^./]+@; $S=~s@\A.*/@@s;
    # ^^^ Imp: remember directory
    push @languages, "hypfile:$S";
  } else {
    # Dat: this line is not part of the .log file
    #push @languages, $1 if $ret=~/^Babel .* (\w+), loaded[.]/m;
    # ^^^ Get the last language. This is incorrect, because \language0 will
    #     be the _first_ language (usually `american').
    push @deflangs, $1 if $ret=~/^Babel .*? and hyphenation patterns for (\w+),(.*) loaded[.]/m;
    #print "C ($1) ($ret)\n";
    # Usually `nohyphenation'.
  }
  ##die @languages;
  #die $ret;
  while ($ret=~/^--:hyphenation(-?)=(\S*)/gm) { # emitted by magyar.ldf 1.5
    if (length $1) {
      my $I=@languages;
      $I-- while $I!=0 && $languages[$I-1] ne $2;
      splice @languages, $I-1, 1 if $I!=0;
    } else { push @languages, $2; }
  }
  if (!@languages and @deflangs) {
    print STDERR "$SELF: warning: using default languages: @deflangs\n";
    push @languages, @deflangs;
  }
  die "$SELF: no used languages found\n" if !@languages;
  \@languages
}

#** @param $_[0] filename
#** @param $_[1] extra args to kpsewhich
#** @return real filename or ""
sub kpsewhich($$) {
  return $_[0] if -f $_[0]; # kpsewhich(1) also does this for rel. and abs.
  return "" if substr($_[0],0,1)eq'/'; # absolute filename missing
  my $s=shq($_[0]);
  $s=qx(kpsewhich $_[1] -- $s); # Dat: don't do 2>/dev/null
  chomp$s;
  $s
}

#** @param $_[0] arrayref of languages that _must_ be present
#** @param $_[1] destination 'language.dat' filename
#** @param $_[2] undef or directory name to copy *.hyp and *hyph.tex to
#** @param $_[3] arrayref of language.dat filenames
#** @return ($hypfns,$hyplangs): (arrayref of .hyp filenames copied, ...)
sub make_language_dat($$$$$) {
  my $printed="% language.dat generated by lafmtgen.pl at ".scalar(localtime)."\n\n";
  my ($langs,$outld,$outdir,$lds,$include_all_p)=@_;
  my %missing=map{$_=>1}@$langs;
  my %copyhyp; # 'huhyph.tex'=>'magyar' etc.
  my $hypfns=[];
  my $hyplangs=[];
  # Sample language.dat:
  #   american ushyph1.tex
  #   =USenglish
  #   =english
  #** Name of file containing hyphenation patterns for the previous language
  my $prevhyp;
  my $prevhypprn="";
  my $lang;
  my %redef;
  my @comms;
  my %had_ldfns;
  for my $ld (@$lds) {
    my $ldfn=kpsewhich($ld,'--must-exist');
    if (0==length $ldfn) {
      print STDERR "$SELF: warning: missing ldfn: $ldfn\n";
      next
    }
    if (exists $had_ldfns{$ldfn}) {
      print STDERR "$SELF: warning: ignoring duplicate ldfn: $ldfn\n";
      next
    }
    $had_ldfns{$ldfn}=1;
    die "$SELF: .dat missing: $ld: $!\n" if !open LD, "< $ldfn";
    while (<LD>) {
      if (/^\s*=\s*(\S+)\s*$/) {
	if (!defined $prevhyp) { print STDERR "$SELF: warning: no prev lang, ignoring =$1\n"; next }
	$lang=$1;
      } elsif (/^\s*([^\s%]+)\s*([^\s%]+)\s*$/) {
	$lang=$1; $prevhyp=$2;
      } elsif (/^\s*\%\s*(\w+)\s*(\S+)\s*$/) { # an entry commented out
	push @comms, $1, $2; next
      } elsif (1+s@%.*@@ and /\S/) {
	print STDERR "$SELF: warning: syntax error in language.dat ($.)\n"; next
      } else { next }
      if (exists $redef{$lang}) {
        print STDERR "$SELF: warning: not redefining $lang to $prevhyp\n";
        next
      }
      $redef{$lang}=1;
      if ($include_all_p or exists $missing{$lang} or exists $missing{"hypfile:$prevhyp"}) {
	delete $missing{$lang};
	delete $missing{"hypfile:$prevhyp"};
	$printed.=$prevhyp eq $prevhypprn ? "=$lang\n" : "$lang $prevhyp\n";
	$copyhyp{$prevhyp}=$lang; push @$hyplangs, $lang;
	# ^^^ Dat: save pattern memory with "=$lang\n"
	$prevhypprn=$prevhyp;
      }
    }
    die unless close LD;
  }
  for (my $I=0;$I<@comms;) {
    $lang=$comms[$I++]; $prevhyp=$comms[$I++];
    ## print STDERR "($lang)($prevhyp)\n";
    next if !exists $missing{$lang} and !exists $missing{"hypfile:$prevhyp"};
    delete $missing{"hypfile:$prevhyp"};
    delete $missing{$lang};
    $printed.=$prevhyp eq $prevhypprn ? "=$lang\n" : "$lang $prevhyp\n";
    $copyhyp{$prevhyp}=$lang; push @$hyplangs, $lang;
    $prevhypprn=$prevhyp;
  }
  my $dummy;
  while (($lang,$dummy)=each%missing) {
    $prevhyp=($lang=~m@\Amagyar(.*)@s) ? "huhyph$1.tex" :
             ($lang=~m@\Ahypfile:(.*)@s) ? $1 : "$lang.hyp";
    if ($lang=~s@\Ahypfile:huhyph(.*)[.]tex\Z(?!\n)@magyar$1@s) {}
    elsif ($lang=~/\Ahypfile:(.*)/) {
      print STDERR "$SELF: warning: don't know language, ignoring file: $1\n";
      next
    }
    if (!length(kpsewhich($prevhyp,'--must-exist'))) {
      print STDERR "$SELF: warning: don't know file of language $lang\n";
      next
    }
    print STDERR "$SELF: warning: adding language $lang in $prevhyp\n";
    $printed.=$prevhyp eq $prevhypprn ? "=$lang\n" : "$lang $prevhyp\n";
    $copyhyp{$prevhyp}=$lang; push @$hyplangs, $lang;
    $prevhypprn=$prevhyp;
  }
  # Dat: important to open LD for writing now since the old one has been read
  die "$SELF: open2write $outld: $!\n" if !open LD, "> $outld";
  die unless print LD $printed;  
  die unless close LD;
  if (defined $outdir) {
    while (($prevhyp,$lang)=each%copyhyp) {
      my $ifn=kpsewhich($prevhyp,'--must-exist');
      if (!length($ifn)) {
        print STDERR "$SELF: warning: $prevhyp: not found\n"
      } elsif (open IF, "< $ifn") {
        print STDERR "$SELF: info: copying $ifn to $outdir/$prevhyp\n";
        die "$SELF: open2write $outdir/$prevhyp: $!" if !open OF, "> $outdir/$prevhyp";
        print OF $dummy while sysread IF, $dummy, 4096;
        # Imp: handle I/O errors
        die if !close OF;
        die if !close IF;
        push @$hypfns, $prevhyp;
      } else { print STDERR "$SELF: warning: $ifn: $!\n" }
    }
  }
  ($hypfns,$hyplangs)
}

#** chdir('..') must be able to undo chdir($tmpdir)
my $tmpdir='lafmtgen.tmp';

#** @param $_[0] arrayref
#** @return ($hypfns,$hyplangs)
sub gen_language_dat($) {
  my $fns=$_[0];
  my $dats;
  my $lds=[];
  my $langs=[];
  for my $fn (@$fns) {
    if ($fn=~m@[.]dat\Z(?!\n)@) { push @$lds, $fn }
			   else { push @$langs, @{get_babel_langs $fn} }
  }
  mkdir $tmpdir;
  die "$SELF: couldn't create directory: $tmpdir\n" if !-d $tmpdir;
  if (@$lds) {
    make_language_dat $langs, "$tmpdir/language.dat", $tmpdir, $lds, 1
  } else {
    push @$lds, 'language.dat'; # Dat: $fn.dat has priority
    make_language_dat $langs, "$tmpdir/language.dat", $tmpdir, $lds, 0
  }
}

my $install_report="";
my $need_mktexlsr=0;
my $need_fn;
my $need_targetfn;
my $need_utf8patch=1;

sub gen_fmt($$) {
  my ($latex,$install_dir)=@_;
  my $inifn=kpsewhich("$latex.ini","--must-exist --progname $latex");
  die "$SELF: initex $latex.ini not found\n" if !-f $inifn;
  if ($need_utf8patch) {
    my $patchfn=kpsewhich("ltpatch.ltx","--must-exist");
    die "$SELF: ltpatch.ltx not found\n" if !-f $patchfn;
    # ^^^ Imp: if missing: \let\fmtversion@topatch\fmtversion  \def\patch@level{0}
    print STDERR "$SELF: info: patching $patchfn to $tmpdir/ltpatch.ltx\n";
    die "$SELF: open2read $patchfn: $!" if !open IF, "< $patchfn";
    die "$SELF: open2write $tmpdir/ltpatch.ltx: $!" if !open OF, "> $tmpdir/ltpatch.ltx";
    my $dummy;
    print OF $dummy while sysread IF, $dummy, 4096;
    die if !print OF '
% LaTeX patch by pts for automatic handling of UTF-8(-ws) input
\expandafter\everyjob\expandafter{\the\everyjob\utfEdetect}
\def\utfEdetect{\csname @ifnextchar\endcsname^^ef\utfEstart\relax}
\def\utfEstart^^ef^^bb^^bf{\RequirePackage[utf8]{inputenc}}
';
    # Imp: handle I/O errors
    die if !close OF;
    die if !close IF;
  }    
  my $initex=$latex=~/^pdf/i ? 'pdfinitex' : 'initex';
  die unless chdir $tmpdir;
  my $cmd="$initex '\\nonstopmode\\input $inifn \\dump'\n";
  close STDIN; # the only way to stop initex from reading the terminal
  unlink "$latex.log";
  print STDERR "$SELF: info: running  $cmd\n";
  while (0!=system($cmd)) {
    my $patmem;
    my $poolmem;
    my $mainmem;
    if (open LOG, "< $latex.log") { # latex.log or pdflatex.log
      while (<LOG>) {
        $patmem=$1+0 if /^! TeX capacity exceeded, sorry \[pattern memory=(\d+)\][.]/;
        $poolmem=$1+20000 if /^! TeX capacity exceeded, sorry \[pool size=(\d+)\][.]/;
        $mainmem=$1 if /^! TeX capacity exceeded, sorry \[main memory size=(\d+)\][.]/;
        $poolmem=150000/2 if /^! You have to increase POOLSIZE[.]/; # Dat: we won't get this from the log file :-(
      }
      close LOG;
    }
    die "$SELF: initex failed, see error message above, and see $tmpdir/*.log\n"
      if !defined $patmem and !defined $poolmem and !defined $mainmem;
    $patmem*=2;
    $poolmem*=2;
    print STDERR "$SELF: warning: increasing pattern memory to $patmem\n";
    $ENV{trie_size}=$patmem; # see also in texmf.cnf
    $ENV{pool_size}=$poolmem;
    $ENV{main_memory}=$mainmem;
  }
  # delete $ENV{trie_size}; # Dat: don't delete, because it might had prev. value, and it would be also good for a second run
  die "$SELF: missing $latex.fmt\n" if !lstat "$latex.fmt";
  unlink qw(texput.log latex.log pdflatex.log texsys.aux ltpatch.ltx), "$latex.log";
  print STDERR "$SELF: info: successfully generated $latex.fmt\n";
  die unless chdir '..';
  my $targetfn="$install_dir/$latex.fmt";
  die "$SELF: cannot move $latex.fmt to dir $install_dir" unless
    rename "$tmpdir/$latex.fmt", "$install_dir/$latex.fmt";
  $install_report.="$SELF: info: installed $targetfn\n";
  my $fn;
  ($need_mktexlsr,$need_fn,$need_targetfn)=(1,"$latex.fmt",$targetfn) if $install_dir=~m@/texmf/web2c/*\Z(?!\n)@ and
    (!length($fn=kpsewhich("$latex.fmt","--must-exist")) or $fn ne $targetfn)
}

sub cleanup($) {
  my $hypfns=$_[0];
  unlink map {"$tmpdir/$_"} qw(texput.log latex.log pdflatex.log language.dat texsys.aux ltpatch.ltx), @$hypfns;
  rmdir $tmpdir;
  die "$SELF: extra files in temp dir: $tmpdir\n" if lstat $tmpdir; # Imp: lstat is UNIX-specific, use stat() on Win32?
  die unless chdir '..';
}

# ---

die "This is lafmtgen.pl v0.04, by pts\@fazekas.hu in May 2004
Usage: $SELF [<option>..] { <FILENAME>[.tex] | <FILENAME.dat> ... }
Example: $SELF --install language.dat huhyph{,c,f,3,n}.tex
Options:
--latex          generate latex.fmt
--pdflatex       generate pdflatex.fmt
--both           --latex and --pdflatex (default)
--install=DIR    install .fmt files to DIR (e.g /usr/share/texmf/web2c)
--install-util   install .fmt files where fmtutil(1) would install them
--install-pfmt   install .fmt files to first component of `kpsepath fmt`
--install        --install-util if root, --install-pfmt otherwise
--install-dir=D  install .fmt to dir D. default: .
--pool-size=INT  see texmf.cnf, give value lager than 125000
--main-memory-size=INT  see texmf.cnf, give value lager than 263000
--utf8={1|0}     patch ltpatch.ltx to accept UTF-8(-ws) encoding
" if !@ARGV or $ARGV[0]eq'--help' or $ARGV[0] eq '-h';

my $install_dir='.';
my %latexs=();
{ my $I;
  for ($I=0;$I<@ARGV;$I++) {
    if ($ARGV[$I] eq '--latex') { $latexs{latex}=1 }
    elsif ($ARGV[$I] eq '--pdflatex') { $latexs{pdflatex}=1; $check_latex='pdflatex'; $check_fmt='pdflatex.fmt'; }
    elsif ($ARGV[$I] eq '--both') { $latexs{pdflatex}=$latexs{latex}=1 }
    elsif ($ARGV[$I] eq '--install') { $install_dir= $<==0 ? '//-util' : '//-pfmt' }
    elsif ($ARGV[$I] eq '--install-util') { $install_dir='//-util' }
    elsif ($ARGV[$I] eq '--install-pfmt') { $install_dir='//-pfmt' }
    elsif ($ARGV[$I]=~/\A--install=(.*)/s) { $install_dir=$1 }
    elsif ($ARGV[$I]=~/\A--pool-size=(\d+)\Z(?!\n)$/) { $ENV{pool_size}=$1 }
    elsif ($ARGV[$I]=~/\A--main-memory-size=(\d+)\Z(?!\n)$/) { $ENV{main_memory}=$1 }
    elsif ($ARGV[$I]=~/\A--utf8=(\d+)$/ and $1>=0 and $1<=1) { $need_utf8patch=$1 }
    elsif ($ARGV[$I] eq '--') { last }
    elsif (substr($ARGV[$I],0,1) eq '-') { die "$SELF: unknown option $ARGV[$I], run --help\n" }
    else { last }
  }
  splice @ARGV, 0, $I
}
$latexs{pdflatex}=$latexs{latex}=1 if !%latexs; # default

if ($install_dir eq '//-pfmt' or $install_dir eq '//-util') {
  if ($install_dir eq '//-pfmt') {
    $install_dir=qx(kpsepath fmt);
    # .:/home/guests/pts/tex/lakk/texmf/web2c:/usr/local/share/texmf/web2c:/usr/local/lib/texmf/web2c:!!/usr/share/texmf/web2c
    chomp $install_dir;
    $install_dir=~s@^(?:[.]:)+(?:!!)?@@;
    $install_dir=~s@:.*@@s;
  } else { # do exactly what fmtutil(1) does
    $install_dir=qx(kpsewhich --expand-var='\$VARTEXMF');  chomp $install_dir;
    if (0==length$install_dir or !(-d$install_dir)) {
      $install_dir=qx(kpsewhich --expand-var='\$TEXMFMAIN'); chomp $install_dir;
    }
  }
  # Dat: don't create it: mkdir $install_dir; # $install_dir usually ends by `/texmf/web2c'
  if (0==length$install_dir or !(-d$install_dir)) {
    my $fn=kpsewhich('latex.fmt','--must-exist');
    die "$SELF: kpsepath reported no dir: $install_dir\n" if 0==length($fn);
    $install_dir=$fn; $install_dir=~s@/[^/]*\Z(?!\n)@@;
    die "$SELF: not a directory: $install_dir\n" unless -d $install_dir;
  }
  die "$SELF: permission denied writing dir: $install_dir\n"
    unless -w $install_dir; # Imp: UNIX-specific
}    

my($hypfns,$hyplangs)=gen_language_dat(\@ARGV);
die "$SELF: missing .tex/.dat filename\n" if !@ARGV;
# ^^^ Dat: don't cleanup()
for my $latex (sort keys%latexs) { gen_fmt $latex, $install_dir }
print STDERR $install_report;
cleanup $hypfns;
if (@$hypfns) {
  print STDERR "$SELF: info: pattern files used: @$hypfns\n";
  print STDERR "$SELF: info: languages provided: @$hyplangs\n";
  # Dat: ordier of $hyplangs is not significant? -- \language0
  # Imp: make huhyph.tex appear earlier if needed
} else {
  print STDERR "$SELF: warning: format doesn't contain patterns!\n";
}
if ($need_mktexlsr) {
  my $dir=$install_dir; $dir=~s@/texmf/.*@/texmf@s;
  my $fn;
  print STDERR "$SELF: info: running  mktexlsr $dir\n";
  print STDERR "$SELF: warning: mktexlsr failed\n" if 0!=system 'mktexlsr', $dir;
  if (length($fn=kpsewhich($need_fn,"--must-exist")) and $fn ne $need_targetfn) {
    print STDERR "$SELF: kpsewhich cannot find new format\n"
  } else { $need_mktexlsr=0 }
}
print STDERR "$SELF: info: install OK\n" if !$need_mktexlsr and $install_dir ne'.';

__END__
