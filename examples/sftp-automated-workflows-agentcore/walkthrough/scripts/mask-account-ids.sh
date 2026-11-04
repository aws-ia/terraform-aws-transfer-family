#!/bin/bash
################################################################################
# Account ID masking helper
#
# Source this near the top of a walkthrough script:
#   source "$(dirname "${BASH_SOURCE[0]}")/mask-account-ids.sh"
#
# All stdout/stderr of the script (and every command it runs) is passed
# through a filter that replaces 12-digit AWS account IDs with asterisks,
# including inside ARNs (arn:aws:iam::************:role/...).
#
# Environment knobs:
#   SHOW_ACCOUNT_IDS=1          disable masking for this run
#   MASK_ACCOUNT_IDS="111122223333 444455556666"
#                               only mask these IDs (default: any 12-digit number)
#   MASK_KEEP_LAST_DIGITS=4     leave the last N digits visible (********3333)
#
# Notes:
#   - Commands no longer see a TTY on stdout, so tools that only colorize or
#     show progress bars on a terminal (jq, sftp progress meter) go plain.
#   - Prompts without a trailing newline still appear (flushed after ~50ms).
#   - Compatible with macOS /bin/bash 3.2.
################################################################################

if [ "${SHOW_ACCOUNT_IDS:-0}" != "1" ] \
    && [ -z "${_MASK_ACCOUNT_IDS_ACTIVE:-}" ] \
    && command -v perl >/dev/null 2>&1; then

    # Perl stream filter. Reads raw bytes, masks IDs, and flushes promptly.
    read -r -d '' _MASK_ACCOUNT_IDS_PERL <<'PERL' || true
use strict;
use warnings;

# Ctrl+C goes to the whole process group; the filter must survive it so the
# script's own INT traps (and remaining output) keep working. It exits on EOF.
$SIG{INT}  = 'IGNORE';
$SIG{QUIT} = 'IGNORE';
binmode STDIN;
binmode STDOUT;
$| = 1;

my $keep = $ENV{MASK_KEEP_LAST_DIGITS} // 0;
$keep = 0  unless $keep =~ /^\d+$/;
$keep = 12 if $keep > 12;

my @known = grep { length($_) == 12 }
            map  { (my $x = $_) =~ s/\D//g; $x }
            split /[\s,]+/, ($ENV{MASK_ACCOUNT_IDS} // '');

# Boundaries: not adjacent to other letters/digits, so hex signatures, tokens
# and longer numbers are left alone. Hyphens are allowed before a plain ID
# (bucket-name-123456789012) but not around the 1234-5678-9012 form.
my $pre  = '(?<![A-Za-z0-9])';
my $post = '(?![A-Za-z0-9])';
my $re;
if (@known) {
    $re = join '|', map {
        my $id = $_;
        ("$pre$id$post",
         '(?<![A-Za-z0-9-])' . substr($id, 0, 4) . '-' . substr($id, 4, 4) . '-'
           . substr($id, 8) . '(?![A-Za-z0-9-])')
    } @known;
} else {
    $re = "$pre\\d{12}$post|(?<![A-Za-z0-9-])\\d{4}-\\d{4}-\\d{4}(?![A-Za-z0-9-])";
}
$re = qr/$re/;

my $esc     = qr/\e\[[0-9;?]*[A-Za-z]/;                        # ANSI color/style
my $tail_re = qr/(?:\e\[[0-9;?]*[A-Za-z]|\e\[?[0-9;?]*|[A-Za-z0-9-])+\z/;

sub mask_match {
    my $m = shift;
    my $n = 0;
    $m =~ s/(\d)/ ++$n > 12 - $keep ? $1 : '*' /ge;
    return $m;
}

sub mask {
    my $s = shift;
    return $s unless $s =~ /\d{4}/;
    # Mask text between ANSI escapes separately so "\e[0;32m123456789012"
    # is treated as a standalone ID rather than "m123456789012".
    return join '', map {
        /\A\e\[/ ? $_ : do { (my $t = $_) =~ s/($re)/mask_match($1)/ge; $t }
    } split /($esc)/, $s;
}

sub emit {
    my $s = shift;
    print mask($s) if length $s;
}

my $buf = '';
my $rin = '';
vec($rin, fileno(STDIN), 1) = 1;

while (1) {
    # If we're holding back a possible partial ID, wait at most 50ms for more.
    my $timeout = length($buf) ? 0.05 : undef;
    my $n = select(my $rout = $rin, undef, undef, $timeout);
    if ($n < 0) { next if $!{EINTR}; last; }
    if ($n == 0) { emit($buf); $buf = ''; next; }

    my $r = sysread(STDIN, my $chunk, 65536);
    if (!defined $r) { next if $!{EINTR}; last; }
    last if $r == 0;
    $buf .= $chunk;

    # Hold back a trailing token that could be the first half of an ID (or of
    # an escape sequence) split across reads; emit everything before it.
    my $hold = '';
    if ($buf =~ /($tail_re)/ && length($1) < 256) {
        $hold = $1;
        substr($buf, -length($hold)) = '';
    }
    emit($buf);
    $buf = $hold;
}
emit($buf);
PERL

    _mask_dir="$(mktemp -d "${TMPDIR:-/tmp}/mask-account-ids.XXXXXX" 2>/dev/null)" || _mask_dir=""

    if [ -n "$_mask_dir" ] && mkfifo "$_mask_dir/out" "$_mask_dir/err" 2>/dev/null; then
        export _MASK_ACCOUNT_IDS_ACTIVE=1

        perl -e "$_MASK_ACCOUNT_IDS_PERL" < "$_mask_dir/out" &
        _mask_out_pid=$!
        perl -e "$_MASK_ACCOUNT_IDS_PERL" < "$_mask_dir/err" >&2 &
        _mask_err_pid=$!

        exec >"$_mask_dir/out" 2>"$_mask_dir/err"
        rm -rf "$_mask_dir"  # FIFOs stay usable once opened

        # On exit, close our ends and wait so all output lands before the
        # shell prompt returns. The script's exit status is preserved.
        _mask_account_ids_finish() {
            exec >&- 2>&-
            wait "$_mask_out_pid" "$_mask_err_pid" 2>/dev/null || true
        }
        trap _mask_account_ids_finish EXIT
    else
        [ -n "$_mask_dir" ] && rm -rf "$_mask_dir"
        echo "warning: account ID masking unavailable (mkfifo failed); output is unmasked" >&2
    fi
    unset _mask_dir
fi
