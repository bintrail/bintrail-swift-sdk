import Foundation

private func bt_print_internal(_ items: [Any], terminator: String, prefix: StaticString) {
    let message = items.map { item in
        String(describing: item)
    }.joined(separator: terminator)

    Swift.print(prefix, message)
}

private func bt_log_internal(_ items: @autoclosure () -> [Any], terminator: String, prefix: StaticString) {
    #if DEBUG
    bt_print_internal(items(), terminator: terminator, prefix: prefix)
    #endif
}

internal func bt_print(_ items: Any..., terminator: String = " ") {
    bt_print_internal(items, terminator: terminator, prefix: "[BINTRAIL]")
}

internal func bt_log_internal(_ items: Any..., terminator: String = " ", prefix: StaticString = "[BINTRAIL DEBUG]") {
    bt_log_internal(items, terminator: terminator, prefix: prefix)
}
