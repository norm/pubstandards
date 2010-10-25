package Text::Intermixed;

use Modern::Perl;

use base qw( Exporter );
our @EXPORT = qw( render_intermixed );

my $next_package = 0;



sub render_intermixed {
    my $template = shift;
    my $vars     = shift;
    
    # use a temporary package for the evaluation
    my $root = create_package();
    install_into( $root, $vars );
    
    # turn the template into raw perl to be evaluated
    my $evaluate = "package $root;\n"
                 . "#line 2 template\n"
                 . expand_code( $template )
                 . ";";
    my $RENDER;
    my $return;
    
    {
        no strict;                  ## no critic
        $return = eval $evaluate;   ## no critic
    }
    
    my $error = $@;
    $return   = $RENDER if defined $RENDER;
    
    return( $return, $error );
}

sub expand_variables {
    my $text = shift // '';
    return '' unless length $text;
    
    my $find_variable = qr{
            ^
            (                           # $1: match nothing (start of string)
                    |                   #     or everything before the var,
                .*? [^\\]               #     ensuring ${var} is not escaped
            )
            \$ ( \{                     # $2: outer variable match inc braces
                (                       # $3: the variable
                    (?:
                        (?> [^\{\}]+ )  # non-braces without backtracking
                        |
                        (?2)            # or recurse to $2...
                    )+
                )
            \} )
            ( .* )                      # $4: everything after the variable
            $
        }sx;
    
    my $expanded;
    if ( $text =~ $find_variable ) {
        my $before   = $1 // '';
        my $variable = $3;
        my $after    = $4 // '';
        
        $expanded = expand_variables( $before )
                    . "\$RENDER .= \$$variable;\n"
                    . expand_variables( $after );
    }
    else {
        $text =~ s{'}{\\'}gs;
        $expanded = "\$RENDER .= '$text';\n";
    }
    
    # remove escapes from escaped variables
    $expanded =~ s{ \\ \$ }{\$}gsx;
    
    return $expanded;
}

sub expand_code {
    my $text = shift // '';
    return '' unless length $text;
    
    my $find_embedded_perl = qr{
            ^
            (                       # $1: match nothing (start of string)
                    |               #     or everything before the code,
                .*? [^\\]           #     ensuring delimiter is not escaped
            )
            \{ \{
                ( .*? [^\\] )       # $2: the code (delimiter is not escaped)
            \} \} \n?               #     ... eat any trailing newline
            ( .* )                  # $3: everything after the code
            $
        }sx;
    
    my $expanded;
    if ( $text =~ $find_embedded_perl ) {
        my $before = $1;
        my $perl   = $2;
        my $after  = $3;
        
        $expanded = expand_variables( $before )
                  . "$perl\n"
                  . expand_code( $after );
    }
    else {
        $expanded = expand_variables( $text );
    }
    
    # remove escapes from escaped delimiters
    $expanded =~ s{ \\ ( [\{\}] ) }{$1}gsx;
    
    return $expanded;
}

sub install_into {
    my $root = shift;
    my $vars = shift;
    
    foreach my $key ( keys %{ $vars } ) {
        my $value = $vars->{ $key };
        
        no strict 'refs';                       ## no critic
        local *SYM = *{"$ {root}::$key"};
        if ( ! defined $value ) {
            delete ${"${root}::"}{ $key };
        }
        elsif ( ref $value ) {
            *SYM = $value;
        }
        else {
            *SYM = \$value;
        }
    }
}

sub create_package {
    __PACKAGE__ . '::Root' . $next_package++;
}

sub scrub_package {
    my $package = shift;
       $package =~ s/^Text::Template:://;
    
    no strict 'refs';       ## no critic
    my $hash = $Text::Template::{$package."::"};
    foreach my $key ( keys %$hash ) {
        undef $hash->{$key};
    }
}


1;

__END__

=head1 NAME

B<Text::Intermixed> - Expand templates with intermixed perl

=head1 VERSION


=head1 SYNOPSIS

    use Text::Intermixed;
    
    # simple variable expansion
    my $template = "Hello ${name}.\n";
    my %vars     = ( name => 'world' );
    print render_intermixed( $template, \%vars );
    
    # intermixed perl code
    $template = <<END;
      Oranges are not the only fruit. We also have:
      {{ foreach my $fruit ( @fruit_list ) { }}
          ${fruit}
      {{ } }}
    END
    %vars = ( 'fruit_list' => [ qw( apples pears bananas ) ] );
    print render_intermixed( $template, \%vars );
    
=head1 DESCRIPTION

A simple library for rendering data within templates, but using embedded
perl code rather than inventing a new template language with less features.
Like PHP code embedded in an HTML document, but with any kind of textual
content and perl instead.

=head1 METHODS

=head2 render_intermixed

There is only the one method, C<render_intermixed>. It is called with two
arguments:

=over

=item template

A string containing intermixed textual content and perl code.

=item hash reference

The data structure to be used when rendering the template.

=back

The contents of the hash are loaded into a L<Safe> compartment; the template
is transformed into executable perl and then evaluated in that context. Only
the variables you pass in the hashref are available to the template, it should
not be able to access your calling environment.

The method returns an array of two strings, the rendered output and the text
of any error(s).

=head1 TEMPLATE STRUCTURE

=head2 Variables

Simple variable expansion occurs when the template contains a sigil and curly
braces, like so:

    Dear ${name}, how are you? I am ${mood}.

Here the contents of the scalar variables C<$name> and C<$mood> would be
interpolated into the text.

This also works for contents of arrays and hashes, like so:

    Dear ${names[0]}, how are you? I am ${moods{'fine'}}.

=head2 Perl code

Perl code is included in the template by surrounding it with double curly
braces, like so:

    {{ my @things = sort keys %blah; }}

The code is not seen as a standalone fragment of perl, so it is possible to
continue code logic between fragments, like so:
    
    <ul>
    {{ foreach my $item ( @items ) { }}
      <li>${item}</li>
    {{ } }}
    </ul>

=head2 Escaping delimiters

In the event that a template is being incorrectly evaluated because one or 
more curly braces are being identified as code or variable delimiters when
they are not, they can be escaped with a backslash, like so:

    \${var} expands to "${var}"

    {{
        %delimiters = (
            open  => "\{{",
            close => "\}}",
        );
    }}

=head2 C<$RENDER> special variable

When compiled, C<$RENDER> is a special variable that contains the actual
output of the entire template. You can use this to inject more or alter the
final output. This can be useful to avoid breaking in and out of perl if
that would make the template harder to read.
    
    <ul>
    {{
        foreach my $item ( @items ) {
            $RENDER .= "<li>$item</li>\n";
        }
    }}
    </ul>

=head2 Error handling

If the evaluation of the code fails for any reason, the error text is
returned as the second value from the method. If both strings are empty, then
the template successfully rendered, but just rendered to nothing.

$RENDER

=head1 SEE ALSO

L<Text::Template>, which was a heavy influence upon this module. In many ways
it is superior, except in seeing every fragment of code as to be evaluated
stand-alone.

=head1 AUTHOR

  Mark Norman Francis: L<norm@cackhanded.net>,
  L<http://marknormanfrancis.com/>.

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Mark Norman Francis, all rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
