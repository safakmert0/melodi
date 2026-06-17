import CarPlay
import MediaPlayer
import Flutter

class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private var nowPlayingTemplate: CPNowPlayingTemplate {
        return CPNowPlayingTemplate.shared
    }

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        setupRootTemplate()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }

    // MARK: - Setup

    private func setupRootTemplate() {
        let sections = [
            makeSection(title: "Favorites", icon: "heart.fill"),
            makeSection(title: "Playlists", icon: "music.note.list"),
            makeSection(title: "Albums", icon: "rectangle.stack.fill"),
            makeSection(title: "Artists", icon: "person.crop.rectangle.stack"),
            makeSection(title: "Songs", icon: "music.note"),
        ]

        let listTemplate = CPListTemplate(title: "Melodi", sections: sections)
        listTemplate.delegate = self

        let tabBar = CPTabBarTemplate(templates: [listTemplate, nowPlayingTemplate])
        interfaceController?.setRootTemplate(tabBar, animated: true)
    }

    private func makeSection(title: String, icon: String) -> CPListSection {
        let item = CPListItem(text: title, detailText: nil)
        item.handler = { [weak self] _, completion in
            self?.handleSectionTap(title)
            completion()
        }
        return CPListSection(items: [item])
    }

    private func handleSectionTap(_ title: String) {
        guard let interface = interfaceController else { return }
        let listTemplate = CPListTemplate(title: title, sections: [])
        listTemplate.delegate = self
        interface.pushTemplate(listTemplate, animated: true)
    }
}

// MARK: - CPListTemplateDelegate

extension CarPlaySceneDelegate: CPListTemplateDelegate {
    func listTemplate(
        _ listTemplate: CPListTemplate,
        didSelect listItem: CPListItem,
        completionHandler: @escaping () -> Void
    ) {
        let nowPlaying = CPNowPlayingTemplate.shared
        interfaceController?.pushTemplate(nowPlaying, animated: true)
        completionHandler()
    }
}
