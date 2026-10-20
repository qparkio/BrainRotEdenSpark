require strings
require daslib/utf8_utils
require constants


// One visible line per message; limits count Unicode codepoints, not UTF-8 bytes.
def public clean_chat_text(value : string) : string {
    if (length(value) > CHAT_MAX_BYTES || !is_utf8_string_valid(value)) {
        return ""
    }
    let message = trim(replace(replace(replace(value, "\r", " "), "\n", " "), "\t", " "))
    if (empty(message) || utf8_length(message) > CHAT_MAX_CHARACTERS) {
        return ""
    }
    let codepoints <- utf8_decode(message)
    for (ch in codepoints) {
        if (ch < 32u || ch == 127u || ch == 0x2028u || ch == 0x2029u) {
            return ""
        }
    }
    return message
}
