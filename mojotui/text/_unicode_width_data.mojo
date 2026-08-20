"""Generated Unicode terminal-width lookup tables. Do not edit."""

# Unicode version: 17.0.0
# Sources and SHA-256 digests:
# - https://www.unicode.org/Public/17.0.0/ucd/EastAsianWidth.txt
#   ea7ce50f3444a050333448dffef1cadd9325af55cbb764b4a2280faf52170a33  EastAsianWidth.txt
# - https://www.unicode.org/Public/17.0.0/ucd/extracted/DerivedGeneralCategory.txt
#   d62e5bab70ca74f099343f71224fa051cb1fdd61a1ab45c0488c44cfc0b6102e  DerivedGeneralCategory.txt
# - https://www.unicode.org/Public/17.0.0/ucd/emoji/emoji-data.txt
#   2cb2bb9455cda83e8481541ecf5b6dfda66a3bb89efa3fa7c5297eccf607b72b  emoji-data.txt
# - https://www.unicode.org/Public/17.0.0/ucd/PropList.txt
#   130dcddcaadaf071008bdfce1e7743e04fdfbc910886f017d9f9ac931d8c64dd  PropList.txt


def unicode_data_version() -> String:
    return "17.0.0"


def is_zero_width(value: Int) -> Bool:
    if value < 0:
        return False
    if value < 0xA82C:
        if value < 0xEB1:
            if value < 0xA4B:
                if value < 0x816:
                    if value < 0x64B:
                        if value < 0x5C1:
                            if value < 0x483:
                                if value < 0x300:
                                    if value < 0xAD:
                                        return False
                                    if value > 0xAD:
                                        return False
                                    return True
                                if value > 0x36F:
                                    return False
                                return True
                            if value > 0x489:
                                if value < 0x5BF:
                                    if value < 0x591:
                                        return False
                                    if value > 0x5BD:
                                        return False
                                    return True
                                if value > 0x5BF:
                                    return False
                                return True
                            return True
                        if value > 0x5C2:
                            if value < 0x600:
                                if value < 0x5C7:
                                    if value < 0x5C4:
                                        return False
                                    if value > 0x5C5:
                                        return False
                                    return True
                                if value > 0x5C7:
                                    return False
                                return True
                            if value > 0x605:
                                if value < 0x61C:
                                    if value < 0x610:
                                        return False
                                    if value > 0x61A:
                                        return False
                                    return True
                                if value > 0x61C:
                                    return False
                                return True
                            return True
                        return True
                    if value > 0x65F:
                        if value < 0x70F:
                            if value < 0x6DF:
                                if value < 0x6D6:
                                    if value < 0x670:
                                        return False
                                    if value > 0x670:
                                        return False
                                    return True
                                if value > 0x6DD:
                                    return False
                                return True
                            if value > 0x6E4:
                                if value < 0x6EA:
                                    if value < 0x6E7:
                                        return False
                                    if value > 0x6E8:
                                        return False
                                    return True
                                if value > 0x6ED:
                                    return False
                                return True
                            return True
                        if value > 0x70F:
                            if value < 0x7A6:
                                if value < 0x730:
                                    if value < 0x711:
                                        return False
                                    if value > 0x711:
                                        return False
                                    return True
                                if value > 0x74A:
                                    return False
                                return True
                            if value > 0x7B0:
                                if value < 0x7FD:
                                    if value < 0x7EB:
                                        return False
                                    if value > 0x7F3:
                                        return False
                                    return True
                                if value > 0x7FD:
                                    return False
                                return True
                            return True
                        return True
                    return True
                if value > 0x819:
                    if value < 0x951:
                        if value < 0x897:
                            if value < 0x829:
                                if value < 0x825:
                                    if value < 0x81B:
                                        return False
                                    if value > 0x823:
                                        return False
                                    return True
                                if value > 0x827:
                                    return False
                                return True
                            if value > 0x82D:
                                if value < 0x890:
                                    if value < 0x859:
                                        return False
                                    if value > 0x85B:
                                        return False
                                    return True
                                if value > 0x891:
                                    return False
                                return True
                            return True
                        if value > 0x89F:
                            if value < 0x93C:
                                if value < 0x93A:
                                    if value < 0x8CA:
                                        return False
                                    if value > 0x902:
                                        return False
                                    return True
                                if value > 0x93A:
                                    return False
                                return True
                            if value > 0x93C:
                                if value < 0x94D:
                                    if value < 0x941:
                                        return False
                                    if value > 0x948:
                                        return False
                                    return True
                                if value > 0x94D:
                                    return False
                                return True
                            return True
                        return True
                    if value > 0x957:
                        if value < 0x9E2:
                            if value < 0x9BC:
                                if value < 0x981:
                                    if value < 0x962:
                                        return False
                                    if value > 0x963:
                                        return False
                                    return True
                                if value > 0x981:
                                    return False
                                return True
                            if value > 0x9BC:
                                if value < 0x9CD:
                                    if value < 0x9C1:
                                        return False
                                    if value > 0x9C4:
                                        return False
                                    return True
                                if value > 0x9CD:
                                    return False
                                return True
                            return True
                        if value > 0x9E3:
                            if value < 0xA3C:
                                if value < 0xA01:
                                    if value < 0x9FE:
                                        return False
                                    if value > 0x9FE:
                                        return False
                                    return True
                                if value > 0xA02:
                                    return False
                                return True
                            if value > 0xA3C:
                                if value < 0xA47:
                                    if value < 0xA41:
                                        return False
                                    if value > 0xA42:
                                        return False
                                    return True
                                if value > 0xA48:
                                    return False
                                return True
                            return True
                        return True
                    return True
                return True
            if value > 0xA4D:
                if value < 0xC3E:
                    if value < 0xB3C:
                        if value < 0xAC1:
                            if value < 0xA75:
                                if value < 0xA70:
                                    if value < 0xA51:
                                        return False
                                    if value > 0xA51:
                                        return False
                                    return True
                                if value > 0xA71:
                                    return False
                                return True
                            if value > 0xA75:
                                if value < 0xABC:
                                    if value < 0xA81:
                                        return False
                                    if value > 0xA82:
                                        return False
                                    return True
                                if value > 0xABC:
                                    return False
                                return True
                            return True
                        if value > 0xAC5:
                            if value < 0xAE2:
                                if value < 0xACD:
                                    if value < 0xAC7:
                                        return False
                                    if value > 0xAC8:
                                        return False
                                    return True
                                if value > 0xACD:
                                    return False
                                return True
                            if value > 0xAE3:
                                if value < 0xB01:
                                    if value < 0xAFA:
                                        return False
                                    if value > 0xAFF:
                                        return False
                                    return True
                                if value > 0xB01:
                                    return False
                                return True
                            return True
                        return True
                    if value > 0xB3C:
                        if value < 0xB82:
                            if value < 0xB4D:
                                if value < 0xB41:
                                    if value < 0xB3F:
                                        return False
                                    if value > 0xB3F:
                                        return False
                                    return True
                                if value > 0xB44:
                                    return False
                                return True
                            if value > 0xB4D:
                                if value < 0xB62:
                                    if value < 0xB55:
                                        return False
                                    if value > 0xB56:
                                        return False
                                    return True
                                if value > 0xB63:
                                    return False
                                return True
                            return True
                        if value > 0xB82:
                            if value < 0xC00:
                                if value < 0xBCD:
                                    if value < 0xBC0:
                                        return False
                                    if value > 0xBC0:
                                        return False
                                    return True
                                if value > 0xBCD:
                                    return False
                                return True
                            if value > 0xC00:
                                if value < 0xC3C:
                                    if value < 0xC04:
                                        return False
                                    if value > 0xC04:
                                        return False
                                    return True
                                if value > 0xC3C:
                                    return False
                                return True
                            return True
                        return True
                    return True
                if value > 0xC40:
                    if value < 0xD3B:
                        if value < 0xCBC:
                            if value < 0xC55:
                                if value < 0xC4A:
                                    if value < 0xC46:
                                        return False
                                    if value > 0xC48:
                                        return False
                                    return True
                                if value > 0xC4D:
                                    return False
                                return True
                            if value > 0xC56:
                                if value < 0xC81:
                                    if value < 0xC62:
                                        return False
                                    if value > 0xC63:
                                        return False
                                    return True
                                if value > 0xC81:
                                    return False
                                return True
                            return True
                        if value > 0xCBC:
                            if value < 0xCCC:
                                if value < 0xCC6:
                                    if value < 0xCBF:
                                        return False
                                    if value > 0xCBF:
                                        return False
                                    return True
                                if value > 0xCC6:
                                    return False
                                return True
                            if value > 0xCCD:
                                if value < 0xD00:
                                    if value < 0xCE2:
                                        return False
                                    if value > 0xCE3:
                                        return False
                                    return True
                                if value > 0xD01:
                                    return False
                                return True
                            return True
                        return True
                    if value > 0xD3C:
                        if value < 0xDD2:
                            if value < 0xD62:
                                if value < 0xD4D:
                                    if value < 0xD41:
                                        return False
                                    if value > 0xD44:
                                        return False
                                    return True
                                if value > 0xD4D:
                                    return False
                                return True
                            if value > 0xD63:
                                if value < 0xDCA:
                                    if value < 0xD81:
                                        return False
                                    if value > 0xD81:
                                        return False
                                    return True
                                if value > 0xDCA:
                                    return False
                                return True
                            return True
                        if value > 0xDD4:
                            if value < 0xE34:
                                if value < 0xE31:
                                    if value < 0xDD6:
                                        return False
                                    if value > 0xDD6:
                                        return False
                                    return True
                                if value > 0xE31:
                                    return False
                                return True
                            if value > 0xE3A:
                                if value < 0xE47:
                                    return False
                                if value > 0xE4E:
                                    return False
                                return True
                            return True
                        return True
                    return True
                return True
            return True
        if value > 0xEB1:
            if value < 0x1A62:
                if value < 0x1160:
                    if value < 0xFC6:
                        if value < 0xF39:
                            if value < 0xF18:
                                if value < 0xEC8:
                                    if value < 0xEB4:
                                        return False
                                    if value > 0xEBC:
                                        return False
                                    return True
                                if value > 0xECE:
                                    return False
                                return True
                            if value > 0xF19:
                                if value < 0xF37:
                                    if value < 0xF35:
                                        return False
                                    if value > 0xF35:
                                        return False
                                    return True
                                if value > 0xF37:
                                    return False
                                return True
                            return True
                        if value > 0xF39:
                            if value < 0xF86:
                                if value < 0xF80:
                                    if value < 0xF71:
                                        return False
                                    if value > 0xF7E:
                                        return False
                                    return True
                                if value > 0xF84:
                                    return False
                                return True
                            if value > 0xF87:
                                if value < 0xF99:
                                    if value < 0xF8D:
                                        return False
                                    if value > 0xF97:
                                        return False
                                    return True
                                if value > 0xFBC:
                                    return False
                                return True
                            return True
                        return True
                    if value > 0xFC6:
                        if value < 0x105E:
                            if value < 0x1039:
                                if value < 0x1032:
                                    if value < 0x102D:
                                        return False
                                    if value > 0x1030:
                                        return False
                                    return True
                                if value > 0x1037:
                                    return False
                                return True
                            if value > 0x103A:
                                if value < 0x1058:
                                    if value < 0x103D:
                                        return False
                                    if value > 0x103E:
                                        return False
                                    return True
                                if value > 0x1059:
                                    return False
                                return True
                            return True
                        if value > 0x1060:
                            if value < 0x1085:
                                if value < 0x1082:
                                    if value < 0x1071:
                                        return False
                                    if value > 0x1074:
                                        return False
                                    return True
                                if value > 0x1082:
                                    return False
                                return True
                            if value > 0x1086:
                                if value < 0x109D:
                                    if value < 0x108D:
                                        return False
                                    if value > 0x108D:
                                        return False
                                    return True
                                if value > 0x109D:
                                    return False
                                return True
                            return True
                        return True
                    return True
                if value > 0x11FF:
                    if value < 0x1885:
                        if value < 0x17B4:
                            if value < 0x1732:
                                if value < 0x1712:
                                    if value < 0x135D:
                                        return False
                                    if value > 0x135F:
                                        return False
                                    return True
                                if value > 0x1714:
                                    return False
                                return True
                            if value > 0x1733:
                                if value < 0x1772:
                                    if value < 0x1752:
                                        return False
                                    if value > 0x1753:
                                        return False
                                    return True
                                if value > 0x1773:
                                    return False
                                return True
                            return True
                        if value > 0x17B5:
                            if value < 0x17C9:
                                if value < 0x17C6:
                                    if value < 0x17B7:
                                        return False
                                    if value > 0x17BD:
                                        return False
                                    return True
                                if value > 0x17C6:
                                    return False
                                return True
                            if value > 0x17D3:
                                if value < 0x180B:
                                    if value < 0x17DD:
                                        return False
                                    if value > 0x17DD:
                                        return False
                                    return True
                                if value > 0x180F:
                                    return False
                                return True
                            return True
                        return True
                    if value > 0x1886:
                        if value < 0x1A17:
                            if value < 0x1927:
                                if value < 0x1920:
                                    if value < 0x18A9:
                                        return False
                                    if value > 0x18A9:
                                        return False
                                    return True
                                if value > 0x1922:
                                    return False
                                return True
                            if value > 0x1928:
                                if value < 0x1939:
                                    if value < 0x1932:
                                        return False
                                    if value > 0x1932:
                                        return False
                                    return True
                                if value > 0x193B:
                                    return False
                                return True
                            return True
                        if value > 0x1A18:
                            if value < 0x1A58:
                                if value < 0x1A56:
                                    if value < 0x1A1B:
                                        return False
                                    if value > 0x1A1B:
                                        return False
                                    return True
                                if value > 0x1A56:
                                    return False
                                return True
                            if value > 0x1A5E:
                                if value < 0x1A60:
                                    return False
                                if value > 0x1A60:
                                    return False
                                return True
                            return True
                        return True
                    return True
                return True
            if value > 0x1A62:
                if value < 0x1CE2:
                    if value < 0x1B80:
                        if value < 0x1B00:
                            if value < 0x1A7F:
                                if value < 0x1A73:
                                    if value < 0x1A65:
                                        return False
                                    if value > 0x1A6C:
                                        return False
                                    return True
                                if value > 0x1A7C:
                                    return False
                                return True
                            if value > 0x1A7F:
                                if value < 0x1AE0:
                                    if value < 0x1AB0:
                                        return False
                                    if value > 0x1ADD:
                                        return False
                                    return True
                                if value > 0x1AEB:
                                    return False
                                return True
                            return True
                        if value > 0x1B03:
                            if value < 0x1B3C:
                                if value < 0x1B36:
                                    if value < 0x1B34:
                                        return False
                                    if value > 0x1B34:
                                        return False
                                    return True
                                if value > 0x1B3A:
                                    return False
                                return True
                            if value > 0x1B3C:
                                if value < 0x1B6B:
                                    if value < 0x1B42:
                                        return False
                                    if value > 0x1B42:
                                        return False
                                    return True
                                if value > 0x1B73:
                                    return False
                                return True
                            return True
                        return True
                    if value > 0x1B81:
                        if value < 0x1BED:
                            if value < 0x1BAB:
                                if value < 0x1BA8:
                                    if value < 0x1BA2:
                                        return False
                                    if value > 0x1BA5:
                                        return False
                                    return True
                                if value > 0x1BA9:
                                    return False
                                return True
                            if value > 0x1BAD:
                                if value < 0x1BE8:
                                    if value < 0x1BE6:
                                        return False
                                    if value > 0x1BE6:
                                        return False
                                    return True
                                if value > 0x1BE9:
                                    return False
                                return True
                            return True
                        if value > 0x1BED:
                            if value < 0x1C36:
                                if value < 0x1C2C:
                                    if value < 0x1BEF:
                                        return False
                                    if value > 0x1BF1:
                                        return False
                                    return True
                                if value > 0x1C33:
                                    return False
                                return True
                            if value > 0x1C37:
                                if value < 0x1CD4:
                                    if value < 0x1CD0:
                                        return False
                                    if value > 0x1CD2:
                                        return False
                                    return True
                                if value > 0x1CE0:
                                    return False
                                return True
                            return True
                        return True
                    return True
                if value > 0x1CE8:
                    if value < 0x2DE0:
                        if value < 0x202A:
                            if value < 0x1CF8:
                                if value < 0x1CF4:
                                    if value < 0x1CED:
                                        return False
                                    if value > 0x1CED:
                                        return False
                                    return True
                                if value > 0x1CF4:
                                    return False
                                return True
                            if value > 0x1CF9:
                                if value < 0x200B:
                                    if value < 0x1DC0:
                                        return False
                                    if value > 0x1DFF:
                                        return False
                                    return True
                                if value > 0x200F:
                                    return False
                                return True
                            return True
                        if value > 0x202E:
                            if value < 0x20D0:
                                if value < 0x2066:
                                    if value < 0x2060:
                                        return False
                                    if value > 0x2064:
                                        return False
                                    return True
                                if value > 0x206F:
                                    return False
                                return True
                            if value > 0x20F0:
                                if value < 0x2D7F:
                                    if value < 0x2CEF:
                                        return False
                                    if value > 0x2CF1:
                                        return False
                                    return True
                                if value > 0x2D7F:
                                    return False
                                return True
                            return True
                        return True
                    if value > 0x2DFF:
                        if value < 0xA6F0:
                            if value < 0xA66F:
                                if value < 0x3099:
                                    if value < 0x302A:
                                        return False
                                    if value > 0x302D:
                                        return False
                                    return True
                                if value > 0x309A:
                                    return False
                                return True
                            if value > 0xA672:
                                if value < 0xA69E:
                                    if value < 0xA674:
                                        return False
                                    if value > 0xA67D:
                                        return False
                                    return True
                                if value > 0xA69F:
                                    return False
                                return True
                            return True
                        if value > 0xA6F1:
                            if value < 0xA80B:
                                if value < 0xA806:
                                    if value < 0xA802:
                                        return False
                                    if value > 0xA802:
                                        return False
                                    return True
                                if value > 0xA806:
                                    return False
                                return True
                            if value > 0xA80B:
                                if value < 0xA825:
                                    return False
                                if value > 0xA826:
                                    return False
                                return True
                            return True
                        return True
                    return True
                return True
            return True
        return True
    if value > 0xA82C:
        if value < 0x1163D:
            if value < 0x11038:
                if value < 0xABE5:
                    if value < 0xAA31:
                        if value < 0xA980:
                            if value < 0xA8FF:
                                if value < 0xA8E0:
                                    if value < 0xA8C4:
                                        return False
                                    if value > 0xA8C5:
                                        return False
                                    return True
                                if value > 0xA8F1:
                                    return False
                                return True
                            if value > 0xA8FF:
                                if value < 0xA947:
                                    if value < 0xA926:
                                        return False
                                    if value > 0xA92D:
                                        return False
                                    return True
                                if value > 0xA951:
                                    return False
                                return True
                            return True
                        if value > 0xA982:
                            if value < 0xA9BC:
                                if value < 0xA9B6:
                                    if value < 0xA9B3:
                                        return False
                                    if value > 0xA9B3:
                                        return False
                                    return True
                                if value > 0xA9B9:
                                    return False
                                return True
                            if value > 0xA9BD:
                                if value < 0xAA29:
                                    if value < 0xA9E5:
                                        return False
                                    if value > 0xA9E5:
                                        return False
                                    return True
                                if value > 0xAA2E:
                                    return False
                                return True
                            return True
                        return True
                    if value > 0xAA32:
                        if value < 0xAAB2:
                            if value < 0xAA4C:
                                if value < 0xAA43:
                                    if value < 0xAA35:
                                        return False
                                    if value > 0xAA36:
                                        return False
                                    return True
                                if value > 0xAA43:
                                    return False
                                return True
                            if value > 0xAA4C:
                                if value < 0xAAB0:
                                    if value < 0xAA7C:
                                        return False
                                    if value > 0xAA7C:
                                        return False
                                    return True
                                if value > 0xAAB0:
                                    return False
                                return True
                            return True
                        if value > 0xAAB4:
                            if value < 0xAAC1:
                                if value < 0xAABE:
                                    if value < 0xAAB7:
                                        return False
                                    if value > 0xAAB8:
                                        return False
                                    return True
                                if value > 0xAABF:
                                    return False
                                return True
                            if value > 0xAAC1:
                                if value < 0xAAF6:
                                    if value < 0xAAEC:
                                        return False
                                    if value > 0xAAED:
                                        return False
                                    return True
                                if value > 0xAAF6:
                                    return False
                                return True
                            return True
                        return True
                    return True
                if value > 0xABE5:
                    if value < 0x10A05:
                        if value < 0xFEFF:
                            if value < 0xFB1E:
                                if value < 0xABED:
                                    if value < 0xABE8:
                                        return False
                                    if value > 0xABE8:
                                        return False
                                    return True
                                if value > 0xABED:
                                    return False
                                return True
                            if value > 0xFB1E:
                                if value < 0xFE20:
                                    if value < 0xFE00:
                                        return False
                                    if value > 0xFE0F:
                                        return False
                                    return True
                                if value > 0xFE2F:
                                    return False
                                return True
                            return True
                        if value > 0xFEFF:
                            if value < 0x102E0:
                                if value < 0x101FD:
                                    if value < 0xFFF9:
                                        return False
                                    if value > 0xFFFB:
                                        return False
                                    return True
                                if value > 0x101FD:
                                    return False
                                return True
                            if value > 0x102E0:
                                if value < 0x10A01:
                                    if value < 0x10376:
                                        return False
                                    if value > 0x1037A:
                                        return False
                                    return True
                                if value > 0x10A03:
                                    return False
                                return True
                            return True
                        return True
                    if value > 0x10A06:
                        if value < 0x10D69:
                            if value < 0x10A3F:
                                if value < 0x10A38:
                                    if value < 0x10A0C:
                                        return False
                                    if value > 0x10A0F:
                                        return False
                                    return True
                                if value > 0x10A3A:
                                    return False
                                return True
                            if value > 0x10A3F:
                                if value < 0x10D24:
                                    if value < 0x10AE5:
                                        return False
                                    if value > 0x10AE6:
                                        return False
                                    return True
                                if value > 0x10D27:
                                    return False
                                return True
                            return True
                        if value > 0x10D6D:
                            if value < 0x10F46:
                                if value < 0x10EFA:
                                    if value < 0x10EAB:
                                        return False
                                    if value > 0x10EAC:
                                        return False
                                    return True
                                if value > 0x10EFF:
                                    return False
                                return True
                            if value > 0x10F50:
                                if value < 0x11001:
                                    if value < 0x10F82:
                                        return False
                                    if value > 0x10F85:
                                        return False
                                    return True
                                if value > 0x11001:
                                    return False
                                return True
                            return True
                        return True
                    return True
                return True
            if value > 0x11046:
                if value < 0x11300:
                    if value < 0x11173:
                        if value < 0x110BD:
                            if value < 0x1107F:
                                if value < 0x11073:
                                    if value < 0x11070:
                                        return False
                                    if value > 0x11070:
                                        return False
                                    return True
                                if value > 0x11074:
                                    return False
                                return True
                            if value > 0x11081:
                                if value < 0x110B9:
                                    if value < 0x110B3:
                                        return False
                                    if value > 0x110B6:
                                        return False
                                    return True
                                if value > 0x110BA:
                                    return False
                                return True
                            return True
                        if value > 0x110BD:
                            if value < 0x11100:
                                if value < 0x110CD:
                                    if value < 0x110C2:
                                        return False
                                    if value > 0x110C2:
                                        return False
                                    return True
                                if value > 0x110CD:
                                    return False
                                return True
                            if value > 0x11102:
                                if value < 0x1112D:
                                    if value < 0x11127:
                                        return False
                                    if value > 0x1112B:
                                        return False
                                    return True
                                if value > 0x11134:
                                    return False
                                return True
                            return True
                        return True
                    if value > 0x11173:
                        if value < 0x11234:
                            if value < 0x111C9:
                                if value < 0x111B6:
                                    if value < 0x11180:
                                        return False
                                    if value > 0x11181:
                                        return False
                                    return True
                                if value > 0x111BE:
                                    return False
                                return True
                            if value > 0x111CC:
                                if value < 0x1122F:
                                    if value < 0x111CF:
                                        return False
                                    if value > 0x111CF:
                                        return False
                                    return True
                                if value > 0x11231:
                                    return False
                                return True
                            return True
                        if value > 0x11234:
                            if value < 0x11241:
                                if value < 0x1123E:
                                    if value < 0x11236:
                                        return False
                                    if value > 0x11237:
                                        return False
                                    return True
                                if value > 0x1123E:
                                    return False
                                return True
                            if value > 0x11241:
                                if value < 0x112E3:
                                    if value < 0x112DF:
                                        return False
                                    if value > 0x112DF:
                                        return False
                                    return True
                                if value > 0x112EA:
                                    return False
                                return True
                            return True
                        return True
                    return True
                if value > 0x11301:
                    if value < 0x11446:
                        if value < 0x113CE:
                            if value < 0x11366:
                                if value < 0x11340:
                                    if value < 0x1133B:
                                        return False
                                    if value > 0x1133C:
                                        return False
                                    return True
                                if value > 0x11340:
                                    return False
                                return True
                            if value > 0x1136C:
                                if value < 0x113BB:
                                    if value < 0x11370:
                                        return False
                                    if value > 0x11374:
                                        return False
                                    return True
                                if value > 0x113C0:
                                    return False
                                return True
                            return True
                        if value > 0x113CE:
                            if value < 0x113E1:
                                if value < 0x113D2:
                                    if value < 0x113D0:
                                        return False
                                    if value > 0x113D0:
                                        return False
                                    return True
                                if value > 0x113D2:
                                    return False
                                return True
                            if value > 0x113E2:
                                if value < 0x11442:
                                    if value < 0x11438:
                                        return False
                                    if value > 0x1143F:
                                        return False
                                    return True
                                if value > 0x11444:
                                    return False
                                return True
                            return True
                        return True
                    if value > 0x11446:
                        if value < 0x115B2:
                            if value < 0x114BA:
                                if value < 0x114B3:
                                    if value < 0x1145E:
                                        return False
                                    if value > 0x1145E:
                                        return False
                                    return True
                                if value > 0x114B8:
                                    return False
                                return True
                            if value > 0x114BA:
                                if value < 0x114C2:
                                    if value < 0x114BF:
                                        return False
                                    if value > 0x114C0:
                                        return False
                                    return True
                                if value > 0x114C3:
                                    return False
                                return True
                            return True
                        if value > 0x115B5:
                            if value < 0x115DC:
                                if value < 0x115BF:
                                    if value < 0x115BC:
                                        return False
                                    if value > 0x115BD:
                                        return False
                                    return True
                                if value > 0x115C0:
                                    return False
                                return True
                            if value > 0x115DD:
                                if value < 0x11633:
                                    return False
                                if value > 0x1163A:
                                    return False
                                return True
                            return True
                        return True
                    return True
                return True
            return True
        if value > 0x1163D:
            if value < 0x11F40:
                if value < 0x11A8A:
                    if value < 0x1193B:
                        if value < 0x1171D:
                            if value < 0x116AD:
                                if value < 0x116AB:
                                    if value < 0x1163F:
                                        return False
                                    if value > 0x11640:
                                        return False
                                    return True
                                if value > 0x116AB:
                                    return False
                                return True
                            if value > 0x116AD:
                                if value < 0x116B7:
                                    if value < 0x116B0:
                                        return False
                                    if value > 0x116B5:
                                        return False
                                    return True
                                if value > 0x116B7:
                                    return False
                                return True
                            return True
                        if value > 0x1171D:
                            if value < 0x11727:
                                if value < 0x11722:
                                    if value < 0x1171F:
                                        return False
                                    if value > 0x1171F:
                                        return False
                                    return True
                                if value > 0x11725:
                                    return False
                                return True
                            if value > 0x1172B:
                                if value < 0x11839:
                                    if value < 0x1182F:
                                        return False
                                    if value > 0x11837:
                                        return False
                                    return True
                                if value > 0x1183A:
                                    return False
                                return True
                            return True
                        return True
                    if value > 0x1193C:
                        if value < 0x11A01:
                            if value < 0x119D4:
                                if value < 0x11943:
                                    if value < 0x1193E:
                                        return False
                                    if value > 0x1193E:
                                        return False
                                    return True
                                if value > 0x11943:
                                    return False
                                return True
                            if value > 0x119D7:
                                if value < 0x119E0:
                                    if value < 0x119DA:
                                        return False
                                    if value > 0x119DB:
                                        return False
                                    return True
                                if value > 0x119E0:
                                    return False
                                return True
                            return True
                        if value > 0x11A0A:
                            if value < 0x11A47:
                                if value < 0x11A3B:
                                    if value < 0x11A33:
                                        return False
                                    if value > 0x11A38:
                                        return False
                                    return True
                                if value > 0x11A3E:
                                    return False
                                return True
                            if value > 0x11A47:
                                if value < 0x11A59:
                                    if value < 0x11A51:
                                        return False
                                    if value > 0x11A56:
                                        return False
                                    return True
                                if value > 0x11A5B:
                                    return False
                                return True
                            return True
                        return True
                    return True
                if value > 0x11A96:
                    if value < 0x11D31:
                        if value < 0x11C38:
                            if value < 0x11B62:
                                if value < 0x11B60:
                                    if value < 0x11A98:
                                        return False
                                    if value > 0x11A99:
                                        return False
                                    return True
                                if value > 0x11B60:
                                    return False
                                return True
                            if value > 0x11B64:
                                if value < 0x11C30:
                                    if value < 0x11B66:
                                        return False
                                    if value > 0x11B66:
                                        return False
                                    return True
                                if value > 0x11C36:
                                    return False
                                return True
                            return True
                        if value > 0x11C3D:
                            if value < 0x11CAA:
                                if value < 0x11C92:
                                    if value < 0x11C3F:
                                        return False
                                    if value > 0x11C3F:
                                        return False
                                    return True
                                if value > 0x11CA7:
                                    return False
                                return True
                            if value > 0x11CB0:
                                if value < 0x11CB5:
                                    if value < 0x11CB2:
                                        return False
                                    if value > 0x11CB3:
                                        return False
                                    return True
                                if value > 0x11CB6:
                                    return False
                                return True
                            return True
                        return True
                    if value > 0x11D36:
                        if value < 0x11D95:
                            if value < 0x11D3F:
                                if value < 0x11D3C:
                                    if value < 0x11D3A:
                                        return False
                                    if value > 0x11D3A:
                                        return False
                                    return True
                                if value > 0x11D3D:
                                    return False
                                return True
                            if value > 0x11D45:
                                if value < 0x11D90:
                                    if value < 0x11D47:
                                        return False
                                    if value > 0x11D47:
                                        return False
                                    return True
                                if value > 0x11D91:
                                    return False
                                return True
                            return True
                        if value > 0x11D95:
                            if value < 0x11F00:
                                if value < 0x11EF3:
                                    if value < 0x11D97:
                                        return False
                                    if value > 0x11D97:
                                        return False
                                    return True
                                if value > 0x11EF4:
                                    return False
                                return True
                            if value > 0x11F01:
                                if value < 0x11F36:
                                    return False
                                if value > 0x11F3A:
                                    return False
                                return True
                            return True
                        return True
                    return True
                return True
            if value > 0x11F40:
                if value < 0x1DA84:
                    if value < 0x1BC9D:
                        if value < 0x1612D:
                            if value < 0x13430:
                                if value < 0x11F5A:
                                    if value < 0x11F42:
                                        return False
                                    if value > 0x11F42:
                                        return False
                                    return True
                                if value > 0x11F5A:
                                    return False
                                return True
                            if value > 0x13440:
                                if value < 0x1611E:
                                    if value < 0x13447:
                                        return False
                                    if value > 0x13455:
                                        return False
                                    return True
                                if value > 0x16129:
                                    return False
                                return True
                            return True
                        if value > 0x1612F:
                            if value < 0x16F4F:
                                if value < 0x16B30:
                                    if value < 0x16AF0:
                                        return False
                                    if value > 0x16AF4:
                                        return False
                                    return True
                                if value > 0x16B36:
                                    return False
                                return True
                            if value > 0x16F4F:
                                if value < 0x16FE4:
                                    if value < 0x16F8F:
                                        return False
                                    if value > 0x16F92:
                                        return False
                                    return True
                                if value > 0x16FE4:
                                    return False
                                return True
                            return True
                        return True
                    if value > 0x1BC9E:
                        if value < 0x1D185:
                            if value < 0x1CF30:
                                if value < 0x1CF00:
                                    if value < 0x1BCA0:
                                        return False
                                    if value > 0x1BCA3:
                                        return False
                                    return True
                                if value > 0x1CF2D:
                                    return False
                                return True
                            if value > 0x1CF46:
                                if value < 0x1D173:
                                    if value < 0x1D167:
                                        return False
                                    if value > 0x1D169:
                                        return False
                                    return True
                                if value > 0x1D182:
                                    return False
                                return True
                            return True
                        if value > 0x1D18B:
                            if value < 0x1DA00:
                                if value < 0x1D242:
                                    if value < 0x1D1AA:
                                        return False
                                    if value > 0x1D1AD:
                                        return False
                                    return True
                                if value > 0x1D244:
                                    return False
                                return True
                            if value > 0x1DA36:
                                if value < 0x1DA75:
                                    if value < 0x1DA3B:
                                        return False
                                    if value > 0x1DA6C:
                                        return False
                                    return True
                                if value > 0x1DA75:
                                    return False
                                return True
                            return True
                        return True
                    return True
                if value > 0x1DA84:
                    if value < 0x1E4EC:
                        if value < 0x1E023:
                            if value < 0x1E000:
                                if value < 0x1DAA1:
                                    if value < 0x1DA9B:
                                        return False
                                    if value > 0x1DA9F:
                                        return False
                                    return True
                                if value > 0x1DAAF:
                                    return False
                                return True
                            if value > 0x1E006:
                                if value < 0x1E01B:
                                    if value < 0x1E008:
                                        return False
                                    if value > 0x1E018:
                                        return False
                                    return True
                                if value > 0x1E021:
                                    return False
                                return True
                            return True
                        if value > 0x1E024:
                            if value < 0x1E130:
                                if value < 0x1E08F:
                                    if value < 0x1E026:
                                        return False
                                    if value > 0x1E02A:
                                        return False
                                    return True
                                if value > 0x1E08F:
                                    return False
                                return True
                            if value > 0x1E136:
                                if value < 0x1E2EC:
                                    if value < 0x1E2AE:
                                        return False
                                    if value > 0x1E2AE:
                                        return False
                                    return True
                                if value > 0x1E2EF:
                                    return False
                                return True
                            return True
                        return True
                    if value > 0x1E4EF:
                        if value < 0x1E8D0:
                            if value < 0x1E6E6:
                                if value < 0x1E6E3:
                                    if value < 0x1E5EE:
                                        return False
                                    if value > 0x1E5EF:
                                        return False
                                    return True
                                if value > 0x1E6E3:
                                    return False
                                return True
                            if value > 0x1E6E6:
                                if value < 0x1E6F5:
                                    if value < 0x1E6EE:
                                        return False
                                    if value > 0x1E6EF:
                                        return False
                                    return True
                                if value > 0x1E6F5:
                                    return False
                                return True
                            return True
                        if value > 0x1E8D6:
                            if value < 0xE0020:
                                if value < 0xE0001:
                                    if value < 0x1E944:
                                        return False
                                    if value > 0x1E94A:
                                        return False
                                    return True
                                if value > 0xE0001:
                                    return False
                                return True
                            if value > 0xE007F:
                                if value < 0xE0100:
                                    return False
                                if value > 0xE01EF:
                                    return False
                                return True
                            return True
                        return True
                    return True
                return True
            return True
        return True
    return True


