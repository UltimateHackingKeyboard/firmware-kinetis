#include "fsl_common.h"
#include "usb_commands/usb_command_apply_config.h"
#include "config_parser/config_globals.h"
#include "config_parser/parse_config.h"
#include "usb_interfaces/usb_interface_generic_hid.h"
#include "usb_protocol_handler.h"
#include "keymap.h"

void updateUsbBuffer(uint8_t usbStatusCode, uint16_t parserOffset, parser_stage_t parserStage)
{
    SET_USB_BUFFER_UINT8(0, usbStatusCode);
    SET_USB_BUFFER_UINT16(1, parserOffset);
    SET_USB_BUFFER_UINT8(3, parserStage);
}

void UsbCommand_ApplyConfig(void)
{
    // Validate the staging configuration.

    ParserRunDry = true;
    StagingUserConfigBuffer.offset = 0;
    uint8_t parseConfigStatus = ParseConfig(&StagingUserConfigBuffer);
    updateUsbBuffer(parseConfigStatus, StagingUserConfigBuffer.offset, ParsingStage_Validate);

    if (parseConfigStatus != UsbStatusCode_Success) {
        return;
    }

    // Make the staging configuration the current one.

    char oldKeymapAbbreviation[KEYMAP_ABBREVIATION_LENGTH];
    uint8_t oldKeymapAbbreviationLen;
    memcpy(oldKeymapAbbreviation, AllKeymaps[CurrentKeymapIndex].abbreviation, KEYMAP_ABBREVIATION_LENGTH);
    oldKeymapAbbreviationLen = AllKeymaps[CurrentKeymapIndex].abbreviationLen;

    uint8_t *temp = ValidatedUserConfigBuffer.buffer;
    ValidatedUserConfigBuffer.buffer = StagingUserConfigBuffer.buffer;
    StagingUserConfigBuffer.buffer = temp;

    ParserRunDry = false;
    ValidatedUserConfigBuffer.offset = 0;
    parseConfigStatus = ParseConfig(&ValidatedUserConfigBuffer);
    updateUsbBuffer(parseConfigStatus, ValidatedUserConfigBuffer.offset, ParsingStage_Apply);

    if (parseConfigStatus != UsbStatusCode_Success) {
        return;
    }

    // Switch to the keymap of the updated configuration of the same name or the default keymap.

    for (uint8_t keymapId = 0; keymapId < AllKeymapsCount; keymapId++) {
        if (AllKeymaps[keymapId].abbreviationLen == oldKeymapAbbreviationLen &&
            !memcmp(oldKeymapAbbreviation, AllKeymaps[keymapId].abbreviation, oldKeymapAbbreviationLen))
        {
            SwitchKeymap(keymapId);
            return;
        }
    }

    SwitchKeymap(DefaultKeymapIndex);
}