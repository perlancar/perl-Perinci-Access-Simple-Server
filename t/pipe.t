#!perl

use 5.010;
use strict;
use warnings;
use Test::More 0.96;

use Cwd;
use Perinci::Access::Simple::Client;

diag "cwd: ", getcwd();
diag "bin/peri-pipe executable accessible? ", ((-x "bin/peri-pipe") ? 1:0);

my $pa  = Perinci::Access::Simple::Client->new;
my $res = $pa->request(
    call => "riap+pipe:bin/peri-pipe////Perinci/Examples/sum",
    {args=>{array=>[1,2,3,4,5]}});

is_deeply($res, [200, "OK", 15])
    or diag explain $res;

done_testing();