def is_wide(value: Int) -> Bool:
    if value < 0:
        return False
    if value < 0x17000:
        if value < 0x2757:
            if value < 0x26BD:
                if value < 0x2614:
                    if value < 0x23E9:
                        if value < 0x231A:
                            if value < 0x1100:
                                return False
                            if value > 0x115F:
                                return False
                            return True
                        if value > 0x231B:
                            if value < 0x2329:
                                return False
                            if value > 0x232A:
                                return False
                            return True
                        return True
                    if value > 0x23EC:
                        if value < 0x23F3:
                            if value < 0x23F0:
                                return False
                            if value > 0x23F0:
                                return False
                            return True
                        if value > 0x23F3:
                            if value < 0x25FD:
                                return False
                            if value > 0x25FE:
                                return False
                            return True
                        return True
                    return True
                if value > 0x2615:
                    if value < 0x268A:
                        if value < 0x2648:
                            if value < 0x2630:
                                return False
                            if value > 0x2637:
                                return False
                            return True
                        if value > 0x2653:
                            if value < 0x267F:
                                return False
                            if value > 0x267F:
                                return False
                            return True
                        return True
                    if value > 0x268F:
                        if value < 0x26A1:
                            if value < 0x2693:
                                return False
                            if value > 0x2693:
                                return False
                            return True
                        if value > 0x26A1:
                            if value < 0x26AA:
                                return False
                            if value > 0x26AB:
                                return False
                            return True
                        return True
                    return True
                return True
            if value > 0x26BE:
                if value < 0x26FD:
                    if value < 0x26EA:
                        if value < 0x26CE:
                            if value < 0x26C4:
                                return False
                            if value > 0x26C5:
                                return False
                            return True
                        if value > 0x26CE:
                            if value < 0x26D4:
                                return False
                            if value > 0x26D4:
                                return False
                            return True
                        return True
                    if value > 0x26EA:
                        if value < 0x26F5:
                            if value < 0x26F2:
                                return False
                            if value > 0x26F3:
                                return False
                            return True
                        if value > 0x26F5:
                            if value < 0x26FA:
                                return False
                            if value > 0x26FA:
                                return False
                            return True
                        return True
                    return True
                if value > 0x26FD:
                    if value < 0x274C:
                        if value < 0x270A:
                            if value < 0x2705:
                                return False
                            if value > 0x2705:
                                return False
                            return True
                        if value > 0x270B:
                            if value < 0x2728:
                                return False
                            if value > 0x2728:
                                return False
                            return True
                        return True
                    if value > 0x274C:
                        if value < 0x2753:
                            if value < 0x274E:
                                return False
                            if value > 0x274E:
                                return False
                            return True
                        if value > 0x2755:
                            return False
                        return True
                    return True
                return True
            return True
        if value > 0x2757:
            if value < 0x31EF:
                if value < 0x2E9B:
                    if value < 0x2B1B:
                        if value < 0x27B0:
                            if value < 0x2795:
                                return False
                            if value > 0x2797:
                                return False
                            return True
                        if value > 0x27B0:
                            if value < 0x27BF:
                                return False
                            if value > 0x27BF:
                                return False
                            return True
                        return True
                    if value > 0x2B1C:
                        if value < 0x2B55:
                            if value < 0x2B50:
                                return False
                            if value > 0x2B50:
                                return False
                            return True
                        if value > 0x2B55:
                            if value < 0x2E80:
                                return False
                            if value > 0x2E99:
                                return False
                            return True
                        return True
                    return True
                if value > 0x2EF3:
                    if value < 0x3099:
                        if value < 0x2FF0:
                            if value < 0x2F00:
                                return False
                            if value > 0x2FD5:
                                return False
                            return True
                        if value > 0x303E:
                            if value < 0x3041:
                                return False
                            if value > 0x3096:
                                return False
                            return True
                        return True
                    if value > 0x30FF:
                        if value < 0x3131:
                            if value < 0x3105:
                                return False
                            if value > 0x312F:
                                return False
                            return True
                        if value > 0x318E:
                            if value < 0x3190:
                                return False
                            if value > 0x31E5:
                                return False
                            return True
                        return True
                    return True
                return True
            if value > 0x321E:
                if value < 0xFE30:
                    if value < 0xA960:
                        if value < 0x3250:
                            if value < 0x3220:
                                return False
                            if value > 0x3247:
                                return False
                            return True
                        if value > 0xA48C:
                            if value < 0xA490:
                                return False
                            if value > 0xA4C6:
                                return False
                            return True
                        return True
                    if value > 0xA97C:
                        if value < 0xF900:
                            if value < 0xAC00:
                                return False
                            if value > 0xD7A3:
                                return False
                            return True
                        if value > 0xFAFF:
                            if value < 0xFE10:
                                return False
                            if value > 0xFE19:
                                return False
                            return True
                        return True
                    return True
                if value > 0xFE52:
                    if value < 0xFFE0:
                        if value < 0xFE68:
                            if value < 0xFE54:
                                return False
                            if value > 0xFE66:
                                return False
                            return True
                        if value > 0xFE6B:
                            if value < 0xFF01:
                                return False
                            if value > 0xFF60:
                                return False
                            return True
                        return True
                    if value > 0xFFE6:
                        if value < 0x16FF0:
                            if value < 0x16FE0:
                                return False
                            if value > 0x16FE4:
                                return False
                            return True
                        if value > 0x16FF6:
                            return False
                        return True
                    return True
                return True
            return True
        return True
    if value > 0x18CD5:
        if value < 0x1F3F8:
            if value < 0x1F18E:
                if value < 0x1B150:
                    if value < 0x1AFF5:
                        if value < 0x18D80:
                            if value < 0x18CFF:
                                return False
                            if value > 0x18D1E:
                                return False
                            return True
                        if value > 0x18DF2:
                            if value < 0x1AFF0:
                                return False
                            if value > 0x1AFF3:
                                return False
                            return True
                        return True
                    if value > 0x1AFFB:
                        if value < 0x1B000:
                            if value < 0x1AFFD:
                                return False
                            if value > 0x1AFFE:
                                return False
                            return True
                        if value > 0x1B122:
                            if value < 0x1B132:
                                return False
                            if value > 0x1B132:
                                return False
                            return True
                        return True
                    return True
                if value > 0x1B152:
                    if value < 0x1D300:
                        if value < 0x1B164:
                            if value < 0x1B155:
                                return False
                            if value > 0x1B155:
                                return False
                            return True
                        if value > 0x1B167:
                            if value < 0x1B170:
                                return False
                            if value > 0x1B2FB:
                                return False
                            return True
                        return True
                    if value > 0x1D356:
                        if value < 0x1F004:
                            if value < 0x1D360:
                                return False
                            if value > 0x1D376:
                                return False
                            return True
                        if value > 0x1F004:
                            if value < 0x1F0CF:
                                return False
                            if value > 0x1F0CF:
                                return False
                            return True
                        return True
                    return True
                return True
            if value > 0x1F18E:
                if value < 0x1F32D:
                    if value < 0x1F240:
                        if value < 0x1F1E6:
                            if value < 0x1F191:
                                return False
                            if value > 0x1F19A:
                                return False
                            return True
                        if value > 0x1F202:
                            if value < 0x1F210:
                                return False
                            if value > 0x1F23B:
                                return False
                            return True
                        return True
                    if value > 0x1F248:
                        if value < 0x1F260:
                            if value < 0x1F250:
                                return False
                            if value > 0x1F251:
                                return False
                            return True
                        if value > 0x1F265:
                            if value < 0x1F300:
                                return False
                            if value > 0x1F320:
                                return False
                            return True
                        return True
                    return True
                if value > 0x1F335:
                    if value < 0x1F3CF:
                        if value < 0x1F37E:
                            if value < 0x1F337:
                                return False
                            if value > 0x1F37C:
                                return False
                            return True
                        if value > 0x1F393:
                            if value < 0x1F3A0:
                                return False
                            if value > 0x1F3CA:
                                return False
                            return True
                        return True
                    if value > 0x1F3D3:
                        if value < 0x1F3F4:
                            if value < 0x1F3E0:
                                return False
                            if value > 0x1F3F0:
                                return False
                            return True
                        if value > 0x1F3F4:
                            return False
                        return True
                    return True
                return True
            return True
        if value > 0x1F43E:
            if value < 0x1F6F4:
                if value < 0x1F5A4:
                    if value < 0x1F54B:
                        if value < 0x1F442:
                            if value < 0x1F440:
                                return False
                            if value > 0x1F440:
                                return False
                            return True
                        if value > 0x1F4FC:
                            if value < 0x1F4FF:
                                return False
                            if value > 0x1F53D:
                                return False
                            return True
                        return True
                    if value > 0x1F54E:
                        if value < 0x1F57A:
                            if value < 0x1F550:
                                return False
                            if value > 0x1F567:
                                return False
                            return True
                        if value > 0x1F57A:
                            if value < 0x1F595:
                                return False
                            if value > 0x1F596:
                                return False
                            return True
                        return True
                    return True
                if value > 0x1F5A4:
                    if value < 0x1F6D0:
                        if value < 0x1F680:
                            if value < 0x1F5FB:
                                return False
                            if value > 0x1F64F:
                                return False
                            return True
                        if value > 0x1F6C5:
                            if value < 0x1F6CC:
                                return False
                            if value > 0x1F6CC:
                                return False
                            return True
                        return True
                    if value > 0x1F6D2:
                        if value < 0x1F6DC:
                            if value < 0x1F6D5:
                                return False
                            if value > 0x1F6D8:
                                return False
                            return True
                        if value > 0x1F6DF:
                            if value < 0x1F6EB:
                                return False
                            if value > 0x1F6EC:
                                return False
                            return True
                        return True
                    return True
                return True
            if value > 0x1F6FC:
                if value < 0x1FA8E:
                    if value < 0x1F93C:
                        if value < 0x1F7F0:
                            if value < 0x1F7E0:
                                return False
                            if value > 0x1F7EB:
                                return False
                            return True
                        if value > 0x1F7F0:
                            if value < 0x1F90C:
                                return False
                            if value > 0x1F93A:
                                return False
                            return True
                        return True
                    if value > 0x1F945:
                        if value < 0x1FA70:
                            if value < 0x1F947:
                                return False
                            if value > 0x1F9FF:
                                return False
                            return True
                        if value > 0x1FA7C:
                            if value < 0x1FA80:
                                return False
                            if value > 0x1FA8A:
                                return False
                            return True
                        return True
                    return True
                if value > 0x1FAC6:
                    if value < 0x1FAEF:
                        if value < 0x1FACD:
                            if value < 0x1FAC8:
                                return False
                            if value > 0x1FAC8:
                                return False
                            return True
                        if value > 0x1FADC:
                            if value < 0x1FADF:
                                return False
                            if value > 0x1FAEA:
                                return False
                            return True
                        return True
                    if value > 0x1FAF8:
                        if value < 0x30000:
                            if value < 0x20000:
                                return False
                            if value > 0x2FFFD:
                                return False
                            return True
                        if value > 0x3FFFD:
                            return False
                        return True
                    return True
                return True
            return True
        return True
    return True


