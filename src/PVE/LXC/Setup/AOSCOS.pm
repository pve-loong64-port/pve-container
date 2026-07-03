package PVE::LXC::Setup::AOSCOS;

use strict;
use warnings;

use PVE::LXC;

use PVE::LXC::Setup::Base;

use base qw(PVE::LXC::Setup::Base);

sub new {
    my ($class, $conf, $rootdir) = @_;

    my $self = { conf => $conf, rootdir => $rootdir, version => 0 };

    $conf->{ostype} = "aoscos";

    return bless $self, $class;
}

sub template_fixup {
    my ($self, $conf) = @_;

    $self->remove_lxc_name_from_etc_hosts();

    $self->setup_systemd_disable_static_units();
}

sub setup_init {
    my ($self, $conf) = @_;

    $self->setup_systemd_preset({
        # AOSC OS disables sshd by default
        'sshd.service' => 1,
    });

    $self->setup_container_getty_service($conf);
}

sub setup_network {
    my ($self, $conf) = @_;

    $self->setup_systemd_networkd($conf);
}

1;
