package PVE::LXC::Setup::ALT;

use strict;
use warnings;

use Digest::SHA;
use Encode;

use PVE::LXC;

use PVE::LXC::Setup::Base;

use base qw(PVE::LXC::Setup::Base);

sub new {
    my ($class, $conf, $rootdir, $os_release) = @_;

    my $version = $os_release->{VERSION_ID};

    my $self = { conf => $conf, rootdir => $rootdir, version => $version };

    $conf->{ostype} = "alt";

    return bless $self, $class;
}

sub template_fixup {
    my ($self, $conf) = @_;

    $self->remove_lxc_name_from_etc_hosts();

    $self->setup_systemd_disable_static_units();
}

sub setup_init {
    my ($self, $conf) = @_;

    $self->setup_systemd_preset();

    $self->setup_container_getty_service($conf);
}

sub setup_network {
    my ($self, $conf) = @_;

    $self->setup_systemd_networkd($conf);
}

my $replacepw = sub {
    my ($self, $file, $user, $epw, $shadow) = @_;

    my $tmpfile = "$file.$$";

    eval {
        my $src = $self->ct_open_file_read($file)
            || die "unable to open file '$file' - $!";

        my $st = $self->ct_stat($src)
            || die "unable to stat file - $!";

        my $dst = $self->ct_open_file_write($tmpfile)
            || die "unable to open file '$tmpfile' - $!";

        # copy owner and permissions
        chmod $st->mode, $dst;
        chown $st->uid, $st->gid, $dst;

        my $last_change = int(time() / (60 * 60 * 24));

        while (defined(my $line = <$src>)) {
            if ($shadow) {
                $line =~ s/^${user}:[^:]*:[^:]*:/${user}:${epw}:${last_change}:/;
            } else {
                $line =~ s/^${user}:[^:]*:/${user}:${epw}:/;
            }
            print $dst $line;
        }

        $src->close() || die "close '$file' failed - $!\n";
        $dst->close() || die "close '$tmpfile' failed - $!\n";
    };
    if (my $err = $@) {
        $self->ct_unlink($tmpfile);
    } else {
        $self->ct_rename($tmpfile, $file);
        $self->ct_unlink($tmpfile); # in case rename fails
    }
};

sub set_user_password {
    my ($self, $conf, $user, $opt_password) = @_;

    my $pwfile = "/etc/passwd";

    return if !$self->ct_file_exists($pwfile);

    my $shadow = "/etc/tcb/root/shadow";

    if (defined($opt_password)) {
        if ($opt_password !~ m/^\$(?:1|2[axy]?|5|6)\$[a-zA-Z0-9.\/]{1,16}\$[a-zA-Z0-9.\/]+$/) {
            my $time = substr(Digest::SHA::sha1_base64(time), 0, 8);
            $opt_password = crypt(encode("utf8", $opt_password), "\$6\$$time\$");
        }
    } else {
        $opt_password = '*';
    }

    if ($self->ct_file_exists($shadow)) {
        &$replacepw($self, $shadow, $user, $opt_password, 1);
        &$replacepw($self, $pwfile, $user, 'x');
    } else {
        &$replacepw($self, $pwfile, $user, $opt_password);
    }
}

1;
