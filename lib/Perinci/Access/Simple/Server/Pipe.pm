package Perinci::Access::Simple::Server::Pipe;

use 5.010001;
use strict;
use warnings;
use Log::Any '$log';

# VERSION

use Data::Clean::JSON;
use JSON;

use Moo;

has req => (is => 'rw'); # current Riap request
has res => (is => 'rw'); # current Riap response
has _pa => (
    is => 'rw',
    lazy => 1,
    default => sub {
        require Perinci::Access::Schemeless;
        Perinci::Access::Schemeless->new();
    });

my $json = JSON->new->allow_nonref;
my $cleanser = Data::Clean::JSON->new;

$|++;

# default handler

sub handle {
    my ($self) = @_;
    my $req = $self->req;

    my $res = $self->_pa->request($req->{action} => $req->{uri}, $req);
    $self->res($res);
}

sub send_response {
    my $self = shift;
    my $res = $self->res // [500, "BUG: Response not set"];
    $log->tracef("Sending response to stdout: %s", $res);
    $cleanser->clean_in_place($res);
    my $res_json = $json->encode($res);
    print "J", length($res_json), "\015\012", $res_json, "\015\012";
}

sub run {
    my $self = shift;
    my $last;

    $log->tracef("Starting loop ...");

  REQ:
    while (1) {
        my $line = <STDIN>;
        $log->tracef("Read line from stdin: %s", $line);
        last REQ unless defined($line);
        my $req_json;
        if ($line =~ /\Aj(.*)/) {
            $req_json = $1;
        } elsif ($line =~ /\AJ(\d+)/) {
            read STDIN, $req_json, $1;
            my $crlf = <STDIN>;
        } else {
            $self->res([400, "Invalid request line, use J<num> or j<json>"]);
            $last++;
            goto RES;
        }
        $log->tracef("Read JSON from stdin: %s", $req_json);
        my $req;
        eval { $req = $json->decode($req_json) };
        my $e = $@;
        if ($e) {
            #$self->res([400, "Invalid JSON ($e)"]);
            $self->res([400, "Invalid JSON"]);
            goto RES;
        } elsif (ref($req) ne 'HASH') {
            $self->res([400, "Invalid request (not hash)"]);
            goto RES;
        }
        $self->req($req);

      HANDLE:
        $self->handle;

      RES:
        $self->send_response;

        last if $last;
    }
}

1;
# ABSTRACT: (Base) class for creating Riap::Simple server over pipe

=head1 SYNOPSIS

In C</path/to/your/program>:

 #!/usr/bin/perl
 package MyRiapServer;
 use Moo;
 extends 'Perinci::Access::Simple::Server::Pipe';

 # override some methods ...

 package main;
 MyRiapServer->run;

Accessing the server via L<Perinci::Access>:

 % perl -MPerinci::Access -e'my $pa = Perinci::Access->new;
   my $res = $pa->request(call => "riap+pipe:/path/to/your/prog////Foo/func");


=head1 DESCRIPTION

This module is a class for creating L<Riap::Simple> server over pipe. Riap
requests will be read from STDIN, and response sent to STDOUT.

By default, the L<handle()> method processes the Riap request using
L<Perinci::Access::Schemeless>. You can customize this by overriding the method.
The Riap request is in C<req>. Method should set C<res> to the Riap response.

This module uses L<Log::Any> for logging.

This module uses L<Moo> for object system.


=head1 ATTRIBUTES

=head2 req => HASH

The current Riap request.

=head2 res => HASH

The current Riap response.


=head1 METHODS

=for Pod::Coverage BUILD

=head2 run()

The main method. Will start a loop of reading request from STDIN and sending
response to STDOUT. Riap request will be put to C<req> attribute.

=head2 handle()

The method that will be called by run() to set C<res> attribute. By default it
will pass the request to L<Perinci::Access::Schemeless>. You can override this
method to provide custom behavior.

=head2 send_response()

The method that sends C<res> to client (STDOUT).


=head1 SEE ALSO

L<Riap::Simple>, L<Riap>, L<Rinci>

L<Perinci::Access::Simple::Server::Socket>.

=cut
