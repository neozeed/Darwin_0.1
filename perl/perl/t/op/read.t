#!./perl

# $RCSfile: read.t,v $$Revision: 1.1.1.1 $$Date: 1998/08/12 17:33:12 $

print "1..4\n";


open(FOO,'op/read.t') || open(FOO,'t/op/read.t') || die "Can't open op.read";
seek(FOO,4,0);
$got = read(FOO,$buf,4);

print ($got == 4 ? "ok 1\n" : "not ok 1\n");
print ($buf eq "perl" ? "ok 2\n" : "not ok 2 :$buf:\n");

seek (FOO,0,2) || seek(FOO,20000,0);
$got = read(FOO,$buf,4);

print ($got == 0 ? "ok 3\n" : "not ok 3\n");
print ($buf eq "" ? "ok 4\n" : "not ok 4\n");
