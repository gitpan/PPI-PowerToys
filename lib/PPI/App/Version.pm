package PPI::App::Version;

use 5.005;
use strict;
use File::Spec             ();
use PPI::Document          ();
use File::Find::Rule       ();
use File::Find::Rule::Perl ();

use vars qw{$VERSION};
BEGIN {
        $VERSION = '0.10';
}

sub FFR () { 'File::Find::Rule' }





#####################################################################
# Main Methods

sub main {
	my $cmd = shift @_;
	return usage(@_)  unless defined $cmd;
	return show(@_)   if $cmd eq 'show';
	return change(@_) if $cmd eq 'change';
	return error("Unknown command '$cmd'");
}

sub usage {
	print "\n";
	print "ppi_version $VERSION - Copright 2006 - 2007 Adam Kennedy\n";
	print "Usage:\n";
	print "  ppi_version show\n";
	print "  ppi_version change 0.02_03 0.54\n";
	print "\n";
	return 0;
}

sub show {
	# Find all modules and scripts below the current directory
	my @files = FFR->perl_file
	               ->in( File::Spec->curdir );
	print  "Found " . scalar(@files) . " file(s)\n";

	my $count = 0;
	foreach my $file ( @files ) {
		print "$file...";
		my $Document = PPI::Document->new( $file );
		unless ( $Document ) {
			print " failed to parse file\n";
			next;
		}

		# Does the document contain a simple version number
		my $elements = $Document->find( sub {
			# Find a $VERSION symbol
			$_[1]->isa('PPI::Token::Symbol')           or return '';
			$_[1]->content =~ m/^\$(?:\w+::)*VERSION$/ or return '';

			# It is the first thing in the statement
			$_[1]->sprevious_sibling                  and return '';

			# Followed by an "equals"
			my $equals = $_[1]->snext_sibling          or return '';
			$equals->isa('PPI::Token::Operator')       or return '';
			$equals->content eq '='                    or return '';

			# Followed by a quote
			my $quote = $equals->snext_sibling         or return '';
			$quote->isa('PPI::Token::Quote')           or return '';

			# ... which is EITHER the end of the statement
			my $next = $quote->snext_sibling           or return 1;

			# ... or is a statement terminator
			$next->isa('PPI::Token::Structure')        or return '';
			$next->content eq ';'                      or return '';

			return 1;
		} );

		unless ( $elements ) {
			print " no version\n";
			next;
		}
		if ( @$elements > 1 ) {
			error("$file contains more than one \$VERSION = 'something';");
		}
		my $element = $elements->[0];
		my $version = $element->snext_sibling->snext_sibling;
		my $version_string = $version->string;
		unless ( defined $version_string ) {
			error("Failed to get version string");
		}
		print " $version_string\n";
		$count++;
	}

	print "Found " . scalar($count) . " version(s)\n";
	print "Done.\n";
	return 0;	
}

sub change {
	my $from = shift @ARGV;
	unless ( $from and $from =~ /^[\d\._]+$/ ) {
		error("From is not a number");
	}
	my $to = shift @ARGV;
	unless ( $to and $to =~ /^[\d\._]+$/ ) {
		error("To is not a number");
	}

	$from = "'$from'";
	$to   = "'$to'";

	# Find all modules and scripts below the current directory
	my @files = FFR->perl_file
	               ->in( File::Spec->curdir );
	print  "Found " . scalar(@files) . " file(s)\n";

	my $count = 0;
	foreach my $file ( @files ) {
		print "$file...";
		if ( ! -w $file ) {
			print " no write permission\n";
			next;
		}
		my $rv = changefile( $file, $from, $to );
		if ( $rv ) {
			print " updated\n";
			$count++;
		} elsif ( defined $rv ) {
			print " skipped\n";
		} else {
			print " failed to parse file\n";
		}
	}

	print "Updated " . scalar($count) . " file(s)\n";
	print "Done.\n";
	return 0;
}





#####################################################################
# Support Functions

sub changefile {
	my ($file, $from, $to) = @_;
	my $Document = PPI::Document->new( $file ) or return undef;

	# Does the document contain a simple version number
	my $elements = $Document->find( sub {
		$_[1]->isa('PPI::Token::Quote')               or return '';
		$_[1]->content eq $from                       or return '';
		my $equals = $_[1]->sprevious_sibling         or return '';
		$equals->isa('PPI::Token::Operator')          or return '';
		$equals->content eq '='                       or return '';
		my $version = $equals->sprevious_sibling      or return '';
		$version->isa('PPI::Token::Symbol')           or return '';
		$version->content =~ m/^\$(?:\w+::)*VERSION$/ or return '';
		return 1;
		} );
	return '' unless $elements;
	if ( @$elements > 1 ) {
		error("$file contains more than one \$VERSION = '$from';");
	}
	my $element = $elements->[0];
	$element->{content} = $to;

	# Save the updated version
	unless ( $Document->save($file) ) {
		error("PPI::Document save failed");
	}

	return 1;
}

sub error {
	my $msg = shift;
	chomp $msg;
	print "\n";
	print "  $msg\n";
	print "\n";
	return 255;
}

1;
