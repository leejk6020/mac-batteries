import CoreGraphics
import Foundation

// Prints the window number of BatteryBar's popover, so screencapture can grab the
// window itself rather than a screen region. The popover uses a translucent
// material, and a region capture would bake whatever happens to be behind it into
// the shot.

let info = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

for window in info {
    guard let owner = window[kCGWindowOwnerName as String] as? String, owner == "BatteryBar",
          let number = window[kCGWindowNumber as String] as? Int,
          let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let height = bounds["Height"] as? Double
    else { continue }
    // The status item itself is also a window; the popover is the tall one.
    if height > 60 { print(number); exit(0) }
}
exit(1)
