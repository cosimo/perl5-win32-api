package Win32::API;

# See the bottom of this file for the POD documentation.  Search for the
# string '=head'.

#######################################################################
#
# Win32::API - Perl Win32 API Import Facility
# 
# Version: 0.20 
# Date: 24 Oct 2000
# Author: Aldo Calpini <dada@perl.it>
#######################################################################

require Exporter;       # to export the constants to the main:: space
require DynaLoader;     # to dynuhlode the module.
@ISA = qw( Exporter DynaLoader );

#######################################################################
# This AUTOLOAD is used to 'autoload' constants from the constant()
# XS function.  If a constant is not found then control is passed
# to the AUTOLOAD in AutoLoader.
#

sub AUTOLOAD {
    my($constname);
    ($constname = $AUTOLOAD) =~ s/.*:://;
    #reset $! to zero to reset any current errors.
    $!=0;
    my $val = constant($constname, @_ ? $_[0] : 0);
    if ($! != 0) {
        if ($! =~ /Invalid/) {
            $AutoLoader::AUTOLOAD = $AUTOLOAD;
            goto &AutoLoader::AUTOLOAD;
        } else {
            ($pack,$file,$line) = caller;
            die "Your vendor has not defined Win32::API macro $constname, used at $file line $line.";
        }
    }
    eval "sub $AUTOLOAD { $val }";
    goto &$AUTOLOAD;
}


#######################################################################
# STATIC OBJECT PROPERTIES
#
$VERSION = "0.20";

# some package-global hash to 
# keep track of the imported 
# libraries and procedures
%Libraries = ();
%Procedures = ();

#######################################################################
# dynamically load in the API extension module.
#
bootstrap Win32::API;

#######################################################################
# PUBLIC METHODS
#
sub new {
    my($class, $dll, $proc, $in, $out) = @_;
    my $hdll;   
    my $self = {};
  
    # avoid loading a library more than once
    if(exists($Libraries{$dll})) {
        # print "Win32::API::new: Library '$dll' already loaded, handle=$Libraries{$dll}\n";
        $hdll = $Libraries{$dll};
    } else {
        # print "Win32::API::new: Loading library '$dll'\n";
        $hdll = Win32::API::LoadLibrary($dll);
        $Libraries{$dll} = $hdll;
    }

    # if the dll can't be loaded, set $! to Win32's GetLastError()
    if(!$hdll) {
        $! = Win32::GetLastError();
        return undef;
    }

    # first try to import the function of given name...
    my $hproc = Win32::API::GetProcAddress($hdll, $proc);

    # ...then try appending either A or W (for ASCII or Unicode)
    if(!$hproc) {
        $proc .= (IsUnicode() ? "W" : "A");
        # print "Win32::API::new: procedure not found, trying '$proc'...\n";
        $hproc = Win32::API::GetProcAddress($hdll, $proc);
    }

    # ...if all that fails, set $! accordingly
    if(!$hproc) {
        $! = Win32::GetLastError();
        return undef;
    }
    
    # ok, let's stuff the object
    $self->{dll} = $hdll;
    $self->{dllname} = $dll;
    $self->{proc} = $hproc;

	my @in_params = ();
	if(ref($in) eq 'ARRAY') {
		foreach (@$in) {
			push(@in_params, 1) if /[NL]/i;
			push(@in_params, 2) if /P/i;
			push(@in_params, 3) if /I/i;        
			push(@in_params, 4) if /F/i;
			push(@in_params, 5) if /D/i;
			push(@in_params, 22) if /B/i;
			push(@in_params, 101) if /C/i;
		}	
	} else {
		my @in = split '', $in;
		foreach (@in) {
			push(@in_params, 1) if /[NL]/i;
			push(@in_params, 2) if /P/i;
			push(@in_params, 3) if /I/i;        
			push(@in_params, 4) if /F/i;
			push(@in_params, 5) if /D/i;
			push(@in_params, 22) if /B/i;
			push(@in_params, 101) if /C/i;
		}			
	}
	$self->{in} = \@in_params;

    if($out =~ /[NL]/i) {
        $self->{out} = 1;
    } elsif($out =~ /P/i) {
        $self->{out} = 2;
    } elsif($out =~ /I/i) {
        $self->{out} = 3;
    } elsif($out =~ /F/i) {
        $self->{out} = 4;
    } elsif($out =~ /D/i) {
        $self->{out} = 5;
    } else {
        $self->{out} = 0;
    }

    # keep track of the imported function
    $Libraries{$dll} = $hdll;
    $Procedures{$dll}++;

    # cast the spell
    bless($self, $class);
    return $self;
}