def is_ambiguous(value: Int) -> Bool:
    if value < 0:
        return False
    if value < 0x2190:
        if value < 0x261:
            if value < 0x113:
                if value < 0xDE:
                    if value < 0xB0:
                        if value < 0xA7:
                            if value < 0xA4:
                                if value < 0xA1:
                                    return False
                                if value > 0xA1:
                                    return False
                                return True
                            if value > 0xA4:
                                return False
                            return True
                        if value > 0xA8:
                            if value < 0xAD:
                                if value < 0xAA:
                                    return False
                                if value > 0xAA:
                                    return False
                                return True
                            if value > 0xAE:
                                return False
                            return True
                        return True
                    if value > 0xB4:
                        if value < 0xC6:
                            if value < 0xBC:
                                if value < 0xB6:
                                    return False
                                if value > 0xBA:
                                    return False
                                return True
                            if value > 0xBF:
                                return False
                            return True
                        if value > 0xC6:
                            if value < 0xD7:
                                if value < 0xD0:
                                    return False
                                if value > 0xD0:
                                    return False
                                return True
                            if value > 0xD8:
                                return False
                            return True
                        return True
                    return True
                if value > 0xE1:
                    if value < 0xF7:
                        if value < 0xEC:
                            if value < 0xE8:
                                if value < 0xE6:
                                    return False
                                if value > 0xE6:
                                    return False
                                return True
                            if value > 0xEA:
                                return False
                            return True
                        if value > 0xED:
                            if value < 0xF2:
                                if value < 0xF0:
                                    return False
                                if value > 0xF0:
                                    return False
                                return True
                            if value > 0xF3:
                                return False
                            return True
                        return True
                    if value > 0xFA:
                        if value < 0x101:
                            if value < 0xFE:
                                if value < 0xFC:
                                    return False
                                if value > 0xFC:
                                    return False
                                return True
                            if value > 0xFE:
                                return False
                            return True
                        if value > 0x101:
                            if value < 0x111:
                                return False
                            if value > 0x111:
                                return False
                            return True
                        return True
                    return True
                return True
            if value > 0x113:
                if value < 0x166:
                    if value < 0x13F:
                        if value < 0x12B:
                            if value < 0x126:
                                if value < 0x11B:
                                    return False
                                if value > 0x11B:
                                    return False
                                return True
                            if value > 0x127:
                                return False
                            return True
                        if value > 0x12B:
                            if value < 0x138:
                                if value < 0x131:
                                    return False
                                if value > 0x133:
                                    return False
                                return True
                            if value > 0x138:
                                return False
                            return True
                        return True
                    if value > 0x142:
                        if value < 0x14D:
                            if value < 0x148:
                                if value < 0x144:
                                    return False
                                if value > 0x144:
                                    return False
                                return True
                            if value > 0x14B:
                                return False
                            return True
                        if value > 0x14D:
                            if value < 0x152:
                                return False
                            if value > 0x153:
                                return False
                            return True
                        return True
                    return True
                if value > 0x167:
                    if value < 0x1D6:
                        if value < 0x1D0:
                            if value < 0x1CE:
                                if value < 0x16B:
                                    return False
                                if value > 0x16B:
                                    return False
                                return True
                            if value > 0x1CE:
                                return False
                            return True
                        if value > 0x1D0:
                            if value < 0x1D4:
                                if value < 0x1D2:
                                    return False
                                if value > 0x1D2:
                                    return False
                                return True
                            if value > 0x1D4:
                                return False
                            return True
                        return True
                    if value > 0x1D6:
                        if value < 0x1DC:
                            if value < 0x1DA:
                                if value < 0x1D8:
                                    return False
                                if value > 0x1D8:
                                    return False
                                return True
                            if value > 0x1DA:
                                return False
                            return True
                        if value > 0x1DC:
                            if value < 0x251:
                                return False
                            if value > 0x251:
                                return False
                            return True
                        return True
                    return True
                return True
            return True
        if value > 0x261:
            if value < 0x2030:
                if value < 0x3B1:
                    if value < 0x2D8:
                        if value < 0x2C9:
                            if value < 0x2C7:
                                if value < 0x2C4:
                                    return False
                                if value > 0x2C4:
                                    return False
                                return True
                            if value > 0x2C7:
                                return False
                            return True
                        if value > 0x2CB:
                            if value < 0x2D0:
                                if value < 0x2CD:
                                    return False
                                if value > 0x2CD:
                                    return False
                                return True
                            if value > 0x2D0:
                                return False
                            return True
                        return True
                    if value > 0x2DB:
                        if value < 0x300:
                            if value < 0x2DF:
                                if value < 0x2DD:
                                    return False
                                if value > 0x2DD:
                                    return False
                                return True
                            if value > 0x2DF:
                                return False
                            return True
                        if value > 0x36F:
                            if value < 0x3A3:
                                if value < 0x391:
                                    return False
                                if value > 0x3A1:
                                    return False
                                return True
                            if value > 0x3A9:
                                return False
                            return True
                        return True
                    return True
                if value > 0x3C1:
                    if value < 0x2013:
                        if value < 0x410:
                            if value < 0x401:
                                if value < 0x3C3:
                                    return False
                                if value > 0x3C9:
                                    return False
                                return True
                            if value > 0x401:
                                return False
                            return True
                        if value > 0x44F:
                            if value < 0x2010:
                                if value < 0x451:
                                    return False
                                if value > 0x451:
                                    return False
                                return True
                            if value > 0x2010:
                                return False
                            return True
                        return True
                    if value > 0x2016:
                        if value < 0x2020:
                            if value < 0x201C:
                                if value < 0x2018:
                                    return False
                                if value > 0x2019:
                                    return False
                                return True
                            if value > 0x201D:
                                return False
                            return True
                        if value > 0x2022:
                            if value < 0x2024:
                                return False
                            if value > 0x2027:
                                return False
                            return True
                        return True
                    return True
                return True
            if value > 0x2030:
                if value < 0x2109:
                    if value < 0x207F:
                        if value < 0x203B:
                            if value < 0x2035:
                                if value < 0x2032:
                                    return False
                                if value > 0x2033:
                                    return False
                                return True
                            if value > 0x2035:
                                return False
                            return True
                        if value > 0x203B:
                            if value < 0x2074:
                                if value < 0x203E:
                                    return False
                                if value > 0x203E:
                                    return False
                                return True
                            if value > 0x2074:
                                return False
                            return True
                        return True
                    if value > 0x207F:
                        if value < 0x2103:
                            if value < 0x20AC:
                                if value < 0x2081:
                                    return False
                                if value > 0x2084:
                                    return False
                                return True
                            if value > 0x20AC:
                                return False
                            return True
                        if value > 0x2103:
                            if value < 0x2105:
                                return False
                            if value > 0x2105:
                                return False
                            return True
                        return True
                    return True
                if value > 0x2109:
                    if value < 0x2153:
                        if value < 0x2121:
                            if value < 0x2116:
                                if value < 0x2113:
                                    return False
                                if value > 0x2113:
                                    return False
                                return True
                            if value > 0x2116:
                                return False
                            return True
                        if value > 0x2122:
                            if value < 0x212B:
                                if value < 0x2126:
                                    return False
                                if value > 0x2126:
                                    return False
                                return True
                            if value > 0x212B:
                                return False
                            return True
                        return True
                    if value > 0x2154:
                        if value < 0x2170:
                            if value < 0x2160:
                                if value < 0x215B:
                                    return False
                                if value > 0x215E:
                                    return False
                                return True
                            if value > 0x216B:
                                return False
                            return True
                        if value > 0x2179:
                            if value < 0x2189:
                                return False
                            if value > 0x2189:
                                return False
                            return True
                        return True
                    return True
                return True
            return True
        return True
    if value > 0x2199:
        if value < 0x25C6:
            if value < 0x2260:
                if value < 0x221A:
                    if value < 0x2202:
                        if value < 0x21D4:
                            if value < 0x21D2:
                                if value < 0x21B8:
                                    return False
                                if value > 0x21B9:
                                    return False
                                return True
                            if value > 0x21D2:
                                return False
                            return True
                        if value > 0x21D4:
                            if value < 0x2200:
                                if value < 0x21E7:
                                    return False
                                if value > 0x21E7:
                                    return False
                                return True
                            if value > 0x2200:
                                return False
                            return True
                        return True
                    if value > 0x2203:
                        if value < 0x220F:
                            if value < 0x220B:
                                if value < 0x2207:
                                    return False
                                if value > 0x2208:
                                    return False
                                return True
                            if value > 0x220B:
                                return False
                            return True
                        if value > 0x220F:
                            if value < 0x2215:
                                if value < 0x2211:
                                    return False
                                if value > 0x2211:
                                    return False
                                return True
                            if value > 0x2215:
                                return False
                            return True
                        return True
                    return True
                if value > 0x221A:
                    if value < 0x2234:
                        if value < 0x2225:
                            if value < 0x2223:
                                if value < 0x221D:
                                    return False
                                if value > 0x2220:
                                    return False
                                return True
                            if value > 0x2223:
                                return False
                            return True
                        if value > 0x2225:
                            if value < 0x222E:
                                if value < 0x2227:
                                    return False
                                if value > 0x222C:
                                    return False
                                return True
                            if value > 0x222E:
                                return False
                            return True
                        return True
                    if value > 0x2237:
                        if value < 0x224C:
                            if value < 0x2248:
                                if value < 0x223C:
                                    return False
                                if value > 0x223D:
                                    return False
                                return True
                            if value > 0x2248:
                                return False
                            return True
                        if value > 0x224C:
                            if value < 0x2252:
                                return False
                            if value > 0x2252:
                                return False
                            return True
                        return True
                    return True
                return True
            if value > 0x2261:
                if value < 0x2460:
                    if value < 0x2295:
                        if value < 0x226E:
                            if value < 0x226A:
                                if value < 0x2264:
                                    return False
                                if value > 0x2267:
                                    return False
                                return True
                            if value > 0x226B:
                                return False
                            return True
                        if value > 0x226F:
                            if value < 0x2286:
                                if value < 0x2282:
                                    return False
                                if value > 0x2283:
                                    return False
                                return True
                            if value > 0x2287:
                                return False
                            return True
                        return True
                    if value > 0x2295:
                        if value < 0x22BF:
                            if value < 0x22A5:
                                if value < 0x2299:
                                    return False
                                if value > 0x2299:
                                    return False
                                return True
                            if value > 0x22A5:
                                return False
                            return True
                        if value > 0x22BF:
                            if value < 0x2312:
                                return False
                            if value > 0x2312:
                                return False
                            return True
                        return True
                    return True
                if value > 0x24E9:
                    if value < 0x25A3:
                        if value < 0x2580:
                            if value < 0x2550:
                                if value < 0x24EB:
                                    return False
                                if value > 0x254B:
                                    return False
                                return True
                            if value > 0x2573:
                                return False
                            return True
                        if value > 0x258F:
                            if value < 0x25A0:
                                if value < 0x2592:
                                    return False
                                if value > 0x2595:
                                    return False
                                return True
                            if value > 0x25A1:
                                return False
                            return True
                        return True
                    if value > 0x25A9:
                        if value < 0x25BC:
                            if value < 0x25B6:
                                if value < 0x25B2:
                                    return False
                                if value > 0x25B3:
                                    return False
                                return True
                            if value > 0x25B7:
                                return False
                            return True
                        if value > 0x25BD:
                            if value < 0x25C0:
                                return False
                            if value > 0x25C1:
                                return False
                            return True
                        return True
                    return True
                return True
            return True
        if value > 0x25C8:
            if value < 0x26E8:
                if value < 0x2660:
                    if value < 0x2609:
                        if value < 0x25E2:
                            if value < 0x25CE:
                                if value < 0x25CB:
                                    return False
                                if value > 0x25CB:
                                    return False
                                return True
                            if value > 0x25D1:
                                return False
                            return True
                        if value > 0x25E5:
                            if value < 0x2605:
                                if value < 0x25EF:
                                    return False
                                if value > 0x25EF:
                                    return False
                                return True
                            if value > 0x2606:
                                return False
                            return True
                        return True
                    if value > 0x2609:
                        if value < 0x261E:
                            if value < 0x261C:
                                if value < 0x260E:
                                    return False
                                if value > 0x260F:
                                    return False
                                return True
                            if value > 0x261C:
                                return False
                            return True
                        if value > 0x261E:
                            if value < 0x2642:
                                if value < 0x2640:
                                    return False
                                if value > 0x2640:
                                    return False
                                return True
                            if value > 0x2642:
                                return False
                            return True
                        return True
                    return True
                if value > 0x2661:
                    if value < 0x26BF:
                        if value < 0x266C:
                            if value < 0x2667:
                                if value < 0x2663:
                                    return False
                                if value > 0x2665:
                                    return False
                                return True
                            if value > 0x266A:
                                return False
                            return True
                        if value > 0x266D:
                            if value < 0x269E:
                                if value < 0x266F:
                                    return False
                                if value > 0x266F:
                                    return False
                                return True
                            if value > 0x269F:
                                return False
                            return True
                        return True
                    if value > 0x26BF:
                        if value < 0x26D5:
                            if value < 0x26CF:
                                if value < 0x26C6:
                                    return False
                                if value > 0x26CD:
                                    return False
                                return True
                            if value > 0x26D3:
                                return False
                            return True
                        if value > 0x26E1:
                            if value < 0x26E3:
                                return False
                            if value > 0x26E3:
                                return False
                            return True
                        return True
                    return True
                return True
            if value > 0x26E9:
                if value < 0xFE00:
                    if value < 0x273D:
                        if value < 0x26F6:
                            if value < 0x26F4:
                                if value < 0x26EB:
                                    return False
                                if value > 0x26F1:
                                    return False
                                return True
                            if value > 0x26F4:
                                return False
                            return True
                        if value > 0x26F9:
                            if value < 0x26FE:
                                if value < 0x26FB:
                                    return False
                                if value > 0x26FC:
                                    return False
                                return True
                            if value > 0x26FF:
                                return False
                            return True
                        return True
                    if value > 0x273D:
                        if value < 0x3248:
                            if value < 0x2B56:
                                if value < 0x2776:
                                    return False
                                if value > 0x277F:
                                    return False
                                return True
                            if value > 0x2B59:
                                return False
                            return True
                        if value > 0x324F:
                            if value < 0xE000:
                                return False
                            if value > 0xF8FF:
                                return False
                            return True
                        return True
                    return True
                if value > 0xFE0F:
                    if value < 0x1F18F:
                        if value < 0x1F110:
                            if value < 0x1F100:
                                if value < 0xFFFD:
                                    return False
                                if value > 0xFFFD:
                                    return False
                                return True
                            if value > 0x1F10A:
                                return False
                            return True
                        if value > 0x1F12D:
                            if value < 0x1F170:
                                if value < 0x1F130:
                                    return False
                                if value > 0x1F169:
                                    return False
                                return True
                            if value > 0x1F18D:
                                return False
                            return True
                        return True
                    if value > 0x1F190:
                        if value < 0xF0000:
                            if value < 0xE0100:
                                if value < 0x1F19B:
                                    return False
                                if value > 0x1F1AC:
                                    return False
                                return True
                            if value > 0xE01EF:
                                return False
                            return True
                        if value > 0xFFFFD:
                            if value < 0x100000:
                                return False
                            if value > 0x10FFFD:
                                return False
                            return True
                        return True
                    return True
                return True
            return True
        return True
    return True


