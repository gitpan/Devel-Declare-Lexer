package ExampleSyntax;

BEGIN {
    push @INC, '../lib';
}

use strict;
use warnings;
use Devel::Declare::Lexer qw/ debug function has /; 

BEGIN {
    #$Devel::Declare::Lexer::DEBUG = 1;
    Devel::Declare::Lexer::lexed(debug => sub {
        my ($stream_r) = @_;
        my @stream = @$stream_r;

        my $string = $stream[2]; # keyword [whitespace] "string"

        my @ns = ();
        tie @ns, "Devel::Declare::Lexer::Stream";

        push @ns, (
            new Devel::Declare::Lexer::Token::Declarator( value => 'debug' ),
            new Devel::Declare::Lexer::Token::Whitespace( value => ' ' ),
            new Devel::Declare::Lexer::Token( value => 'print' ),
            new Devel::Declare::Lexer::Token::Whitespace( value => ' ' ),
            $string,
            new Devel::Declare::Lexer::Token::EndOfStatement,
            new Devel::Declare::Lexer::Token::Newline,
        );

        return \@ns;
    });
    Devel::Declare::Lexer::lexed(function => sub {
        my ($stream_r) = @_;

        my @stream = @{$stream_r};
        my @start = @stream[0..1];
        my @end = @stream[2..$#stream];

        my @output;
        tie @output, 'Devel::Declare::Lexer::Stream';

        shift @stream; # remove keyword
        shift @stream; # remove whitespace
        my $name = shift @stream; # get function name

        my @vars = ();
        while($stream[0]->{value} !~ /{/) {
            my $tok = shift @stream;
            next if ref($tok) =~ /Devel::Declare::Lexer::Token::(Left|Right)Bracket/;
            next if ref($tok) =~ /Devel::Declare::Lexer::Token::Operator/;
            next if ref($tok) =~ /Devel::Declare::Lexer::Token::Whitespace/;
           
            if(ref($tok) =~ /Devel::Declare::Lexer::Token::Variable/) {
                push @vars, [
                    $tok,
                    shift @stream
                ];
            }
        }

        push @output, @start;
        # Terminate the existing statement
        push @output, new Devel::Declare::Lexer::Token::Bareword( value => '1' );
        push @output, new Devel::Declare::Lexer::Token::EndOfStatement( value => ';' );

        # Add the sub keyword/name
        push @output, new Devel::Declare::Lexer::Token::Bareword( value => 'sub' );
        push @output, new Devel::Declare::Lexer::Token::Whitespace( value => ' ' );
        push @output, $name;
        push @output, new Devel::Declare::Lexer::Token::Whitespace( value => ' ' );

        # Output the 'my (...) = @_;' line
        push @output, new Devel::Declare::Lexer::Token::Whitespace( value => ' ' );
        push @output, shift @stream; # consume the {
        push @output, new Devel::Declare::Lexer::Token::Bareword( value => 'my' );
        push @output, new Devel::Declare::Lexer::Token::Whitespace( value => ' ' );
        push @output, new Devel::Declare::Lexer::Token::LeftBracket( value => '(' );
        for my $var (@vars) {
            push @output, @$var;
            push @output, new Devel::Declare::Lexer::Token::Operator( value => ',' );
        }
        pop @output; # one too many commas
        push @output, new Devel::Declare::Lexer::Token::RightBracket( value => ')' );
        push @output, new Devel::Declare::Lexer::Token::Whitespace( value => ' ' );
        push @output, new Devel::Declare::Lexer::Token::Operator( value => '=' );
        push @output, new Devel::Declare::Lexer::Token::Whitespace( value => ' ' );
        push @output, new Devel::Declare::Lexer::Token::Variable( value => '@_' );
        push @output, new Devel::Declare::Lexer::Token::EndOfStatement( value => ';' );

        # Stick everything else back on the end
        push @output, @stream;

        return \@output;
    });
    Devel::Declare::Lexer::lexed(has => sub {
        my ($stream_r) = @_;

        my @stream = @{$stream_r};
        my @start = @stream[0..1];
        my @end = @stream[2..$#stream];

        my @output;
        tie @output, 'Devel::Declare::Lexer::Stream';

        shift @stream; # remove keyword
        while(ref($stream[0]) =~ /Devel::Declare::Lexer::Token::Whitespace/) {
            shift @stream;
        }

        # Get the name (could be string or variable)
        my $name = shift @stream;
        if(ref($name =~ /Devel::Declare::Lexer::Token::Variable/)) {
            $name = shift @stream;
        }
        
        # Consume whitespace and => 
        while($stream[0]->{value} !~ /{/) {
            shift @stream;
        }

        push @output, @start;
        # Terminate the existing statement
        push @output, new Devel::Declare::Lexer::Token::Bareword( value => '1' );
        push @output, new Devel::Declare::Lexer::Token::EndOfStatement( value => ';' );

        # Setup the property store
        shift @stream; # consume the {
        push @output, new Devel::Declare::Lexer::Token::Bareword( value => 'my' );
        push @output, new Devel::Declare::Lexer::Token::Whitespace( value => ' ' );
        push @output, new Devel::Declare::Lexer::Token::Variable( value => '$' );
        push @output, new Devel::Declare::Lexer::Token::Bareword( value => '__props_lexer_' . $name->{value} );
        push @output, new Devel::Declare::Lexer::Token::Whitespace( value => ' ' );
        push @output, new Devel::Declare::Lexer::Token::Operator( value => '=' );
        push @output, new Devel::Declare::Lexer::Token::Whitespace( value => ' ' );
        push @output, new Devel::Declare::Lexer::Token::LeftBracket( value => '{' );

        my $nest = 0;
        while(@stream) {
            if(ref($stream[0]) =~ /Devel::Declare::Lexer::Token::LeftBracket/) {
                $nest++;
            }elsif(ref($stream[0]) =~ /Devel::Declare::Lexer::Token::RightBracket/) {
                last if $nest == 0 && $stream[0]->{value} =~ /}/;
                $nest--;
            }
            push @output, shift @stream; # consume tokens
        }

        push @output, shift @stream; # consume the }
        push @output, new Devel::Declare::Lexer::Token::EndOfStatement(value => ';');

        # setup the value
        push @output, new Devel::Declare::Lexer::Token::Variable( value => '$' );
        push @output, new Devel::Declare::Lexer::Token::Bareword( value => '__props_lexer_' . $name->{value} );
        push @output, new Devel::Declare::Lexer::Token::Operator( value => '-' );
        push @output, new Devel::Declare::Lexer::Token::Operator( value => '>' );
        push @output, new Devel::Declare::Lexer::Token::LeftBracket( value => '{' );
        push @output, new Devel::Declare::Lexer::Token::String( start => "'", end => "'", value => 'value' );
        push @output, new Devel::Declare::Lexer::Token::RightBracket( value => '}' );
        push @output, new Devel::Declare::Lexer::Token::Operator( value => '=' );
        push @output, new Devel::Declare::Lexer::Token::Variable( value => '$' );
        push @output, new Devel::Declare::Lexer::Token::Bareword( value => '__props_lexer_' . $name->{value} );
        push @output, new Devel::Declare::Lexer::Token::Operator( value => '-' );
        push @output, new Devel::Declare::Lexer::Token::Operator( value => '>' );
        push @output, new Devel::Declare::Lexer::Token::LeftBracket( value => '{' );
        push @output, new Devel::Declare::Lexer::Token::String( start => "'", end => "'", value => 'default' );
        push @output, new Devel::Declare::Lexer::Token::RightBracket( value => '}' );
        push @output, new Devel::Declare::Lexer::Token::EndOfStatement(value => ';');

        # Add the sub keyword/name
        push @output, new Devel::Declare::Lexer::Token::Bareword( value => 'sub' );
        push @output, new Devel::Declare::Lexer::Token::Whitespace( value => ' ' );
        push @output, new Devel::Declare::Lexer::Token::Bareword( value => $name->{value} );
        push @output, new Devel::Declare::Lexer::Token::Whitespace( value => ' ' );
        push @output, new Devel::Declare::Lexer::Token::LeftBracket( value => '{' );

        push @output, new Devel::Declare::Lexer::Token::Bareword( value => 'my' );
        push @output, new Devel::Declare::Lexer::Token::Whitespace( value => ' ' );
        push @output, new Devel::Declare::Lexer::Token::LeftBracket( value => '(' );
        push @output, new Devel::Declare::Lexer::Token::Variable( value => '$' );
        push @output, new Devel::Declare::Lexer::Token::Bareword( value => 'value' );
        push @output, new Devel::Declare::Lexer::Token::LeftBracket( value => ')' );
        push @output, new Devel::Declare::Lexer::Token::Operator( value => '=' );
        push @output, new Devel::Declare::Lexer::Token::Variable( value => '@' );
        push @output, new Devel::Declare::Lexer::Token::Bareword( value => '_' );
        push @output, new Devel::Declare::Lexer::Token::EndOfStatement(value => ';');

        push @output, new Devel::Declare::Lexer::Token::Bareword( value => 'if' );
        push @output, new Devel::Declare::Lexer::Token::LeftBracket( value => '(' );
        push @output, new Devel::Declare::Lexer::Token::Variable( value => '$' );
        push @output, new Devel::Declare::Lexer::Token::Bareword( value => 'value' );
        push @output, new Devel::Declare::Lexer::Token::LeftBracket( value => ')' );
        push @output, new Devel::Declare::Lexer::Token::LeftBracket( value => '{' );
        push @output, new Devel::Declare::Lexer::Token::Variable( value => '$' );
        push @output, new Devel::Declare::Lexer::Token::Bareword( value => '__props_lexer_' . $name->{value} );
        push @output, new Devel::Declare::Lexer::Token::Operator( value => '-' );
        push @output, new Devel::Declare::Lexer::Token::Operator( value => '>' );
        push @output, new Devel::Declare::Lexer::Token::LeftBracket( value => '{' );
        push @output, new Devel::Declare::Lexer::Token::String( start => "'", end => "'", value => 'value' );
        push @output, new Devel::Declare::Lexer::Token::RightBracket( value => '}' );
        push @output, new Devel::Declare::Lexer::Token::Operator( value => '=' );
        push @output, new Devel::Declare::Lexer::Token::Variable( value => '$' );
        push @output, new Devel::Declare::Lexer::Token::Bareword( value => 'value' );
        push @output, new Devel::Declare::Lexer::Token::LeftBracket( value => '}' );
        push @output, new Devel::Declare::Lexer::Token::EndOfStatement(value => ';');

        # Return the value
        push @output, new Devel::Declare::Lexer::Token::Bareword( value => 'return' );
        push @output, new Devel::Declare::Lexer::Token::Whitespace( value => ' ' );
        push @output, new Devel::Declare::Lexer::Token::Variable( value => '$' );
        push @output, new Devel::Declare::Lexer::Token::Bareword( value => '__props_lexer_' . $name->{value} );
        push @output, new Devel::Declare::Lexer::Token::Operator( value => '-' );
        push @output, new Devel::Declare::Lexer::Token::Operator( value => '>' );
        push @output, new Devel::Declare::Lexer::Token::LeftBracket( value => '{' );
        push @output, new Devel::Declare::Lexer::Token::String( start => "'", end => "'", value => 'value' );
        push @output, new Devel::Declare::Lexer::Token::RightBracket( value => '}' );
        push @output, new Devel::Declare::Lexer::Token::EndOfStatement(value => ';');

        # Close the sub
        push @output, new Devel::Declare::Lexer::Token::RightBracket( value => '}' );
        
        # Stick everything else back on the end
        push @output, @stream;
        return \@output;
    });
}

sub import
{
    my $caller = caller;
    Devel::Declare::Lexer::import_for($caller, "debug");
    Devel::Declare::Lexer::import_for($caller, "function");
    Devel::Declare::Lexer::import_for($caller, "has");
}

1;