#######################################################################
# PRIVATE METHODS
#
sub DESTROY {
    my($self) = @_;

    # decrease this library's procedures reference count
    $Procedures{$self->{dllname}}--;

    # once it reaches 0, free it
    if($Procedures{$self->{dllname}} == 0) {
        # print "Win32::API::DESTROY: Freeing library '$self->{dllname}'\n";
        Win32::API::FreeLibrary($Libraries{$self->{dllname}});
        delete($Libraries{$self->{dllname}});
    }    
}

#Currently Autoloading is not implemented in Perl for win32
# Autoload methods go after __END__, and are processed by the autosplit program.

1;
__END__


=head1 NAME

Win32::API - Perl Win32 API Import Facility

=head1 SYNOPSIS

  use Win32::API;
  $function = new Win32::API(
      $library, $functionname, \@argumenttypes, $returntype,
  );
  $return = $function->Call(@arguments);

=head1 ABSTRACT

With this module you can import and call arbitrary functions
from Win32's Dynamic Link Libraries (DLL), without having
to write an XS extension. Note, however, that this module 
can't do anything (parameters input and output is limited 
to simpler cases), and anyway a regular XS extension is
always safer and faster. 

The current version of Win32::API is available at my website:

  http://dada.perl.it/

It's also available on your nearest CPAN mirror (but allow a few days 
for worldwide spreading of the latest version) reachable at:

  http://www.perl.com/CPAN/authors/Aldo_Calpini/

