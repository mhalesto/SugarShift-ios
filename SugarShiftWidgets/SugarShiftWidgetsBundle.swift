import WidgetKit
import SwiftUI

@main
struct SugarShiftWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DailyChallengeWidget()
        if #available(iOSApplicationExtension 16.1, *) {
            LifeRegenLiveActivity()
        }
    }
}
