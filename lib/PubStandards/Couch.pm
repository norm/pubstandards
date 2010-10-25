package PubStandards::Couch;

use Modern::Perl;
use Moose::Role;
use MooseX::Method::Signatures;

use DB::CouchDB;

has database => (
    isa     => 'DB::CouchDB',
    is      => 'ro',
);

method build_db_handle (
    Str $database = 'pubstandards',
    Str $host     = 'localhost'
) {
    my $db = DB::CouchDB->new(
            host => $host,
            db   => $database,
        );
    $db->create_db();
    
    $self->{'database'} = $db;
}



method get_document ( Str $id! ) {
    my $db  = $self->get_database();
    my $doc = $db->get_doc( $id );
    
    my $no_such_document = defined $doc->{'error'} 
                           && 'not_found' eq $doc->{'error'};
    
    return undef if $no_such_document;
    return $doc;
}
1;
