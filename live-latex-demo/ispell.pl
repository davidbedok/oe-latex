#! /bin/sh
eval '(exit $?0)' && eval 'PERL_BADLANG=x;PATH="$PATH:.";export PERL_BADLANG\
 PATH;exec perl -x -S -- "$0" ${1+"$@"};#'if 0;eval 'setenv PERL_BADLANG x\
;setenv PATH "$PATH":.;exec perl -x -S -- "$0" $argv:q;#'.q
#!perl -w
+push@INC,'.';$0=~/(.*)/s;do(index($1,"/")<0?"./$1":$1);die$@if$@__END__+if 0
;#Don't touch/remove lines 1--7: http://www.inf.bme.hu/~pts/Magic.Perl.Header
#
# ispell -- ispell + mspell (+ will be hunspell) wrapper
# by pts@fazekas.hu at Tue Dec 30 09:24:30 CET 2003
# bugfixes, Perl script at Wed Apr  7 14:31:32 CEST 2004
# hunspell works at Sun May 16 18:59:01 CEST 2004
#
# This script should be copied to /usr/local/bin/ispell .
# Call this script as `ispell -d mspell -a' to get mspell,
# `ispell -d hunspell -a' to get hunspell and
# other `ispell -d $LANGUAGE -a' to get ispell.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# Dat: Emacs calls us as -a -m -d 'magyar (mspell)' -d mspell
# Dat: see `-a' in `man ispell' for the line-oriented ispell protocol
# Dat: mspell accepts the word: asdasd
# Imp: mspell(1) emits: Word 'MASTERSTHESIS{pts_diploma,' contains illegal characters
# Dat: hunspell (best Hungarian spell checker) installation to UNIX systems:
#      -- install GNU Make, G++
#      -- download hunspell from http://hunspell.sf.net/
#         (tested with hunspell-1.2.3)
#      -- extract; ./configure; make
#      -- # cp src/tools/hunspell /usr/local/bin
#      -- # strip /usr/local/bin/hunspell
#      -- download the dictionary from http://magyarispell.sf.net/
#         (tested with http://magyarispell.sourceforge.net/hu_HU-1.0.tar.gz)
#      -- extract
#      -- copy files (hu_HU.aff and hu_HU.dic are enough)
#         # mkdir -p /usr/share/myspell
#         # cp hu_HU.aff hu_HU.dic /usr/share/myspell/
#      -- optionally copy the other *.aff and *.dic files
#      -- add /usr/local/bin to your default $PATH
#      -- try: hunspell -d hu_HU
# Dat: ispell.pl installation on Linux systems
#      -- install hunspell first (see above)
#      -- optional: install ispell and ihungarian
#      -- optional: install mspell
#      -- copy this ispell.pl to /usr/local/bin/ispell
#      -- touch /usr/lib/ispell/mspell.hash
#      -- touch /usr/lib/ispell/hunspell.hash
#      -- touch /usr/lib/ispell/magyar-best.hash
#      -- # cp ispell.pl /usr/local/bin
#      -- # chmod +x /usr/local/bin/ispell
#      -- prepend /usr/local/bin to your $PATH
#      -- run ispell --list
#      -- if it prints `BAD:', resolve the problem
#      -- append pts-emacs.el to your .emacs
#      -- restart Emacs
#      -- Meta-<X> pts-spell-hu
#      -- start spellchecking the buffer with Meta-<X> pts-flyspell-mode
#      -- use the menu: Tools / Spell checking / Select ... Dict
#         to change the dictionary
#      -- the ispell-* commands continue to work
#

BEGIN { eval { require integer } and import integer }
BEGIN { eval { require strict  } and import strict  } # go on if missing

sub fnq($) {
  #return $_[0] if substr($_[0],0,1)ne'-'
  return $_[0] if $_[0]!~m@[^-_/.0-9a-zA-Z]@;
  my $S=$_[0];
  $S=~s@'@'\\''@g;
  "'$S'"
}


#die unless open A, "> /tmp/aaa";
#die unless print A "(".join(':',@ARGV),")\n";
#die unless close A;

