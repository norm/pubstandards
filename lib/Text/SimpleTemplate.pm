package Text::SimpleTemplate;

use Modern::Perl;
use Moose;
use MooseX::FollowPBP;
use MooseX::Method::Signatures;

use IO::All     -utf8;

has base_dir => (
    isa      => 'Str',
    is       => 'ro',
    required => 1,
);
has dimension => (
    isa      => 'Str',
    is       => 'ro',
    required => 1,
);

my $include_command = qr{
        ^
        (?'before' .*? )
        \$\{ include \s+ (?'template' [^\}]+ ) \s* \} \s*
        (?'after' .* )
        $
    }sx;



method get_template ( 
        Str     $template!, 
        Str     $extension!,
        Str     $context?
) {
    $context = $template
        unless defined $context;
    
    return $self->get_template_with_includes(
            $template,
            $extension,
            $context,
            1
        );
}
method get_template_with_includes (
        Str     $template!, 
        Str     $extension!,
        Str     $context,
        Bool    $use_base = 0
) {
    my $filename = $self->find_template_filename(
                       $template,
                       $extension,
                       $context,
                       $use_base,
                   );
    return unless $filename;
    
    my $content = $self->read_template_file( $filename );
    return unless defined $content;
    
    return $self->include_subtemplates( $content, $extension, $context );
}

method include_subtemplates (
        Str $content!,
        Str $extension!,
        Str $context!
) {
    my $done = '';
    
    while ( $content =~ $include_command ) {
        my %match = %+;
        
        $content = $match{'after'};
        $done   .= ( $match{'before'} // '' )
                 . ( $self->get_template_with_includes(
                        $match{'template'},
                        $extension,
                        $context
                     ) // ''
                   );
    }
    
    $done .= $content
        if length $content;
    
    return $done;
}

method find_template_filename (
        Str     $template!,
        Str     $extension!,
        Str     $context!,
        Bool    $use_base=0
) {
    my $base_dir  = $self->get_base_dir();
    my $dimension = $self->get_dimension();
    my $filename  = "${template}.${extension}";
    
    my @specialisations = (
            "${base_dir}/${dimension}/${context}/${filename}",
            "${base_dir}/${dimension}/${filename}",
            "${base_dir}/${context}/${filename}",
            "${base_dir}/_base/${filename}",
            "${base_dir}/${filename}",
        );
    
    push(   @specialisations,
            "${base_dir}/_base/standard_template.${extension}"
        ) if $use_base;
    
    foreach my $attempt ( @specialisations ) {
        return $attempt
            if -f $attempt;
    }
    
    return;
}

method read_template_file ( Str $filename! ) {
    my $handle = io $filename;
    
    return '' unless $handle->exists;
    return $handle->all();
}

1;
