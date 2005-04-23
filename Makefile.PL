use 5.005;
use ExtUtils::MakeMaker;
use ExtUtils::Depends;

our $deps = ExtUtils::Depends->new('Gtk2::Ex::Geo','Gtk2','Geo::Raster');

our %pm_files = (
		 'lib/Gtk2/Ex/Geo/Renderer.pm'   => '$(INST_LIBDIR)/Renderer.pm',
		 'lib/Gtk2/Ex/Geo/Overlay.pm'    => '$(INST_LIBDIR)/Overlay.pm',
		 'lib/Gtk2/Ex/Geo/Glue.pm'       => '$(INST_LIBDIR)/Glue.pm',
		 'lib/Gtk2/Ex/Geo.pm'            => '$(INST_LIBDIR)/../Geo.pm',
);

$deps->add_pm (%pm_files);

$deps->add_xs('lib/Gtk2/Ex/Geo/Renderer.xs');

WriteMakefile(
	      NAME              => 'Gtk2::Ex::Geo',
	      VERSION_FROM      => 'lib/Gtk2/Ex/Geo.pm', # finds $VERSION
	      PREREQ_PM         => {}, # e.g., Module::Name => 1.1
	      ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
#	       (
	       (ABSTRACT_FROM  => 'lib/Gtk2/Ex/Geo.pm', # retrieve abstract from module
		AUTHOR         => 'Ari Jolma <ari.jolma @ tkk.fi>') : ()),
	      $deps->get_makefile_vars,
	      );

# -o on the compiler command line...
package MY;
use Cwd;
sub const_cccmd {
    my $inherited = shift->SUPER::const_cccmd(@_);
    $inherited .= ' -o $@';
    $inherited;
}
