#############   !perl -T
use 5.16.0;
use strict;
use warnings;
use Test::More tests => 1;
use Test::Output;
use feature 'say';

use Franckys::Error;

# Custom Error
def_error('WARNING',   'Some files could not be opened');
def_error('WFILE',     "\t%s");

# Polymorphic function : returns a "filename -> filehandler" hashref or an Error object
sub open_files {
    my @files = @_;
    my %fh    = ();

    # Get a cumulative Error Object
    my $error   = Error();

    # Open my files for reading
    foreach my $filename ( @files ) {
        ($error->Error('ESTAT', $filename, \%fh) && next)
            unless -f $filename;

        if ( open my $fh, '<', $filename ) {
            $fh{ $filename } = $fh;
        }
        else {
            $error->Error('EOPEN', $filename, \%fh);
        }
    }

    # Polymorphic return
    return $error->nb_errors > 0 ? $error : \%fh;
}

sub main {
    my $handlers = open_files( @_ ) ;
    
    if ( is_error( $handlers ) ) {
        # $handlers is an Error object
        
        # Retrieve the custom datum set by open_files()
        my $datum = $handlers->data();

        # Die if no file handler at all was opened
        die_if_error($handlers)
            unless %$datum;

        # Generate warnings otherwise and go on with the business
        say Error('WARNING')->as_string();
        say Error('WFILE', $_)->as_string() foreach $handlers->msgs();

        # Attach whatever valid file handlers
        $handlers = $datum;
    }

    foreach my $filename ( sort keys %$handlers ) {
        say "Now handling: $filename... done.";
        close $handlers->{ $filename };
    }
}

# TEST 1
my $expected = do {
    local $/ = undef;
    <DATA>
};

chdir('t');
my @files = map {
            chomp;
            s/\.t$//;
            ("${_}.t", "${_}.nofile") 
        } qx(ls *.t);

main(@files);

stdout_is { main(@files) } $expected, 'main()';

__END__
(WARNING) Some files could not be opened
(WFILE) 	(ESTAT) Cannot stat file:[00-load.nofile]
(WFILE) 	(ESTAT) Cannot stat file:[01-overall.nofile]
(WFILE) 	(ESTAT) Cannot stat file:[manifest.nofile]
(WFILE) 	(ESTAT) Cannot stat file:[pod-coverage.nofile]
(WFILE) 	(ESTAT) Cannot stat file:[pod.nofile]
Now handling: 00-load.t... done.
Now handling: 01-overall.t... done.
Now handling: manifest.t... done.
Now handling: pod-coverage.t... done.
Now handling: pod.t... done.