A short example of how you can use this module (it just gets the PID of 
the current process, eg. same as Perl's internal C<$$>):

    use Win32::API;
    $GetPID = new Win32::API("kernel32", "GetCurrentProcessId", '', 'N');
    $PID = $GetPID->Call();

The possibilities are nearly infinite (but not all are good :-).
Enjoy it.


=head1 CREDITS

All the credits go to Andrea Frosini 
for the neat assembler trick that makes this thing work.
A big thank you also to Gurusamy Sarathy for his
unvaluable help in XS development, and to all the Perl community for
being what it is.


=head1 DESCRIPTION

To use this module put the following line at the beginning of your script:

    use Win32::API;

You can now use the C<new()> function of the Win32::API module to create a
new API object (see L<IMPORTING A FUNCTION>) and then invoke the 
C<Call()> method on this object to perform a call to the imported API
(see L<CALLING AN IMPORTED FUNCTION>).

=head2 IMPORTING A FUNCTION

You can import a function from a 32 bit Dynamic Link Library (DLL) file 
with the C<new()> function. This will create a Perl object that contains the
reference to that function, which you can later C<Call()>.
You need to pass 4 parameters:

=over 4

=item 1.
The name of the library from which you want to import the function.

=item 2.
The name of the function (as exported by the library).

=item 3.
The number and types of the arguments the function expects as input.

=item 4.
The type of the value returned by the function.

=back

To better explain their meaning, let's suppose that we
want to import and call the Win32 API C<GetTempPath()>.
This function is defined in C as:

    DWORD WINAPI GetTempPathA( DWORD nBufferLength, LPSTR lpBuffer );

This is documented in the B<Win32 SDK Reference>; you can look
for it on the Microsoft's WWW site, or in your C compiler's 
documentation, if you own one.

=over 4

=item B<1.>

The first parameter is the name of the library file that 
exports this function; our function resides in the F<KERNEL32.DLL>
system file.
When specifying this name as parameter, the F<.DLL> extension
is implicit, and if no path is given, the file is searched through
a couple of directories, including: 

=over 4

=item 1. The directory from which the application loaded. 

=item 2. The current directory. 

=item 3. The Windows system directory (eg. c:\windows\system or system32).

=item 4. The Windows directory (eg. c:\windows).

=item 5. The directories that are listed in the PATH environment variable. 

=back

So, you don't have to write F<C:\windows\system\kernel32.dll>; 
only F<kernel32> is enough:

    $GetTempPath = new Win32::API('kernel32', ...

=item B<2.>

Now for the second parameter: the name of the function.
It must be written exactly as it is exported 
by the library (case is significant here). 
If you are using Windows 95 or NT 4.0, you can use the B<Quick View> 
command on the DLL file to see the function it exports. 
Remember that you can only import functions from 32 bit DLLs:
in Quick View, the file's characteristics should report
somewhere "32 bit word machine"; as a rule of thumb,
when you see that all the exported functions are in upper case,
the DLL is a 16 bit one and you can't use it. 
If their capitalization looks correct, then it's probably a 32 bit
DLL.

Also note that many Win32 APIs are exported twice, with the addition of
a final B<A> or B<W> to their name, for - respectively - the ASCII 
and the Unicode version.
When a function name is not found, Win32::API will actually append
an B<A> to the name and try again; if the extension is built on a
Unicode system, then it will try with the B<W> instead.
So our function name will be:

    $GetTempPath = new Win32::API('kernel32', 'GetTempPath', ...

In our case C<GetTempPath> is really loaded as C<GetTempPathA>.

=item B<3.>

The third parameter, the input parameter list, specifies how many 
arguments the function wants, and their types. It can be passed as
a single string, in which each character represents one parameter, 
or as a list reference. The following forms are valid:

    "abcd"
    [a, b, c, d]
    \@LIST

But those are not:

    (a, b, c, d)
    @LIST

The number of characters, or elements in the list, specifies the number 
of parameters, and each character or element specifies the type of an 
argument; allowed types are:

=over 4

=item C<I>: 
value is an integer

=item C<N>: 
value is a number (long)

=item C<F>: 
value is a floating point number (float)

=item C<D>: 
value is a double precision number (double)

=item C<P>: 
value is a pointer (to a string, structure, etc...)

=back

Our function needs two parameters: a number (C<DWORD>) and a pointer to a 
string (C<LPSTR>):

    $GetTempPath = new Win32::API('kernel32', 'GetTempPath', 'NP', ...

=item B<4.>

The fourth and final parameter is the type of the value returned by the 
function. It can be one of the types seen above, plus another type named B<V> 
(for C<void>), used for functions that do not return a value.
In our example the value returned by GetTempPath() is a C<DWORD>, so 
our return type will be B<N>:

    $GetTempPath = new Win32::API('kernel32', 'GetTempPath', 'NP', 'N');

Now the line is complete, and the GetTempPath() API is ready to be used
in Perl. Before calling it, you should test that $GetTempPath is 
C<defined>, otherwise either the function or the library could not be
loaded; in this case, C<$!> will be set to the error message reported 
by Windows.
Our definition, with error checking added, should then look like this:

    $GetTempPath = new Win32::API('kernel32', 'GetTempPath', 'NP', 'N');
    if(not defined $GetTempPath) {
        die "Can't import API GetTempPath: $!\n";
    }

=back

=head2 CALLING AN IMPORTED FUNCTION

To effectively make a call to an imported function you must use the
Call() method on the Win32::API object you created.
Continuing with the example from the previous paragraph, 
the GetTempPath() API can be called using the method:

    $GetTempPath->Call(...

Of course, parameters have to be passed as defined in the import phase.
In particular, if the number of parameters does not match (in the example,
if GetTempPath() is called with more or less than two parameters), 
Perl will C<croak> an error message and C<die>.

The two parameters needed here are the length of the buffer
that will hold the returned temporary path, and a pointer to the 
buffer itself.
For numerical parameters, you can use either a constant expression
or a variable, while B<for pointers you must use a variable name> (no 
Perl references, just a plain variable name).
Also note that B<memory must be allocated before calling the function>,
just like in C.
For example, to pass a buffer of 80 characters to GetTempPath(),
it must be initialized before with:

    $lpBuffer = " " x 80;

This allocates a string of 80 characters. If you don't do so, you'll
probably get C<Runtime exception> errors, and generally nothing will 
work. The call should therefore include:

    $lpBuffer = " " x 80;
    $GetTempPath->Call(80, $lpBuffer);

And the result will be stored in the $lpBuffer variable.
Note that you don't need to pass a reference to the variable
(eg. you B<don't need> C<\$lpBuffer>), even if its value will be set 
by the function. 

A little problem here is that Perl does not trim the variable, 
so $lpBuffer will still contain 80 characters in return; the exceeding 
characters will be spaces, because we said C<" " x 80>.

In this case we're lucky enough, because the value returned by 
the GetTempPath() function is the length of the string, so to get
the actual temporary path we can write:

    $lpBuffer = " " x 80;
    $return = $GetTempPath->Call(80, $lpBuffer);
    $TempPath = substr($lpBuffer, 0, $return);

If you don't know the length of the string, you can usually
cut it at the C<\0> (ASCII zero) character, which is the string
delimiter in C:

    $TempPath = ((split(/\0/, $lpBuffer))[0];
    
    # or
    
    $lpBuffer =~ s/\0.*$//;

Another note: to pass a pointer to a structure in C, you have
to pack() the required elements in a variable. And of course, to 
access the values stored in a structure, unpack() it as required.
A short example of how it works: the C<POINT> structure is defined 
in C as:

    typedef struct {
        LONG  x;
        LONG  y;
    } POINT;

Thus, to call a function that uses a C<POINT> structure you
need the following lines:

    $GetCursorPos = new Win32::API('user32', 'GetCursorPos', 'P', 'V');
    
    $lpPoint = pack('LL', 0, 0); # store two LONGs
    $GetCursorPos->Call($lpPoint);
    ($x, $y) = unpack('LL', $lpPoint); # get the actual values

The rest is left as an exercise to the reader...


=head1 AUTHOR

Aldo Calpini ( I<dada@perl.it> ).

=cut


