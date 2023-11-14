# --
# Copyright (C) 2023 maxence business consulting gmbh, http://www.maxence.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use Kernel::Language;

print STDERR "Loading TranslationHelper\n";

{
    my $orgTranslate = \&Kernel::Language::Translate;
    *Kernel::Language::Translate = sub {
        my ( $Self, $Text, @Parameters ) = @_;
        $Self->{TranslationHelper}->checkTranslation($Text) if ($Self->{TranslationHelper});
        return $orgTranslate->($Self, $Text, @Parameters);
    };  
}