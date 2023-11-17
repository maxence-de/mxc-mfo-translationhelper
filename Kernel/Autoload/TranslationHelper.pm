# --
# Copyright (C) 2023 maxence business consulting gmbh
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (GPL-3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use Kernel::Language;

BEGIN {
    #---------------------------------------------------------------------------------------------------------
    # Monkey Patch for Kernel::Language::Translate
    #
    # Extends the Translate function of the Kernel::Language module to call TranslationHelper if injected.
    #
    # Description:
    #     This Monkey Patch modifies the behavior of the Kernel::Language::Translate function to enhance
    #     translation handling. It checks if a TranslationHelper object has been injected and, if so, calls
    #     the TranslationHelper's checkTranslation method to identify missing translations before performing
    #     the actual translation using the original Translate function.
    #
    # Parameters:
    #     - $Self:       The Kernel::Language object instance.
    #     - $Text:       The text to be translated.
    #     - @Parameters: Additional parameters for translation (if any).
    #
    # Returns:
    #     The translated text or the original text if no translation is available.
    #
    # Example:
    #     my $translatedText = $Kernel::OM->Get('Kernel::Language')->Translate('Hello, World!');
    #
    # Note:
    #     - This Monkey Patch should be registered as part of Znuny Autoload to extend the behavior of the
    #       Translate function in Kernel::Language.
    #     - It enhances translation by identifying missing translations through TranslationHelper when it has
    #       been injected.
    #---------------------------------------------------------------------------------------------------------
    no warnings 'redefine';
  
    my $orgTranslate = \&Kernel::Language::Translate;
    *Kernel::Language::Translate = sub {
        my ( $Self, $Text, @Parameters ) = @_;
        $Self->{TranslationHelper}->checkTranslation($Text) if ($Self->{TranslationHelper});
        return $orgTranslate->($Self, $Text, @Parameters);
    };  
}