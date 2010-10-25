package PubStandards::Couch;

use Modern::Perl;
use Moose::Role;
use MooseX::Method::Signatures;

use DB::CouchDB;
use Test::Deep::NoTest  qw( eq_deeply );

use constant ROWS_PER_REQUEST => 50;

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
method update_document_if_changed ( Str $id!, HashRef $state ) {
    my $db      = $self->get_database();
    my $doc     = $db->get_doc( $id );
    my $changed = 0;
    
    if ( $doc->err ) {
        $doc     = $db->create_named_doc( $state, $id );
        $changed = 1;
    }
    else {
        # copy across the couchdb internal state as the client shouldn't
        # have to worry about preserving that part
        $state->{'_id'} = $doc->{'_id'};
        $state->{'_rev'} = $doc->{'_rev'};
        
        my %all_keys;
        $all_keys{$_}++ for keys %$state;
        $all_keys{$_}++ for keys %$doc;
        delete $all_keys{'_id'};
        delete $all_keys{'_rev'};
        
        foreach my $key ( keys %all_keys ) {
            $changed = 1 
                unless eq_deeply( $state->{$key}, $doc->{$key} );
        }
        
        $doc = $db->update_doc( $id, $state )
            if $changed;
    }
    
    return( $changed, $doc );
}

method query_view ( Str $design!, Str $view!, HashRef $options? ) {
    my $db      = $self->get_database();
    my %options = (
            limit => ROWS_PER_REQUEST,
        );
    
    %options = ( %options, %$options )
        if defined $options;
    
    my $results = $db->view(
            $design,
            $view,
            \%options,
        );
    
    my $count = $results->{'count'} // 0;
    my $more  = $count > ROWS_PER_REQUEST;
    
    return( $results, $more );
}
method query_view_for_key ( Str $design!, Str $view!, Str $key! ) {
    my( $results, undef )
        = $self->query_view( 
              $design,
              $view,
              {
                  key => JSON->new->allow_nonref->encode($key),
              }
          );
    
    return $results->{'data'}->[0]
        if defined $results;
    return;
}

1;
