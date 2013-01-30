package Devel::Declare::Lexer;

use strict;
use warnings;
use v5.14.2;

our $VERSION = '0.001';

use Data::Dumper;
use Devel::Declare;
use Devel::Declare::Lexer::Stream;
use Devel::Declare::Lexer::Token;
use Devel::Declare::Lexer::Token::Comma;
use Devel::Declare::Lexer::Token::Declarator;
use Devel::Declare::Lexer::Token::EndOfStatement;
use Devel::Declare::Lexer::Token::LeftBracket;
use Devel::Declare::Lexer::Token::Newline;
use Devel::Declare::Lexer::Token::Operator;
use Devel::Declare::Lexer::Token::RightBracket;
use Devel::Declare::Lexer::Token::String;
use Devel::Declare::Lexer::Token::Variable;
use Devel::Declare::Lexer::Token::Whitespace;

use vars qw/ @ISA $DEBUG /;
@ISA = ();
$DEBUG = 0;

sub import
{
    my $class = shift;
    my $caller = caller;

    import_for($caller, @_);
}

sub import_for
{
    my ($caller, @args) = @_;
    my $class = shift;

    no strict 'refs';
    my @consts;

    my %tags = map { $_ => 1 } @args;
    if($tags{":debug"}) {
        $DEBUG = 1;
    }
    if($tags{":lexer_test"}) {
        $DEBUG and say STDERR "Adding 'lexer_test' to keyword list";

        push @consts, "lexer_test";
    }

    my @names = @_;
    for my $name (@names) {
        next if $name =~ /:/;
        $DEBUG and say STDERR "Adding '$name' to keyword list";

        push @consts, $name;
    }

    for my $word (@consts) {
        $DEBUG and say STDERR "Injecting '$word' into '$caller'";
        Devel::Declare->setup_for(
            $caller,
            {
                $word => { const => \&lexer }
            }
        );
        *{$caller.'::'.$word} = sub () { 1; };
    }
}

my %named_lexed_stack = ();
sub lexed
{
    my ($key, $callback) = @_;
    $DEBUG and say STDERR "Registered callback for keyword '$key'";
    $named_lexed_stack{$key} = $callback;
}

sub call_lexed
{
    my ($name, $stream) = @_;

    $DEBUG and say STDERR "Checking for callbacks for keyword '$name'";
    $DEBUG and say STDERR Dumper $stream;

    my $callback = $named_lexed_stack{$name};
    if($callback) {
        $DEBUG and say STDERR "Found callback '$callback' for keyword '$name'";
        $stream = &$callback($stream);
    }

    $DEBUG and say STDERR Dumper $stream;

    return $stream;
}

