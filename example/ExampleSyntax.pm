package ExampleSyntax;

BEGIN {
    push @INC, '../lib';
}

use strict;
use warnings;
use Devel::Declare::Lexer qw/ debug /; 

BEGIN {
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
}

sub import
{
    my $caller = caller;
    Devel::Declare::Lexer::import_for($caller, "debug");
}

1;
