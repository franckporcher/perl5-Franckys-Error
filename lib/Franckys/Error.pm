#===============================================================================
#
#         FILE: <+FILENAME+>
#
#        USAGE: <+USAGE+>
#
#  DESCRIPTION: <+DESCRIPTION+>
#
#      OPTIONS: <+OPTIONS+>
# REQUIREMENTS: <+REQUIREMENTS+>
#         BUGS: <+BUGS+>
#        NOTES: <+NOTES+>
#
#       AUTHOR: Franck Porcher, Ph.D. - franck.porcher@franckys.com
# ORGANIZATION: Franckys
#      CREATED: Mer 18 fév 2015 21:06:50 PST
#     REVISION: 0.11
#
# Copyright (C) 1995-2015 - Franck Porcher, Ph.D 
# www.franckys.com
# Tous droits réservés - All rights reserved
#===============================================================================
package Franckys::Error;
use v5.16;                                   ## no critic (ValuesAndExpressions::ProhibitVersionStrings)
use strict;
use warnings;
use autodie;
use feature             qw( switch say unicode_strings );

use Scalar::Util        qw(blessed reftype);
use Carp                qw( carp croak confess cluck );

#----------------------------------------------------------------------------
# UTF8 STUFF
#----------------------------------------------------------------------------
use utf8;
use warnings            FATAL => "utf8";
use charnames           qw( :full :short );
use Encode              qw( encode decode );
use Unicode::Collate;
use Unicode::Normalize  qw( NFD NFC );

#----------------------------------------------------------------------------
# I/O
#----------------------------------------------------------------------------
use open qw( :encoding(UTF-8) :std );

#----------------------------------------------------------------------------
# EXPORTED STUFF
#----------------------------------------------------------------------------
use Perl6::Export::Attrs;

#----------------------------------------------------------------------------
# POD
#----------------------------------------------------------------------------
=pod

=head1 NAME

Franckys::Error - A simple Error reporting mechanism


=head1 VERSION

Version 0.11

=cut

use version; our $VERSION = 'v0.11';           # Keep on same line


=pod

=head1 SYNOPSIS

    use Franckys::Error;

    use 5.16;
    use feature 'say';

    # Custom Error
    def_error( 'WARNING',   'Some files could not be opened');
    def_error( 'WFILE',     "\t%s");

    # Polymorphic function : returns an arrayref of file handlers or an Error object
    sub open_files {
        my @files = @_;
        my @fh    = ();
    
        # Get a cumulative Error Object
        my $error   = Error();

        # Open my files for reading
        foreach my $filename ( @ARGV ) {
            $error->Error('ESTAT', $filename, \@h) && next
                unless -f $filename;

            open my $fh, '<', $filename
                or $error->Error('EOPEN', $filename, \@h);
        }

        return $error->nb_errors > 0 ? $error : \@h;
    }

    sub main {
        my $data = open_files( @ARGV ) ;
        
        if ( is_error( $data ) ) {
            # Retrieve the custom datum set by open_files()
            my $file_handlers = $data->data();

            # Die if no file handler at all was opened
            die_if_error($data)
                unless @$file_handlers;

            # Generate warnings otherwise and go on with the business
            say Error('WARNING')->as-string();
            say Error('WFILE', $_)->as-string() foreach $data->msgs();

            $data = $file_handlers;
        }

        ...
    }

    main();


=head1 EXPORT

The following functions are exported by default :

=over 4


=item . B<Error()>

=item . B<def_error()>

=item . B<is_error()>

=item . B<die_if_error()>

=back


=head1 SUBROUTINES AND METHODS

=cut


#----------------------------------------------------------------------------
# GLOBAL OBJECTS AND CONSTANTS
#----------------------------------------------------------------------------
# CONSTANTS

# GLOBALS
my %ErrMsg = (
    EARG    => 'Missing argument:[%s]',
    ELIB    => 'Cannot use library:[%s] - %s',
    ENOTAG  => 'Missing tag. Params:[%s]',
    EOPEN   => 'Cannot open file:[%s]',
    ESTAT   => 'Cannot stat file:[%s]',
    ETAG    => 'Invalid tag:[%s] %s',
);

=pod

=head2 Default Error tags and messages

=over

=item . EARG    => Missing argument:[%s]

=item . ELIB    => Cannot use library:[%s] - %s

=item . ENOTAG  => Missing tag. Params:[%s]

=item . EOPEN   => Cannot open file:[%s]

=item . ESTAT   => Cannot stat file:[%s]

=item . ETAG    => Invalid tag:[%s] %s

=back

=head2 (void) def_error($error_tag, $error_fmt);

Allows to define custom errors or redefine default errors.

=cut

sub def_error :Export(:DEFAULT) {
    my ($error_tag, $error_fmt) = @_;
    $ErrMsg{ $error_tag } = $error_fmt;
}


#----------------------------------------------------------------------------
# Library
#----------------------------------------------------------------------------
###
### Error()
###
=pod

=head2 my $error = Error([$Error,] $errtag, $param [, $datum]);

=head2 my $error = Error([$Error,] $errtag, [$param,...] [, $datum]);

=over

=item @@ B<$Error>  - An optional Error object

=item @@ B<$errtag> - A valid tag error (String)

=item @@ B<$param> - Any valid scalar Perl data

=item @@ B<$datum> - A valid scalar Perl data to return to caller within the error object, to be retrieved with method Error->data()

=back

Returns an B<Error> object whose error tag is set to C<$errtag> and whose
associated error message is instantiated with parameter(s) C<$param...>

The tag B<ENOTAG> is used whenever the error tag is not defined.

Use B<undef> or B<[]> to signal no parameters.