sub lexer
{
    my ($symbol, $offset) = @_;

    $DEBUG and print "=" x 80, "\n";

    my $linestr = Devel::Declare::get_linestr;
    my $original_linestr = $linestr;
    my $original_offset = $offset;
    $DEBUG and say STDERR "Starting with linestr '$linestr'";

    my @tokens = ();
    tie @tokens, "Devel::Declare::Lexer::Stream";
    my ($len, $tok);
    my $eoleos = 0;
    my %lineoffsets;
    my $line = 1;

    # Skip the declarator
    $offset += Devel::Declare::toke_move_past_token($offset);
    push @tokens, new Devel::Declare::Lexer::Token::Declarator( value => $symbol );
    $DEBUG and say STDERR "Skipped declarator '$symbol'";

    my $skipspace = sub {
        $len = Devel::Declare::toke_skipspace($offset);
        if($len > 0) {
            $tok = substr($linestr, $offset, $len);
            $DEBUG and say STDERR "Skipped whitespace '$tok', length [$len]";
            push @tokens, new Devel::Declare::Lexer::Token::Whitespace( value => $tok );
            $offset += $len;

            if($tok =~ /\n/) {
                $DEBUG and say STDERR "Got end of line in skipspace, unusual circumstances";
                # FIXME really?
                Devel::Declare::clear_lex_stuff;

                $linestr = Devel::Declare::get_linestr;
                $original_linestr = $linestr;

                #if($line == 1) {
                #    $lineoffsets{1} = (length $symbol) + 1;
                #};
                #$line++;
                #$lineoffsets{$line} = $offset;

                $DEBUG and say STDERR "Refreshed linestr [$linestr]";
            }
        } elsif ($len < 0) {
            $DEBUG and say STDERR "Got end of line in skipspace";
        } elsif ($len == 0) {
            $DEBUG and say STDERR "No whitespace skipped";
        }
        return $len;
    };

    # get the message
    $DEBUG and say STDERR "Linestr length [", length $linestr, "]";
    while($offset < length $linestr) {
        $DEBUG and say STDERR "Offset[$offset], Remaining[", substr($linestr, $offset), "]";

        if(substr($linestr, $offset, 1) eq ';') {
            $DEBUG and say STDERR "Got end of statement";
            push @tokens, new Devel::Declare::Lexer::Token::EndOfStatement;
            $offset += 1;
            $eoleos = 1;
            next;
        }

        if(substr($linestr, $offset, 2) eq "\n") {
            $DEBUG and say STDERR "Got end of line in loop (current line $line)";
            push @tokens, new Devel::Declare::Lexer::Token::Newline;
            $offset += 1;

            last if $eoleos;
            $eoleos = 0;

            # we're actually consuming a new line now

            # We don't use skipspace here - it does too much!
            #&$skipspace;
            $len = Devel::Declare::toke_skipspace($offset);
            if($len != 0) {
                # TODO it seems odd that we don't add $len to the
                # offset... this might come back to bite us later!
                #$offset += $len - 6;
                $DEBUG and say STDERR "Skipped $len whitespace following EOL, not added to \$offset";
            }

            Devel::Declare::clear_lex_stuff;

            $linestr = Devel::Declare::get_linestr;
            $original_linestr = $linestr;

            if($line == 1) {
                $lineoffsets{1} = (length $symbol) + 1;
            };
            $line++;
            $lineoffsets{$line} = $offset;

            $DEBUG and say STDERR "Refreshed linestr [$linestr]";
            next;
        }

        last if &$skipspace < 0;

        if(substr($linestr, $offset, 1) =~ /(\{|\[|\()/) {
            my $b = substr($linestr, $offset, 1);
            push @tokens, new Devel::Declare::Lexer::Token::LeftBracket( value => $b );
            $DEBUG and say STDERR "Got left bracket '$b'";
            $offset += 1;
            next;
        }
        if(substr($linestr, $offset, 1) =~ /(\}|\]|\))/) {
            my $b = substr($linestr, $offset, 1);
            push @tokens, new Devel::Declare::Lexer::Token::RightBracket( value => $b );
            $DEBUG and say STDERR "Got right bracket '$b'";
            $offset += 1;
            next;
        }

        if(substr($linestr, $offset, 1) =~ /\\/) {
            $tok = substr($linestr, $offset, 1);
            $DEBUG and say STDERR "Got reference operator '$tok'";
            push @tokens, new Devel::Declare::Lexer::Token::Operator( value => $tok);
            $offset += 1;
            next;
        }

        if(substr($linestr, $offset, 1) =~ /(\$|\%|\@|\*)/) {
            # get the sign
            # TODO the variable name is captured later - it should probably be done here
            $tok = substr($linestr, $offset, 1);
            $DEBUG and say STDERR "Got variable '$tok'";
            push @tokens, new Devel::Declare::Lexer::Token::Variable( value => $tok );
            $offset += 1;
            next;
        }

        if(substr($linestr, $offset, 1) =~ /[!\+\-\*\/\.><=]/) {
            $tok = substr($linestr, $offset, 1);
            $DEBUG and say STDERR "Got operator '$tok'";
            push @tokens, new Devel::Declare::Lexer::Token::Operator( value => $tok );
            $offset += 1;
            next;
        }

        if(substr($linestr, $offset, 1) eq ',') {
            $DEBUG and say STDERR "Got a comma";
            push @tokens, new Devel::Declare::Lexer::Token::Comma;
            $offset += 1;
            next;
        }

        if(substr($linestr, $offset, 1) =~ /^(q|\"|\')/) {
            # FIXME need to determine string type properly
            my $strstype = substr($linestr, $offset, 1);
            my $stretype = $strstype;
            if($strstype =~ /q/) {
                $offset += 1;
                $strstype .= substr($linestr, $offset, 1);
                $stretype = substr($strstype, 1);
                $stretype =~ tr/\(/)/;
                $len = Devel::Declare::toke_scan_str($offset);
            } else {
                $len = Devel::Declare::toke_scan_str($offset);
            }
            $DEBUG and say STDERR "Got string type '$strstype', end type '$stretype'";
            $tok = Devel::Declare::get_lex_stuff;
            Devel::Declare::clear_lex_stuff;
            $DEBUG and say STDERR "Got string '$tok'";
            push @tokens, new Devel::Declare::Lexer::Token::String( start => $strstype, end => $stretype, value => $tok );
            # get a new linestr - we might have captured multiple lines
            $linestr = Devel::Declare::get_linestr;
            $offset += $len;

            # If we do have multiple lines, we'll fix line numbering at the end

            next;
        }

        $len = Devel::Declare::toke_scan_word($offset, 1);
        if($len) {
            $tok = substr($linestr, $offset, $len);
            $DEBUG and say STDERR "Got token '$tok'";
            push @tokens, new Devel::Declare::Lexer::Token( value => $tok );
            $offset += $len;
            next;
        }

    }

    # Callback (AT COMPILE TIME) to allow manipulation of the token stream before injection
    $DEBUG and say STDERR Dumper \@tokens;
    @tokens = @{call_lexed($symbol, \@tokens)};

    my $stmt = "";
    for my $token (@tokens) {
        $stmt .= $token->get;
    }

    $DEBUG and print "=" x 80, "\n";

    if($symbol =~ /^lexer_test$/) {
        $DEBUG and say STDERR "Escaping statement for variable assignment";
        $stmt =~ s/\\/\\\\/g;
        $stmt =~ s/\"/\\"/g;
        $stmt =~ s/\$/\\\$/g;
        $stmt =~ s/\n/\\n/g;
        chomp $stmt;
        $stmt = substr($stmt, 0, (length $stmt) - 2); # strip the final \\n
    } else {
        $stmt =~ s/\n//g; # remove multiline on final statement
        chomp $stmt;
    }
    $DEBUG and say STDERR "Final statement: [$stmt]";

    my @lcnt = split /\\n/, $stmt;
    my $lc = scalar @lcnt;
    my $lineadjust = $lc - $line;
    $DEBUG and say STDERR "Linecount[$lc] lines[$line] - missing $lineadjust lines";

    # we've got a new linestr, we need to re-fix all our offsets
    $DEBUG and say STDERR "\n\nStarted with linestr [$linestr]";
    use Data::Dumper;
    $DEBUG and say STDERR Dumper \%lineoffsets;

    for my $l (sort keys %lineoffsets) {
        my $sol = $lineoffsets{$l};
        last if !defined $lineoffsets{$l+1}; # don't mess with the current line, yet!
        my $eol = $lineoffsets{$l + 1} - 1;
        my $diff = $eol - $sol;
        my $substr = substr($linestr, $sol, $diff);
        $DEBUG and say STDERR "\nLine $l, sol[$sol], eol[$eol], diff[$diff], linestr[$linestr], substr[$substr]";
        substr($linestr, $sol, $diff) = " " x $diff;
    }

    # now clear up the last line
    $DEBUG and say STDERR "Still got linestr[$linestr]";
    my $sol = $line == 1 ? (length $symbol) + 1 + $original_offset : $lineoffsets{$line};
    my $eol = (length $linestr) - 1;
    my $diff = $eol - $sol;
    my $substr = substr($linestr, $sol, $diff);
    $DEBUG and say STDERR "Got substr[$substr] sol[$sol] eol[$eol] diff[$diff]";

    my $newline = "\n" x $lineadjust;
    if($symbol =~ /^lexer_test$/) {
        $newline .= "and \$lexed = \"$stmt\";";
    } else {
        $newline .= " and " . substr($stmt, length $symbol);
    }

    substr($linestr, $sol, (length $linestr) - $sol - 1) = $newline; # put the rest of the statement in

    $DEBUG and say STDERR "Got new linestr[$linestr] from original_linestr[$original_linestr]";

    $DEBUG and print "=" x 80, "\n";
    Devel::Declare::set_linestr($linestr);
}

=head1 NAME

Devel::Declare::Lexer

=head1 SYNOPSIS

    # Add :debug tag to enable debugging
    # Add :lexer_test to enable variable assignment
    # Anything not starting with : becomes a keyword
    use Devel::Declare::Lexer qw/ keyword /;

    BEGIN {
        # Create a callback for the keyword (inside a BEGIN block!)
        Devel::Declare::Lexer::lexed(keyword => sub {
            # Get the stream out (given as an arrayref)
            my ($stream_r) = @_;
            my @stream = @$stream_r;

            my $str = $stream[2]; # in the example below, the string is the 3rd token

            # Create a new stream (we could manipulate the existing one though)
            my @ns = ();
            tie @ns, "Devel::Declare::Lexer::Stream";

            # Add a few tokens to print the string 
            push @ns, (
                # You need this (for now)
                new Devel::Declare::Lexer::Token::Declarator( value => 'keyword' ),
                new Devel::Declare::Lexer::Token::Whitespace( value => ' ' ),

                # Everything else is your own custom code
                new Devel::Declare::Lexer::Token( value => 'print' ),
                new Devel::Declare::Lexer::Token::Whitespace( value => ' ' ),
                $string,
                new Devel::Declare::Lexer::Token::EndOfStatement,
                new Devel::Declare::Lexer::Token::Newline,
            );

            # Stream now contains:
            # keyword and print "This is a string";
            # keyword evaluates to 1, everything after the and gets executed

            # Return an arrayref
            return \@ns;
        });
    }

    # Use the keyword anywhere in this package
    keyword "This is a string";

=head1 DESCRIPTION

L<Devel::Declare::Lexer> makes it easier to parse code using L<Devel::Declare>
by generating a token stream from the statement and providing a callback for
you to manipulate it before its parsed by Perl.

The example in the synopsis creates a keyword named 'keyword', which accepts
a string and prints it.

Although this simple example could be done using print, say or any other simple
subroutine, L<Devel::Declare::Lexer> supports much more flexible syntax.

For example, it could be used to auto-expand subroutine declarations, e.g.
    method MethodName ( $a, @b ) {
        ... 
    }
into
    sub MethodName ($@) {
        my ($self, $a, @b) = @_;
        ...
    }

Unlike L<Devel::Declare>, there's no need to worry about parsing text and
taking care of multiline strings or code blocks - it's all done for you.

=head1 SEE ALSO

For more information about how L<Devel::Declare::Lexer>works , read the 
documentation for L<Devel::Declare>.

=head1 AUTHORS

Ian Kent - E<lt>email@iankent.co.uk<gt> - original author

http://www.iankent.co.uk/

=head1 COPYRIGHT AND LICENSE

This library is free software under the same terms as perl itself

Copyright (c) 2013 Ian Kent

Devel::Declare::Lexer is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the license for more details.

=cut

1;