def is_emoji(value: Int) -> Bool:
    if value < 0:
        return False
    if value < 0x2757:
        if value < 0x2663:
            if value < 0x25B6:
                if value < 0x2194:
                    if value < 0xAE:
                        if value < 0x30:
                            if value < 0x2A:
                                if value < 0x23:
                                    return False
                                if value > 0x23:
                                    return False
                                return True
                            if value > 0x2A:
                                return False
                            return True
                        if value > 0x39:
                            if value < 0xA9:
                                return False
                            if value > 0xA9:
                                return False
                            return True
                        return True
                    if value > 0xAE:
                        if value < 0x2122:
                            if value < 0x2049:
                                if value < 0x203C:
                                    return False
                                if value > 0x203C:
                                    return False
                                return True
                            if value > 0x2049:
                                return False
                            return True
                        if value > 0x2122:
                            if value < 0x2139:
                                return False
                            if value > 0x2139:
                                return False
                            return True
                        return True
                    return True
                if value > 0x2199:
                    if value < 0x23E9:
                        if value < 0x2328:
                            if value < 0x231A:
                                if value < 0x21A9:
                                    return False
                                if value > 0x21AA:
                                    return False
                                return True
                            if value > 0x231B:
                                return False
                            return True
                        if value > 0x2328:
                            if value < 0x23CF:
                                return False
                            if value > 0x23CF:
                                return False
                            return True
                        return True
                    if value > 0x23F3:
                        if value < 0x24C2:
                            if value < 0x23F8:
                                return False
                            if value > 0x23FA:
                                return False
                            return True
                        if value > 0x24C2:
                            if value < 0x25AA:
                                return False
                            if value > 0x25AB:
                                return False
                            return True
                        return True
                    return True
                return True
            if value > 0x25B6:
                if value < 0x2622:
                    if value < 0x2611:
                        if value < 0x2600:
                            if value < 0x25FB:
                                if value < 0x25C0:
                                    return False
                                if value > 0x25C0:
                                    return False
                                return True
                            if value > 0x25FE:
                                return False
                            return True
                        if value > 0x2604:
                            if value < 0x260E:
                                return False
                            if value > 0x260E:
                                return False
                            return True
                        return True
                    if value > 0x2611:
                        if value < 0x261D:
                            if value < 0x2618:
                                if value < 0x2614:
                                    return False
                                if value > 0x2615:
                                    return False
                                return True
                            if value > 0x2618:
                                return False
                            return True
                        if value > 0x261D:
                            if value < 0x2620:
                                return False
                            if value > 0x2620:
                                return False
                            return True
                        return True
                    return True
                if value > 0x2623:
                    if value < 0x2640:
                        if value < 0x262E:
                            if value < 0x262A:
                                if value < 0x2626:
                                    return False
                                if value > 0x2626:
                                    return False
                                return True
                            if value > 0x262A:
                                return False
                            return True
                        if value > 0x262F:
                            if value < 0x2638:
                                return False
                            if value > 0x263A:
                                return False
                            return True
                        return True
                    if value > 0x2640:
                        if value < 0x2648:
                            if value < 0x2642:
                                return False
                            if value > 0x2642:
                                return False
                            return True
                        if value > 0x2653:
                            if value < 0x265F:
                                return False
                            if value > 0x2660:
                                return False
                            return True
                        return True
                    return True
                return True
            return True
        if value > 0x2663:
            if value < 0x26F0:
                if value < 0x26AA:
                    if value < 0x2692:
                        if value < 0x267B:
                            if value < 0x2668:
                                if value < 0x2665:
                                    return False
                                if value > 0x2666:
                                    return False
                                return True
                            if value > 0x2668:
                                return False
                            return True
                        if value > 0x267B:
                            if value < 0x267E:
                                return False
                            if value > 0x267F:
                                return False
                            return True
                        return True
                    if value > 0x2697:
                        if value < 0x26A0:
                            if value < 0x269B:
                                if value < 0x2699:
                                    return False
                                if value > 0x2699:
                                    return False
                                return True
                            if value > 0x269C:
                                return False
                            return True
                        if value > 0x26A1:
                            if value < 0x26A7:
                                return False
                            if value > 0x26A7:
                                return False
                            return True
                        return True
                    return True
                if value > 0x26AB:
                    if value < 0x26CE:
                        if value < 0x26C4:
                            if value < 0x26BD:
                                if value < 0x26B0:
                                    return False
                                if value > 0x26B1:
                                    return False
                                return True
                            if value > 0x26BE:
                                return False
                            return True
                        if value > 0x26C5:
                            if value < 0x26C8:
                                return False
                            if value > 0x26C8:
                                return False
                            return True
                        return True
                    if value > 0x26CF:
                        if value < 0x26D3:
                            if value < 0x26D1:
                                return False
                            if value > 0x26D1:
                                return False
                            return True
                        if value > 0x26D4:
                            if value < 0x26E9:
                                return False
                            if value > 0x26EA:
                                return False
                            return True
                        return True
                    return True
                return True
            if value > 0x26F5:
                if value < 0x271D:
                    if value < 0x2708:
                        if value < 0x2702:
                            if value < 0x26FD:
                                if value < 0x26F7:
                                    return False
                                if value > 0x26FA:
                                    return False
                                return True
                            if value > 0x26FD:
                                return False
                            return True
                        if value > 0x2702:
                            if value < 0x2705:
                                return False
                            if value > 0x2705:
                                return False
                            return True
                        return True
                    if value > 0x270D:
                        if value < 0x2714:
                            if value < 0x2712:
                                if value < 0x270F:
                                    return False
                                if value > 0x270F:
                                    return False
                                return True
                            if value > 0x2712:
                                return False
                            return True
                        if value > 0x2714:
                            if value < 0x2716:
                                return False
                            if value > 0x2716:
                                return False
                            return True
                        return True
                    return True
                if value > 0x271D:
                    if value < 0x2747:
                        if value < 0x2733:
                            if value < 0x2728:
                                if value < 0x2721:
                                    return False
                                if value > 0x2721:
                                    return False
                                return True
                            if value > 0x2728:
                                return False
                            return True
                        if value > 0x2734:
                            if value < 0x2744:
                                return False
                            if value > 0x2744:
                                return False
                            return True
                        return True
                    if value > 0x2747:
                        if value < 0x274E:
                            if value < 0x274C:
                                return False
                            if value > 0x274C:
                                return False
                            return True
                        if value > 0x274E:
                            if value < 0x2753:
                                return False
                            if value > 0x2755:
                                return False
                            return True
                        return True
                    return True
                return True
            return True
        return True
    if value > 0x2757:
        if value < 0x1F573:
            if value < 0x1F18E:
                if value < 0x2B55:
                    if value < 0x27BF:
                        if value < 0x27A1:
                            if value < 0x2795:
                                if value < 0x2763:
                                    return False
                                if value > 0x2764:
                                    return False
                                return True
                            if value > 0x2797:
                                return False
                            return True
                        if value > 0x27A1:
                            if value < 0x27B0:
                                return False
                            if value > 0x27B0:
                                return False
                            return True
                        return True
                    if value > 0x27BF:
                        if value < 0x2B1B:
                            if value < 0x2B05:
                                if value < 0x2934:
                                    return False
                                if value > 0x2935:
                                    return False
                                return True
                            if value > 0x2B07:
                                return False
                            return True
                        if value > 0x2B1C:
                            if value < 0x2B50:
                                return False
                            if value > 0x2B50:
                                return False
                            return True
                        return True
                    return True
                if value > 0x2B55:
                    if value < 0x1F004:
                        if value < 0x3297:
                            if value < 0x303D:
                                if value < 0x3030:
                                    return False
                                if value > 0x3030:
                                    return False
                                return True
                            if value > 0x303D:
                                return False
                            return True
                        if value > 0x3297:
                            if value < 0x3299:
                                return False
                            if value > 0x3299:
                                return False
                            return True
                        return True
                    if value > 0x1F004:
                        if value < 0x1F170:
                            if value < 0x1F0CF:
                                return False
                            if value > 0x1F0CF:
                                return False
                            return True
                        if value > 0x1F171:
                            if value < 0x1F17E:
                                return False
                            if value > 0x1F17F:
                                return False
                            return True
                        return True
                    return True
                return True
            if value > 0x1F18E:
                if value < 0x1F396:
                    if value < 0x1F22F:
                        if value < 0x1F201:
                            if value < 0x1F1E6:
                                if value < 0x1F191:
                                    return False
                                if value > 0x1F19A:
                                    return False
                                return True
                            if value > 0x1F1FF:
                                return False
                            return True
                        if value > 0x1F202:
                            if value < 0x1F21A:
                                return False
                            if value > 0x1F21A:
                                return False
                            return True
                        return True
                    if value > 0x1F22F:
                        if value < 0x1F300:
                            if value < 0x1F250:
                                if value < 0x1F232:
                                    return False
                                if value > 0x1F23A:
                                    return False
                                return True
                            if value > 0x1F251:
                                return False
                            return True
                        if value > 0x1F321:
                            if value < 0x1F324:
                                return False
                            if value > 0x1F393:
                                return False
                            return True
                        return True
                    return True
                if value > 0x1F397:
                    if value < 0x1F4FF:
                        if value < 0x1F3F3:
                            if value < 0x1F39E:
                                if value < 0x1F399:
                                    return False
                                if value > 0x1F39B:
                                    return False
                                return True
                            if value > 0x1F3F0:
                                return False
                            return True
                        if value > 0x1F3F5:
                            if value < 0x1F3F7:
                                return False
                            if value > 0x1F4FD:
                                return False
                            return True
                        return True
                    if value > 0x1F53D:
                        if value < 0x1F550:
                            if value < 0x1F549:
                                return False
                            if value > 0x1F54E:
                                return False
                            return True
                        if value > 0x1F567:
                            if value < 0x1F56F:
                                return False
                            if value > 0x1F570:
                                return False
                            return True
                        return True
                    return True
                return True
            return True
        if value > 0x1F57A:
            if value < 0x1F6CB:
                if value < 0x1F5D1:
                    if value < 0x1F5A4:
                        if value < 0x1F590:
                            if value < 0x1F58A:
                                if value < 0x1F587:
                                    return False
                                if value > 0x1F587:
                                    return False
                                return True
                            if value > 0x1F58D:
                                return False
                            return True
                        if value > 0x1F590:
                            if value < 0x1F595:
                                return False
                            if value > 0x1F596:
                                return False
                            return True
                        return True
                    if value > 0x1F5A5:
                        if value < 0x1F5BC:
                            if value < 0x1F5B1:
                                if value < 0x1F5A8:
                                    return False
                                if value > 0x1F5A8:
                                    return False
                                return True
                            if value > 0x1F5B2:
                                return False
                            return True
                        if value > 0x1F5BC:
                            if value < 0x1F5C2:
                                return False
                            if value > 0x1F5C4:
                                return False
                            return True
                        return True
                    return True
                if value > 0x1F5D3:
                    if value < 0x1F5EF:
                        if value < 0x1F5E3:
                            if value < 0x1F5E1:
                                if value < 0x1F5DC:
                                    return False
                                if value > 0x1F5DE:
                                    return False
                                return True
                            if value > 0x1F5E1:
                                return False
                            return True
                        if value > 0x1F5E3:
                            if value < 0x1F5E8:
                                return False
                            if value > 0x1F5E8:
                                return False
                            return True
                        return True
                    if value > 0x1F5EF:
                        if value < 0x1F5FA:
                            if value < 0x1F5F3:
                                return False
                            if value > 0x1F5F3:
                                return False
                            return True
                        if value > 0x1F64F:
                            if value < 0x1F680:
                                return False
                            if value > 0x1F6C5:
                                return False
                            return True
                        return True
                    return True
                return True
            if value > 0x1F6D2:
                if value < 0x1F93C:
                    if value < 0x1F6F0:
                        if value < 0x1F6E9:
                            if value < 0x1F6DC:
                                if value < 0x1F6D5:
                                    return False
                                if value > 0x1F6D8:
                                    return False
                                return True
                            if value > 0x1F6E5:
                                return False
                            return True
                        if value > 0x1F6E9:
                            if value < 0x1F6EB:
                                return False
                            if value > 0x1F6EC:
                                return False
                            return True
                        return True
                    if value > 0x1F6F0:
                        if value < 0x1F7F0:
                            if value < 0x1F7E0:
                                if value < 0x1F6F3:
                                    return False
                                if value > 0x1F6FC:
                                    return False
                                return True
                            if value > 0x1F7EB:
                                return False
                            return True
                        if value > 0x1F7F0:
                            if value < 0x1F90C:
                                return False
                            if value > 0x1F93A:
                                return False
                            return True
                        return True
                    return True
                if value > 0x1F945:
                    if value < 0x1FAC8:
                        if value < 0x1FA80:
                            if value < 0x1FA70:
                                if value < 0x1F947:
                                    return False
                                if value > 0x1F9FF:
                                    return False
                                return True
                            if value > 0x1FA7C:
                                return False
                            return True
                        if value > 0x1FA8A:
                            if value < 0x1FA8E:
                                return False
                            if value > 0x1FAC6:
                                return False
                            return True
                        return True
                    if value > 0x1FAC8:
                        if value < 0x1FADF:
                            if value < 0x1FACD:
                                return False
                            if value > 0x1FADC:
                                return False
                            return True
                        if value > 0x1FAEA:
                            if value < 0x1FAEF:
                                return False
                            if value > 0x1FAF8:
                                return False
                            return True
                        return True
                    return True
                return True
            return True
        return True
    return True


def is_whitespace(value: Int) -> Bool:
    if value < 0:
        return False
    if value < 0x2000:
        if value < 0x85:
            if value < 0x20:
                if value < 0x9:
                    return False
                if value > 0xD:
                    return False
                return True
            if value > 0x20:
                return False
            return True
        if value > 0x85:
            if value < 0x1680:
                if value < 0xA0:
                    return False
                if value > 0xA0:
                    return False
                return True
            if value > 0x1680:
                return False
            return True
        return True
    if value > 0x200A:
        if value < 0x205F:
            if value < 0x202F:
                if value < 0x2028:
                    return False
                if value > 0x2029:
                    return False
                return True
            if value > 0x202F:
                return False
            return True
        if value > 0x205F:
            if value < 0x3000:
                return False
            if value > 0x3000:
                return False
            return True
        return True
    return True
