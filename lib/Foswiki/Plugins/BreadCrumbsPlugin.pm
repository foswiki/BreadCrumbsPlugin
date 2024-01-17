# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2024 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package Foswiki::Plugins::BreadCrumbsPlugin;

=begin TML

---+ package Foswiki::Plugins::BreadCrumbsPlugin

base class to hook into the foswiki core

=cut

use strict;
use warnings;

our $VERSION = '4.01';
our $RELEASE = '%$RELEASE%';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION = 'A flexible way to display breadcrumbs navigation';
our $LICENSECODE = '%$LICENSECODE%';
our $core;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean

initialize the plugin, automatically called during the core initialization process

=cut

sub initPlugin {

  Foswiki::Func::registerTagHandler(
    'BREADCRUMBS',
    sub {
      my $session = shift;
      return getCore($session)->renderBreadCrumbs(@_);
    }
  );

  my $doRecordTrail = Foswiki::Func::isTrue(Foswiki::Func::getPreferencesValue('BREADCRUMBSPLUGIN_RECORDTRAIL'), 0);
  if ($doRecordTrail) {
    getCore()->recordTrail($_[1], $_[0]);
  } else {

    #print STDERR "not recording the click path trail\n";
  }

  return 1;
}

=begin TML

---++ finishPlugin

finish the plugin and the core if it has been used,
automatically called during the core initialization process

=cut

sub finishPlugin {
  $core->finish () if defined $core;
  undef $core;
}

=begin TML

---++ getCore() -> $core

returns a singleton Foswiki::Plugins::BreadCrumbsPlugin::Core object for this plugin; a new core is allocated 
during each session request; once a core has been created it is destroyed during =finishPlugin()=

=cut

sub getCore {

  unless (defined $core) {
    require Foswiki::Plugins::BreadCrumbsPlugin::Core;
    $core = Foswiki::Plugins::BreadCrumbsPlugin::Core->new(@_);
  }

  return $core;
}

1;
