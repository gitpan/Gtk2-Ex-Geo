use 5.005;
use Config;
use ExtUtils::MakeMaker;

my %missing_modules;

$missing_modules{chk_module('ExtUtils::Depends')} = 1;
$missing_modules{chk_module('ExtUtils::PkgConfig')} = 1;
$missing_modules{chk_module('Gtk2::GladeXML')} = 1;
$missing_modules{chk_module('Graphics::ColorUtils')} = 1;
$missing_modules{chk_module('Geo::OGC::Geometry')} = 1;

delete $missing_modules{''};

my @missing_modules = keys %missing_modules;
warn "Following required modules are missing: @missing_modules\n" if @missing_modules;

require ExtUtils::Depends;
require ExtUtils::PkgConfig;

my($inc,$libs,$cflags) = ('','','');

my @packages = ('gdk-pixbuf-2.0');

for $package (@packages) {
    print "Checking for $package: ";
    my($c,$l);
    if ($package eq 'gdal' and $^O ne 'MSWin32') {
	$c = `gdal-config --cflags`;
	chomp $c;
	$l = `gdal-config --libs`;
	chomp $l;
    } else {
	%pkg_info = ExtUtils::PkgConfig->find ($package);
	$c = $pkg_info{cflags};
	$l = $pkg_info{libs};
    }
    $cflags .= " $c";
    if ($^O eq "MSWin32") {
	my @a = split /\s+/,$l;
	for (@a) {
	    if (/^-l/ and !(/.dll/) and !(/-lm/) and !(/^-lws2/) and !(/^-lgdi/)) {
		$_ .= '.dll.a';
	    }
	}
	$l = join(' ',@a);
    }
    $libs .= " $l";
    print "ok\n";
}

our $deps = ExtUtils::Depends->new('Gtk2::Ex::Geo', 'Gtk2');

our %pm_files = (
		 'lib/Gtk2/Ex/Geo/Overlay.pm'      => '$(INST_LIBDIR)/Geo/Overlay.pm',
		 'lib/Gtk2/Ex/Geo/Glue.pm'         => '$(INST_LIBDIR)/Geo/Glue.pm',
		 'lib/Gtk2/Ex/Geo/TreeDumper.pm'   => '$(INST_LIBDIR)/Geo/TreeDumper.pm',
		 'lib/Gtk2/Ex/Geo/DialogMaster.pm' => '$(INST_LIBDIR)/Geo/DialogMaster.pm',
		 'lib/Gtk2/Ex/Geo/Layer.pm'        => '$(INST_LIBDIR)/Geo/Layer.pm',
		 'lib/Gtk2/Ex/Geo/Dialogs.pm'      => '$(INST_LIBDIR)/Geo/Dialogs.pm',
		 'lib/Gtk2/Ex/Geo.pm'              => '$(INST_LIBDIR)/Geo.pm',
);

$deps->add_pm (%pm_files);
$deps->add_xs('lib/Gtk2/Ex/Geo.xs');
if ($^O eq 'MSWin32') {
    $libs .= $deps->_find_extra_libs;
}
$deps->set_libs($libs);

@for_windows = ();
if ($^O eq 'MSWin32') {
    $lddlflags = $Config{lddlflags};
    $lddlflags =~ s/-mdll/-shared/;
    @for_windows = (LDDLFLAGS => $lddlflags,
		    dynamic_lib=>{OTHERLDFLAGS=>"-Wl,--out-implib=blib\\arch\\auto\\Gtk2\\Ex\\Geo.dll.a "});
}

$deps->install (qw(lib/Gtk2/Ex/gtk2-ex-geo.h));
$deps->save_config ('Files.pm');

WriteMakefile(
	      NAME              => 'Gtk2::Ex::Geo',
	      VERSION_FROM      => 'lib/Gtk2/Ex/Geo.pm',
	      PREREQ_PM         => {}, # e.g., Module::Name => 1.1
	      (
	       $] >= 5.005 ?     ## Add these new keywords supported since 5.005
	       (
		ABSTRACT_FROM  => 'lib/Gtk2/Ex/Geo.pm', # retrieve abstract from module
		AUTHOR         => 'Ari Jolma <ari.jolma @ tkk.fi>'
		) : 
	       ()
	       ),
	      CCFLAGS => $cflags,
	      $deps->get_makefile_vars,
	      @for_windows
	      );

sub chk_module {
    my $pkg = shift;
    print "Checking for $pkg:";
    eval { 
	my $p; 
	($p = $pkg . ".pm") =~ s#::#/#g; 
	require $p; 
    };
    if ($@) {
	print " failed\n";
	return $pkg;
    } else {
	print " ok\n";
	return '';
    }
}

# -o on the compiler command line...
package MY;
use Cwd;
sub const_cccmd {
    my $inherited = shift->SUPER::const_cccmd(@_);
    $inherited .= ' -o $@';
    $inherited;
}

sub postamble {
    my $ret = '';
    my $lib = 'lib/Gtk2/Ex/Geo/';
    $lib = "lib/Gtk2/Ex/Geo/";
    for ('Glue', 'Dialogs') {
	$ret .= "\n$lib$_.pm: $lib$_.pm.in $lib$_.glade\n";
	if ($^O eq 'MSWin32') {
	} else {
	    $ret .= "\tif [ -f $lib$_.pm ]; then chmod u+w $lib$_.pm; fi\n\n";
	}
	my $l = $lib;
	if ($^O eq 'MSWin32') {
	    $l =~ s/\//\\/g;
	    $ret .= "\tcopy $l$_.pm.in+$l$_.glade $l$_.pm\n";
	} else {
	    $ret .= "\tcat $l$_.pm.in $l$_.glade >$l$_.pm\n";
	    $ret .= "\tchmod a-w $lib$_.pm\n\n"; # to remember to edit .pm.in :)
	}
    }
    return $ret;
}

# this probably needs to go into ExtUtils::Depends.
sub ExtUtils::Depends::_find_extra_libs {
	# right now we need this terrible hack only for windows.
	return "" unless $^O eq "MSWin32";

	my $self = shift;

	# win32 does not allow unresolved symbols in libraries, but
	# Gtk2 uses on symbols in the dll created for Glib.
	# so, we have to break all this nice abstraction and encapsulation
	# and find the actual Glib.dll and Glib.lib installed by perl when
	# the Glib module was built, and add it to the list of lib files.
	#
	# say it with me: "i hate win32."

	my $retstring = "";

	use File::Find;

	my %deps = $self->get_deps;
	foreach my $mod (keys %deps) {
	    print "find extra libs $mod\n";
	    my $m = $mod;
	    if ($m =~ /::/) {
		my @m = split /::/, $m;
		$m = pop @m;
	    }
	    print "find extra libs $m\n";
		find (sub {
		    print $File::Find::name,"\n" if /$m.dll.a/ or /lib$m.dll.a/;
			$retstring .= " ".$File::Find::name
				if /$m.dll.a/ or /lib$m.dll.a/;
		}, @INC);
	}
	#print "$retstring\n";
	return $retstring;
}