sub dumpq($) {
  my $S=$_[0];
  $S=~s@(["\\])|([^ -~])@
    defined $2 ? sprintf("\\x%02X",ord($2)) # Imp: Unicode chars
               : "\\$1" # Imp: Unicode chars
  @ge;
  "\"$S\""
}

my $fake_ispell_libdir='/usr/lib/ispell';

my $opt_log=0;

#** Read from STDIN, report the line "word\n" as a spelling error, otherwise
#** start real spell checker
#** @param $_[0] arrayref args to real spell checker
#** @param $_[1] mode
#**   0: normal exec()
#**   1: for vim_verify
#**   2: run ispell through pipe
#**   3: emulate terse mode for hunspell
#**   4: emulate missing mspell commands
sub do_spell($$) {
  my $ARGV=$_[0];
  my $mode=$_[1];
  $mode=2 if $mode==0 and $opt_log;
  die "$0: spell checker command not found\n" if !defined $ARGV->[0];
  if ($mode==0) {
    die "$0: $ARGV->[0]: cannot exec: $!\n" if !exec @$ARGV;
  } elsif ($mode==1) {
    # Dat: SUXX: `mspell -l' prints `@(#) Inter...' header too late, but never mind
    print while <STDIN>; # report all words, especially `word' as incorrect
    exit 0;
    # vvv SUXX: will ignore very first word
    #my $S;
    #select(STDOUT); $|=1;
    #while (1) {
    #  # Dat: we must use sysread() here so we don't read too many chars before exec()
    #  $S=""; 1 while 0<sysread(STDIN, $S, 1, length$S) and substr($S,-1)ne"\n";
    #  last if $S ne "word\n" and $S ne "word\r\n";
    #  print $S;
    #}
  } elsif ($mode>1) {
    my $pid;
    die if !pipe my($ar), my($aw); # Imp: in Perl v5.005?
    die if !pipe my($br), my($bw);
    select(STDERR); $|=1; select(STDOUT); $|=1; # Dat: flush before fork()
    die "$0: fork: $!\n" if 0>($pid=fork());
    if ($pid==0) {
      $SIG{INT}='DEFAULT'; $SIG{TERM}='DEFAULT'; $SIG{HUP}='DEFAULT';
      close $ar; close $bw;
      die unless open STDIN,  "<&".fileno($br);
      die unless open STDOUT, ">&".fileno($aw);
      close $br if fileno($br)>2;
      close $aw if fileno($aw)>2;
      #close $br; close $aw;
      die "$0: $ARGV->[0]: cannot exec: $!\n" if !exec @$ARGV; # Imp: report to parent
    }
    if ($opt_log) {
      my $logfn="/tmp/ispell.log";
      # print STDERR "ispell.pl: appending session log to: $logfn\n"; # Dat: breaks Emacs
      die "$0: cannot append to logfile: $logfn\n" if
        !open STDERR, ">> $logfn";
    }
    close $br; close $aw;
    select($bw); $|=1;
    select(STDERR); $|=1; select(STDOUT); $|=1;
    my($in0,$in1);
    $in0=''; vec($in0,fileno($ar),1)=1; vec($in0,fileno(STDIN),1)=1;
    # Dat: we use sysread() instead of readline(), because readline() does
    #      too much buffering
    my $inbuf=""; my $outbuf="";
    my $terse_mode_p=0;
    while ($in0=~/[^\0]/) {
      next if !select($in1=$in0, undef, undef, undef);
      # Imp: check for interrupt etc.
      # Imp: error checking for print()
      if (vec($in1,fileno($ar),1)) {
        my $S; sysread($ar,$S,4096); # $S=<$ar>;
        # Dat: assert(defined($S));
        # vvv Dat: log unchanged $S
        print STDERR "> ".dumpq($S)."\n" if $opt_log and length($S)>0;
        if (0==length$S) {
          vec($in0,fileno($ar),1)=0;
          print $outbuf; $outbuf=""; # Dat: last line
          # close STDOUT;
        #} elsif ($mode==3) {
        #  # Imp: proper terse mode emulation (i.e. remove lines starting with
        #  #      "*", "+" or "-" in terse mode), in sync with ispell and its
        #  #      client
        #  # Dat: Emacs 21.4.1 doesn't need proper terse emulation
        #  $outbuf.=$S; pos($outbuf)=0;
        #  my $lastpos=0;
        #  while ($outbuf=~/\A(.*\n)/g) { # Dat: do line buffering
        #    $lastpos=pos($outbuf);
        #    if (0 && substr($1,0,1)eq"*" or substr($1,0,1)eq"+" or substr($1,0,1)eq"-") { } # Dat: incorrect, we're not in sync
        #    else { print $1 }
        #  }
        #  substr($outbuf,0,$lastpos)="";
        } else {
          print $S;
        }
      }
      if (vec($in1,fileno(STDIN),1)) {
        my $S; sysread(STDIN,$S,4096); # my $S=<STDIN>;
        print STDERR "< ".dumpq($S)."\n" if $opt_log and length($S)>0;
        if (0==length$S) {
          vec($in0,fileno(STDIN),1)=0; # Dat; force EOF
          #print $bw $outin; $inbuf=""; # Dat: last line
          close $bw;
        } elsif ($mode==3) {
          $inbuf.=$S; pos($inbuf)=0;
          my $lastpos=0;
          while ($inbuf=~/\G(.*\n)/mg) { # Dat: do line buffering
            $lastpos=pos($inbuf);
               if ("!\n"eq$1) { $terse_mode_p=1 }
            elsif ("%\n"eq$1) { $terse_mode_p=0 }
            else { print $bw $1 }
          }
          substr($inbuf,0,$lastpos)="";
        } elsif ($mode==4) {
          $inbuf.=$S; pos($inbuf)=0;
          my $lastpos=0;
          while ($inbuf=~/\G(.*\n)/mg) { # Dat: do line buffering
            $lastpos=pos($inbuf);
               if (substr($1,0,1)eq"~") { }
            elsif ("+\n"eq$1) { }
            elsif ("-\n"eq$1) { }
            else { print $bw $1 }
          }
          substr($inbuf,0,$lastpos)="";
        } else {
          print $bw $S;
        }
      }
    }
    close $ar; close $bw; # Dat: might be already closed;
    kill 'INT', $pid;
  }
}

#** @param $_[0] might be undefined
sub find_mspell_libdir($) {
  my $mspell_cmddir=$_[0];
  my $mydir=$0; $mydir=~s@/?[^/]+\Z(?!\n)@@;
  my $mspell_libdir;
  for my $m ($ENV{MSPELL_LIBDIR},$mspell_cmddir,$mydir,'/usr/local/lib/mspell','/usr/lib/mspell',
   '/usr/lib/Morpholigic', # Dat: standard path, for N.L.
   '.') {
    if (defined $m and (-f "$m/mspell.lex")) { $mspell_libdir=$m; last }
  }
  $mspell_libdir
}

#** @param $_[0] might be undefined
sub find_hunspell_dict_dir($) {
  my $hunspell_cmddir=$_[0];
  my $mydir=$0; $mydir=~s@/?[^/]+\Z(?!\n)@@;
  my $hunspell_libdir;
  for my $m ($ENV{HUNSPELL_LIBDIR},$hunspell_cmddir,$mydir,
   '/usr/local/share/hunspell',
   '/usr/local/lib/hunspell',
   '/usr/local/share/myspell',
   '/usr/share/hunspell',
   '/usr/share/myspell',  # Dat: standard path
   '.') {
    if (defined $m and (-f "$m/hu_HU.dic")) { $hunspell_libdir=$m; last }
  }
  $hunspell_libdir
}

my $targetdir='/usr/local/bin';
my $VERSION='0.06';

if (!@ARGV or $ARGV[0] eq '--help') {
  # Dat: even ispell(1) prints a help message w/o args
  print "This is ispell.pl, version $VERSION -- written by pts\@fazekas.hu
ispell.pl is free software, GNU GPL >=2.0. There is NO WARRANTY.\n";
  print "Usage: (ispell.pl is $0)
ispell.pl [--help] # show this help
ispell.pl -d { magyar | mspell hunspell } --help
ispell.pl --list
  Report installation status and possible problems with Hungarian spell
  checkers on this system.
ispell.pl --detect-hu  # detect available Hungarian dictionaries
ispell.pl --install [<dir>]  # install myself to <dir> (/usr/local/bin) etc.
ispell.pl -a [-m]  # run best Hungarian spell checker
ispell.pl -d magyar [-m] [<option> ...] [-a | <filename>]
ispell.pl -d { mspell | hunspell } [-m] [<option> ...] [-a]\n";
  exit;
}
if (@ARGV and $ARGV[0] eq '--ispell-pl-version') {
  print "ispell.pl $VERSION\n";
  exit;
}

sub orig_ispell_cmd() {
  my @mystat=(stat($0),-1,-1);
  my @stat;
  my @progs=qw(ispell.real ispell);
  # Dat: stat() is required to avoid symlink ambiguity and the difference
  #      between `./' and `./.' 
  for my $prog (@progs) {
    for my $dir (split/:/,$ENV{PATH}) {
      my $f="$dir/$prog";
      next if !(@stat=stat($f));
      next if $stat[0]eq$mystat[0] and $stat[1]eq$mystat[1];
      return $f
    }
  }
  undef
}

sub my_ispell_cmd() {
  for my $dir (split/:/,$ENV{PATH}) {
    my $f="$dir/ispell";
    return $f if (-f $f)
  }
  ""
}

# Dat: ispell doesn't support `--', anyway
if (@ARGV and ($ARGV[0] eq '--list' or $ARGV[0] eq '--install')) {
  my $badc=0;
  my $is_install=($ARGV[0] eq '--install');
  $targetdir=$ARGV[1] if defined $ARGV[1];
  eval {
    require Cwd;
    my $my_abs=Cwd::abs_path($0);
    my $my_ispell_cmd=my_ispell_cmd();
    my $ispell_abs=Cwd::abs_path(my_ispell_cmd());
    if ($my_abs ne $ispell_abs) {
      $badc++;
      print "BAD: ispell.pl is not the default `ispell' command on \$PATH\n";
      print "     The usual solution is to copy it as /usr/local/bin/ispell\n";
      print "     ispell.pl is '".fnq($my_abs)."', ispell is '".fnq($ispell_abs)."'\n";
    }
    if (substr($my_ispell_cmd,0,1)ne'/') {
      $badc++; print "BAD: ispell on \$PATH is not absolute: $my_ispell_cmd\n";
    }
  };
  my $bestdict;
  my $ddir;
  my $ispell_cmd=orig_ispell_cmd();
  my $iq=defined $ispell_cmd ? fnq($ispell_cmd) : "";
  my $S=defined $ispell_cmd ? qx($iq -vv 2>&1) : ""; $S="" if !defined $S;
  my @badifnone;
  if ($S=~s/^\@\(\#\) International Ispell (.*?\(but really )/$1/) {
    $S=~s@\n.*@@s;
    $badc++; print "BAD: ispell is fake: $S\n";
  } elsif ($S=~s/^\@\(\#\) International Ispell\s+([^\n]*)(?=\n).*\n\s*LIBDIR\s*=\s*"([^"]+)"/$1/s and -d $2) {
    $ddir=$2;
    $S=~s@\n.*@@s;
    print "ispell is installed: $S\n";
    print "ispell command is: $ispell_cmd\n";
    print "ispell dicts are in dir: $ddir\n";
    for my $dict (qw(hungarian magyar mspell hunspell)) {
      $S=qx($ispell_cmd -a -d $dict </dev/null 2>&1); $S="" if !defined $S;
      chomp $S;
      if ($S=~s/^\@\(\#\) International Ispell (.*)\Z/$1/) { KNOW:
	print "ispell knows -d $dict: $S\n";
	if (!-f"$ddir/$dict.hash") {
  	  $badc++; print "BAD: missing dict file: $ddir/$dict.hash\n"
	} else {
	  $bestdict=$dict;
	}
      } elsif ($S=~/^(?:Null|Truncated) hash table /) {
        my $comment=($dict eq 'mspell' or $dict eq 'hunspell') ? " (it's OK)" : "";
        print "ispell can't use -d $dict$comment: $S\n";
      } else {
	$S=~s@^Can't exec .*\n(.*?: command not found)\Z(?!\n)@$1@;
	print "ispell doesn't know -d $dict: $S\n";
      }
    }
    if (defined $bestdict) {
      print "best ispell dict command: $ispell_cmd -d $bestdict\n";
    } else {
      $badc++; push @badifnone, "BAD: no usable ispell Hungarian dictionary found\n";
    }
  } elsif ($S=~/\bcommand not found\b/) {
    print "ispell is not installed: command not found\n"; # Dat: usually returned by another instance of ispell.pl on $PATH
  } elsif (!defined $ispell_cmd) {
    print "ispell is not installed: program ispell missing\n"
  } else {
    my $ic=orig_ispell_cmd();  $ic="ispell" if !defined $ic;
    $badc++; print "BAD: ispell is not installed properly: unexpected output from `$ic -vv'\n"
  }
  # Dat: mspell is better than ispell, so we detect it later for $bestdict
  #my $needme_p=0;
  my @arb;
  $ddir=$fake_ispell_libdir if !defined $ddir; # Dat: Emacs needs to have mspell.hash touched here even if ispell is not installed
  for my $cmd (qw(mspell)) {
    # Imp: check dictfile avail
    $S=qx($cmd -v 2>&1); $S="program $cmd missing" if !defined $S;
    chomp $S;
    if ($S=~s/^\@\(\#\) International Ispell (.*?\(but really )/$1/ or $S=~/^Hunspell \d\S+$/) {
      $S=~s@\n.*@@s;
      print "$cmd is installed: $S\n";
      
      my $idict='mspell';
      if (defined $ddir and !-f "$ddir/$idict.hash") {
        push @arb, "$ddir/$idict.hash";
        $badc++; print "BAD: need file, touch it: $arb[-1]\n"
      }
      my $badc0=$badc;
      my $mspell_cmddir;
      for my $dir (split/:/,$ENV{PATH}) {
        if (-f "$dir/mspell") { $mspell_cmddir=$dir; last }
      }
      $badc++,print "BAD: mspell: command not found\n" if !defined $mspell_cmddir;
      my $mspell_libdir=find_mspell_libdir($mspell_cmddir);
      $badc++,push @badifnone, "BAD: mspell.lex: not found for $cmd; install it to /usr/local/lib/mspell/\n" if !defined $mspell_libdir or !(-f "$mspell_libdir/mspell.lex");
      $badc++,push @badifnone, "BAD: mhyph.lex:  not found for $cmd; install it to /usr/local/lib/mspell/\n" if !defined $mspell_libdir or !(-f "$mspell_libdir/mhyph.lex");
      print "mspell dictionary found: $mspell_libdir/{mspell,mhyph}.lex\n" if $badc0==$badc;
      #$needme_p=1 if !exists $idict{$dict};
      $bestdict='mspell' if $badc0==$badc;
    } elsif ($S=~s/^\@\(\#\) International Ispell //) {
      $S=~s@\n.*@@s;
      $badc++,print "BAD: $cmd isn't fake: $S\n";
    } else { print "$cmd is not installed: $S\n" }
  }
  # Dat: hunspell is better than mspell, so we detect it later for $bestdict
  for my $cmd (qw(hunspell)) {
    $S=qx($cmd -vv 2>&1); $S="program $cmd missing" if !defined $S;
    chomp $S;
    if ($S=~/^(Hunspell \d[-.\w]*)$/) { # Dat: works for Hunspell 0.9.7, 1.0-RC1
      print "$cmd is installed: $1\n";
      my $idict='hunspell';
      if (defined $ddir and !-f "$ddir/$idict.hash") {
        push @arb, "$ddir/$idict.hash";
        $badc++; print "BAD: need file, touch it: $arb[-1]\n"
      }
      my $badc0=$badc;
      my $hunspell_cmddir;
      for my $dir (split/:/,$ENV{PATH}) {
        if (-f "$dir/hunspell") { $hunspell_cmddir=$dir; last }
      }
      $badc++,print "BAD: command not found\n" if !defined $hunspell_cmddir;
      my $hunspell_dict_dir=find_hunspell_dict_dir($hunspell_cmddir);
      $badc++,print "BAD: hu_HU.dic for $cmd: not found; install it to /usr/local/share/hunspell/\n" if !defined $hunspell_dict_dir or !(-f "$hunspell_dict_dir/hu_HU.dic");
      $badc++,print "BAD: hu_HU.aff fir $cmd: not found; install it to /usr/local/share/hunspell/\n" if !defined $hunspell_dict_dir or !(-f "$hunspell_dict_dir/hu_HU.aff");
      #$needme_p=1 if !exists $idict{$dict};
      $bestdict='hunspell' if $badc0==$badc;
      print "hunspell dict -d hu_HU found: $hunspell_dict_dir/hu_HU.{dic,aff}\n" if $badc0==$badc;
    } elsif ($S=~s/^\@\(\#\) International Ispell //) {
      $S=~s@\n.*@@s;
      $badc++; print "BAD: $cmd isn't fake: $S\n";
    } else { print "$cmd is not installed: $S\n" }
  }
  if (defined $bestdict) {
    print "conclusion: best Hungarian spell command: $0 -d $bestdict -m -a\n";
    $badc-=@badifnone;
  } else {
    print @badifnone;
    $badc++; print "BAD: you have to install any of ispell+magyar, mspell, hunspell\n"
  }
  if (defined $ddir and !-f"$ddir/magyar-best.hash") {
    $badc++; print "BAD: need file, touch it: $ddir/magyar-best.hash\n" # Dat: needed by Emacs
  }
  if ($is_install) {
    print "starting installation\n";
    my($S,$ret);
    if (open F, "< $targetdir/ispell" and 2==read(F,$S,2) and $S ne "#!") {
      # Dat: won't clobber even if it's a symlink
      die "BAD: won't clobber ispell(1) binary: $targetdir/ispell\nBAD: installation failed\n";
    }
    my $file3="$targetdir/ispell";
    my $file2=$0;
    if ($file2!~m@/@) { # Dat: find on $PATH; shouldn't happen on UNIX
      for my $dir (split/:/,$ENV{PATH}) {
	$file2="$dir/$file2"; last
      }
      die "BAD: cannot find myself on \$PATH: $0\n" if $file2!~m@/@;
    }
    print "copying $file2 to $file3\n";
    my @stat=lstat $file2; # Dat: not lstat();
    die "BAD: cannot find: $file2\n" if !@stat;
    #if (-l _) { # was a symlink
    #  $S=readlink $file2; # Dat: don't append $bakext to $S
    #  die if !defined $S;
    #  die unless symlink  $S, "$file3";
    #  die "BAD: cannot create symlink: $file3: $!\nBAD: installation failed\n"
    #}
    { # Dat: do a real copy on the symlink target
      die unless open F, "< $file2";
      unlink "$file3";
      die "BAD: cannot create file: $file3: $!\nBAD: installation failed\n" unless open B, "> $file3";
      while (1) {
	die if !defined($ret=sysread(F,$S,4096));
	last if 0==$ret;
	die if $ret!=(syswrite(B,$S,$ret) or 0); # Dat `or 0': undef -> 0
      }
      die unless close B;
      die unless close F;
      # vvv Dat: don't verify the return values
      # vvv Dat: has race condition
      chown $stat[4], $stat[5], "$file3"; # UID, GID
      utime $stat[8], $stat[9], "$file3"; # access and mod time
      chmod((($stat[2]&00666)|0555), "$file3"); # Dat: Perl script: has to be readable and executable
    }
    for my $file (@arb) {
      print "creating $file\n";
      if (!open F, ">> $file") {
        die "BAD: cannot create file: $file: $!\nBAD: installation failed\n";
      }
      close F;
    }
    print "installation OK, verify by running this as normal user:\n  ispell --list  # ispell must be $targetdir/ispell\n";
  } else {
    $S=qx(ispell --ispell-pl-version 2>&1); $S="" if !defined $S;
    if ($S ne "ispell.pl $VERSION\n") {
      $badc++; print "BAD: need me ($0) as ispell on \$PATH, e.g $targetdir/ispell\n";
      # ^^^ so ispell will know `-d hunspell' etc.
    }
    print "warning: you had `BAD:' features -- please fix the problem!\n" if $badc>0;
  }
  exit($badc>0 ? 2 : 0);
}

if (@ARGV and ($ARGV[0] eq '--detect-hu')) {
  # Dat: detetcts in decreasing preference
  my @L;
  for my $dir (split/:/,$ENV{PATH}) {
    if (-f "$dir/hunspell") { push @L, "hunspell"; last }
  }
  for my $dir (split/:/,$ENV{PATH}) {
    if (-f "$dir/mspell") { push @L, "mspell"; last }
  }
  my $ispell_cmd=orig_ispell_cmd();
  if (defined orig_ispell_cmd() and $ispell_cmd ne "ispell") {
    my $iq=fnq($ispell_cmd);
    my $S=qx($iq -vv 2>&1); $S="" if !defined $S;
    push @L, "magyar" if
      $S=~/^\@\(\#\) International Ispell\s+([^\n]*)\n.*\n\s*LIBDIR\s*=\s*"([^"]+)"/s and (-d $2) and (-f "$2/magyar.hash") and (-s "$2/magyar.hash");
    # ^^^ Dat: detects even if magyar.hash is a symlink
  }
  print join(',', @L);
  print "\n" if @ARGV<2 or $ARGV[1] ne '--nonl';
  exit 0;
}

$ENV{ISPELL_RECURSE}=0 if !exists $ENV{ISPELL_RECURSE};
die "$0: infinite loop detected, aborting (fix your \$PATH!)\n"
  if $ENV{ISPELL_RECURSE}>2;
$ENV{ISPELL_RECURSE}++;

#** Will contain the very last dict -- whic is correct
my $opt_d=$ENV{DICTIONARY}; # may be undefined
my $is_interactive=1; # Dat: unused
my $is_vim=exists $ENV{VIM} and exists $ENV{VIMRUNTIME}; # called from vim
my $is_no_space_d=0;
my $opt_l;
my $opt_help=!(@ARGV);
my $need_filter_p=1;
my $had_v=0;
my $I;
my @A;
for ($I=0;$I<@ARGV;$I++) {
  # Imp: better option parsing: ignore `-a' on bad place etc.
  if ($I!=$#ARGV and $ARGV[$I]eq'-d') { $opt_d=$ARGV[++$I] }
  elsif (substr($ARGV[$I],0,2)eq'-d') { $is_no_space_d=1; $opt_d=substr($ARGV[$I],2) }
  elsif ($ARGV[$I]eq'-a' or $ARGV[$I]eq'-l') { $opt_l=$ARGV[$I]eq'-l'; $is_interactive=0; push @A, $ARGV[$I] }
  elsif ($ARGV[$I]eq'--help') { $opt_help=1; $need_filter_p=0; push @A, $ARGV[$I] }
  elsif ($ARGV[$I]eq'-v' ) { $need_filter_p=0; $had_v=1; push @A, $ARGV[$I] }
  elsif ($ARGV[$I]eq'-vv') { $need_filter_p=0; $had_v=1; push @A, $ARGV[$I] }
  elsif ($ARGV[$I]eq'--log') { $opt_log=1; }
  elsif (substr($ARGV[$I],0,2)eq'--' or substr($ARGV[$I],0,1)ne'-') { last }
  else { push @A, $ARGV[$I] }
}
splice @ARGV, 0, $I, @A;
delete $ENV{DICTIONARY}; # Dat: used by ispell(1)
my $do_spell_mode=($is_vim and $opt_l and $is_no_space_d); # called from s:SpellVerifyLanguage of vimspell.vim

if (!$opt_help and !$had_v and (!defined $opt_d or $opt_d eq 'magyar-best')) {
  # Dat: the user hasn't specified Hungarian sublanguage -- choose the best.
  my $df;
  for my $dir (split/:/,$ENV{PATH}) {
    if (-f "$dir/hunspell") { $df="hunspell"; last }
  }
  if (!defined $df) {
    for my $dir (split/:/,$ENV{PATH}) {
      if (-f "$dir/mspell") { $df="mspell"; last }
    }
    if (!defined $df) {
      my $ispell_cmd;
      if (!defined ($ispell_cmd=orig_ispell_cmd()) or "ispell" eq $ispell_cmd) {
        die "$0: no useful Hungarian spell checkers found; try  $0 --list\n"
      }
      $df="magyar"; # MagyarISpell
    }
  }
  $opt_d=$df;
}

# die "$0: please install ispell first\n"

#$opt_d='magyar'; # Dat: for debugging

if (0) {
} elsif (defined $opt_d and $opt_d eq 'errors' and $opt_l) {
  # consider all words as errors
  while (<STDIN>) { while (m@([-a-zA-Z·È˙ı˚Û¸ˆÌ¡…⁄’€”‹÷Õ]+)@g) { print "$1\n" } }
  exit 0;
} elsif (defined $opt_d and $opt_d eq 'mspell') {
  # Dat: SUXX: `mspell -l' prints `@(#) Inter...' header
  my $mspell_cmddir;
  for my $dir (split/:/,$ENV{PATH}) {
    if (-f "$dir/mspell") { $mspell_cmddir=$dir; last }
  }
  die "$0: mspell: command not found\n" if !defined $mspell_cmddir;
  my $mspell_libdir=find_mspell_libdir($mspell_cmddir);
  die "$0: mspell.lex: not found\n" if !defined $mspell_libdir;
  die "$0: mhyph.lex: not found\n" if !(-f "$mspell_libdir/mhyph.lex");
  $do_spell_mode=4 if $need_filter_p and $do_spell_mode==0;
  do_spell ["mspell", "-d", "$mspell_libdir/mspell.lex", "-D", "$mspell_libdir/mhyph.lex", @ARGV], $do_spell_mode;
} elsif (defined $opt_d and $opt_d eq 'hunspell') {
  my $df;
  for my $dir (split/:/,$ENV{PATH}) {
    if (-f "$dir/hunspell") { $df=$dir; last }
  }
  die "$0: hunspell: command not found\n" if !defined $df;
  $df=find_hunspell_dict_dir($df);
  die "$0: hu_HU.dic: not found\n" if !defined $df;
  die "$0: hu_HU.aff: not found\n" if !defined $df or !(-f"$df/hu_HU.aff");
  # Dat: move -a last, because Emacs 21 requires it: with `-a -m' hunspell
  #      doesn't emit the `@(#) International Ispell' header, but with
  #      `-m -a' it emits
  my $I=0;
  my $had_ma=0;
  while ($I<@ARGV) {
    if ($ARGV[$I] eq '-a') { splice(@ARGV,$I,1); $had_ma=1 }
                      else { $I++ }
  }
  push @ARGV, '-a' if $had_ma;
  #die "@ARGV";
  # ^^^ Dat: use hu_HU.dic in the source (binary) directory
  $do_spell_mode=3 if $need_filter_p and $do_spell_mode==0;
  # ^^^ Dat: hunspell 1.0 doesn't have terse mode (i.e. ispell commands "!"
  #     and "%"), but it prints a "*" for these commands, which confuses
  #     ispell.el of Emacs 21. So we emulate terse mode.
  do_spell ["hunspell", "-d", "$df/hu_HU", @ARGV], $do_spell_mode;
} elsif (!defined $opt_d or $opt_help) { # Dat: use ispell default dict
  my $orig_ispell_cmd=orig_ispell_cmd();
  if (!defined $orig_ispell_cmd) {
    # Dat: fake ispell presence for Emacs 21 ispell.el
    print "\@(#) International Ispell Version 3.1.20 fake ispell.pl v$VERSION\n",
    	  "\tLIBDIR = \"$fake_ispell_libdir\"\n";
  } else {
    die "$0: ispell: command not found\n" if !defined $orig_ispell_cmd;
    $do_spell_mode=0 if $do_spell_mode==1; # Dat: original ispell works with vi(1)
    do_spell [orig_ispell_cmd(), @ARGV], $do_spell_mode;
  }
} else {
  my $orig_ispell_cmd=orig_ispell_cmd();
  die "$0: ispell: command not found\n" if !defined $orig_ispell_cmd;
  $do_spell_mode=0 if $do_spell_mode==1; # Dat: original ispell works with VI
  do_spell [orig_ispell_cmd(), "-d", $opt_d, @ARGV], $do_spell_mode;
}
__END__

