import CarPlay
import UIKit

@available(iOS 14.0, *)
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        let listTemplate = createLibraryTemplate()
        interfaceController.setRootTemplate(listTemplate, animated: true, completion: nil)
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.interfaceController = nil
    }

    private func createLibraryTemplate() -> CPListTemplate {
        let playItem = CPListItem(text: "Play", detailText: "Now Playing", image: nil)
        playItem.handler = { _, completion in
            NotificationCenter.default.post(name: NSNotification.Name("MelodiRemotePlay"), object: nil)
            completion()
        }
        let pauseItem = CPListItem(text: "Pause", detailText: "Pause playback", image: nil)
        pauseItem.handler = { _, completion in
            NotificationCenter.default.post(name: NSNotification.Name("MelodiRemotePause"), object: nil)
            completion()
        }
        let nextItem = CPListItem(text: "Next", detailText: "Next track", image: nil)
        nextItem.handler = { _, completion in
            NotificationCenter.default.post(name: NSNotification.Name("MelodiRemoteNext"), object: nil)
            completion()
        }
        let section = CPListSection(items: [playItem, pauseItem, nextItem],
                                    header: "Melodi — LA_Player gibi CarPlay",
                                    sectionIndexTitle: nil)
        let template = CPListTemplate(title: "Melodi", sections: [section])
        template.tabTitle = "Library"
        return template
    }
}