The Error object can be used as a structured container that has the dual ability
to signal an error (per se) and yet return any custom data to the caller in the
same time, making this mechanism very flexible.

The caller can pass any number of parameters to instantiate the error message associated with the error tag. In this case
the parameters should be gathered together within an array reference. in this case, the caller wanting to pass an array reference
as one parameter should use the form C<[ $my_array_reference ]>, though it won't be too informative as a message parameter.

The B<Error> object is cumulative and has the ability to record any number of error events within the same Error object.
Whenever an I<$Error> argument is provided, it is aggregated as follows :

=over 4

=item . The initial error tag is left untouched.

=item . $datum is aggregated to the previous datum(s) within an array reference.

=item . A new error message is build using $errtag and $param... and aggregated to the previous message(s) into an array reference.

=back

=cut

sub Error :Export(:DEFAULT) {
    # Request for a default error object
    return bless {
                tag     => undef,
                msgs    => [],
                datum   => [],
                n       => 0,
            } => __PACKAGE__
        unless @_;

    # Initial error event
    my ($error, $errtag, $param, $datum) = @_;

    my $pkg = blessed $error || '';
    unless ( $pkg eq __PACKAGE__ ) {
        my $error = Error();
        return $error->Error(@_);
    }

    # Parameters
    my @params
        = !blessed($param) && ((reftype($param) || '') eq 'ARRAY')      ? @$param 
        : defined($param)                                               ? $param
        :                                                                 ()
        ;

    # Record error event
    unless ( $errtag && exists $ErrMsg{$errtag} ) {
        if ($errtag) {
            @params = ($errtag, "@params");
            $errtag = 'ETAG';
        }
        else {
            @params = "@params";
            $errtag = 'ENOTAG';
        }
    }

    my $errmsg
        = sprintf(
            '(%s) %s', 
            $errtag,
            sprintf( $ErrMsg{$errtag}, @params ),
    );

    # Aggregate
    if ( (my $n = $error->{n}) == 0 ){
        $error->{tag  }    = $errtag;
        $error->{datum}[0] = $datum;
        $error->{msg  }[0] = $errmsg;
        $error->{n    }    = 1;
    }
    else {
        $error->{datum}[$n] = $datum;
        $error->{msg  }[$n] = $errmsg;
        $error->{n    }++;
    }

    return $error;
}


###
### is_error()
###
=pod

=head2 my $bool = is_error( $x );

Returns a boolean value depending whether $x is an Error object or not

=cut

sub is_error :Export(:DEFAULT) {
    my $x = shift;
    return $x && blessed($x) && $x->isa(__PACKAGE__);
}


###
### die_if_error()
###
=pod

=head2 (void) die_if_error( $x )

Launch an exception with Carp::confess( $msg ) if $x is an Error object.
The $msg argument will be the concatenation of all error messages recorded within the Error object. 

=cut

sub die_if_error :Export(:DEFAULT) {
    my $error = shift;

    if ( is_error($error) ) {
        my @msgs = $error->msgs();
        confess( "@msgs" );
    }
}


###
### tag()
###
=pod

=head2 my $tag = $error->tag()

Returns the error tag of the B<Error> object.

=cut

sub tag { return $_[0]{tag} }


###
### nb_errors()
###
=pod

=head2 my $nb_errors = $error->nb_errors();

Returns the positive number of error events recorded within the B<Error> object.


=cut

sub nb_errors { return : $_[0]->{n} }


###
### msgs()
###
=pod

=head2 my ($first_msg) = $error->msgs(0);

=head2 my $last_msg    = $error->msgs();

=head2 my @all_msgs    = $error->msgs();

=head2 my @some_msgs   = $error->msgs($index...);


In scalar context, returns the error message of the last error event recorded within the B<Error> object.

In list context, returns all or some of the error messages recorded within the B<Error> object depending on the further use of
constraining indexes.

Ideally, B<$index> must be in the range [O, $nb_msg[. For 
efficiency reasons though, this consistency check is not carried over, leaving this to the user's responsibility.

There are therefore two ways to get to the second error message : 

=over

=item C<my ($do_not_care, $msg) = $error-E<gt>msgs();>

=item C<my ($msg) = $error-E<gt>msgs(1);>

=back

=cut

sub msgs { 
    my $self = shift;

    return wantarray
        ?  (
                @_ ? (@{ $self->{msg} })[@_] : @{$self->{msg}}
           )
        : $self->as_string();
}

###
### as_string()
###
=pod

=head2 my $msg  = $error->as-string();

Returns the last error message in any context

=cut

sub as_string { 
    $_[0]{msg}[-1];
}

###
### data()
###
=pod

=head2 my $last_datum    = $error->data();

=head2 my ($first_datum) = $error->data();

=head2 my @all_datums    = $error->data();

=head2 my @some_datums   = $error->data($index...);

In scalar context, returns the last datum associated with B<Error> object.

In list context, filters or returns them all.

=cut

sub data { 
    my $self = shift;

    return wantarray
        ?  (
                @_ ? (@{ $self->{datum} })[@_] : @{$self->{datum}}
           )
        : $self->{datum}[-1]
        ;
}




#--------
1;
__END__
=pod 

=head1 DEPENDENCIES

=over 4

=item B<Perl6::Export::Attrs>

=back


=head1 AUTHOR

Franck PORCHER,PhD, C<< <franck.porcher at franckys.com> >>


=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to C<bug-franckys-error at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Franckys-Error>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 INCOMPATIBILITIES

This code is guaranteed to work with Perl 5.16 or higher.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Franckys::Error


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Franckys-Error>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Franckys-Error>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Franckys-Error>

=item * Search CPAN

L<http://search.cpan.org/dist/Franckys-Error/>

=back


=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 - Franck Porcher, Ph.D - All rights reserved

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut
