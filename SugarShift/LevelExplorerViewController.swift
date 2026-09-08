#if DEBUG
import UIKit

/// A single presentation owns browsing, numeric entry and seed replay. Gameplay
/// remains in GameScene; this controller returns a selection after it dismisses.
final class LevelExplorerViewController: UIViewController, UISearchBarDelegate,
                                         UITextFieldDelegate, UIAdaptivePresentationControllerDelegate {
    var onSelect: ((Int, UInt64?) -> Void)?
    var onDismiss: (() -> Void)?

    private let config: LevelConfig
    private let openingSeed: UInt64
    private let stats: [String: Int]
    private let balance: LevelBalanceSnapshot
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let searchBar = UISearchBar()
    private let titleLabel = UILabel()
    private let backButton = UIButton(type: .system)
    private var selectedWorld: WorldThemeDefinition?
    private var showsSeedReplay = false
    private var showsBalanceDetails = false
    private var jumpDraft: String
    private var seedDraft: String
    private weak var levelField: UITextField?
    private weak var seedField: UITextField?
    private weak var entryError: UILabel?
    private var gridColumns = 4
    private var dismissalStarted = false
    private var dismissalDelivered = false
    private var pendingSelection: (level: Int, seed: UInt64?)?

    private static let recentKey = "SugarShift.Debug.LevelExplorer.recentLevels"
    private static let cream = UIColor(hex: "#FFF4E7")
    private static let ink = UIColor(hex: "#421D48")
    private static let muted = UIColor(hex: "#765A76")
    private static let berry = UIColor(hex: "#B92471")
    private static let gold = UIColor(hex: "#FFDC9A")

    init(config: LevelConfig, openingSeed: UInt64) {
        self.config = config
        self.openingSeed = openingSeed
        stats = Analytics.levelStats(for: config.number)
        balance = LevelBalanceAnalyzer.snapshot(for: config)
        jumpDraft = (1...Levels.count).contains(config.number) ? String(config.number) : ""
        seedDraft = String(openingSeed)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        presentationController?.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func loadView() {
        view = ExplorerGradientView(colors: [UIColor(hex: "#39294F"), UIColor(hex: "#161E38")])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityViewIsModal = true
        buildChrome()
        renderContent()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard scrollView.bounds.width > 0 else { return }
        let columns = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            ? 2 : (scrollView.bounds.width >= 600 ? 6 : (scrollView.bounds.width < 360 ? 3 : 4))
        if gridColumns != columns {
            gridColumns = columns
            renderContent()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if isViewLoaded,
           previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            renderContent()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Also release the scene guard if the presenting screen is removed.
        if isBeingDismissed || presentingViewController == nil { deliverDismissal() }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        deliverDismissal()
    }

    private func buildChrome() {
        let eyebrow = label(String(localized: "LEVEL TESTER"), style: .caption1, color: Self.gold)
        titleLabel.font = Self.font(.title2, heavy: true)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = Self.cream
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header
        let titles = stack([eyebrow, titleLabel], spacing: 3)

        var backStyle = UIButton.Configuration.plain()
        backStyle.image = UIImage(systemName: "chevron.left")
        backStyle.baseForegroundColor = Self.cream
        backStyle.contentInsets = .init(top: 12, leading: 8, bottom: 12, trailing: 8)
        backButton.configuration = backStyle
        backButton.accessibilityLabel = String(localized: "Back to worlds")
        backButton.accessibilityIdentifier = "levelExplorer.back"
        backButton.addAction(UIAction { [weak self] _ in self?.showWorlds() }, for: .touchUpInside)
        backButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true

        let close = button(String(localized: "Close"), symbol: "xmark", fill: UIColor.white.withAlphaComponent(0.12), ink: Self.cream) { [weak self] in
            self?.finish()
        }
        close.configuration?.title = nil
        close.accessibilityLabel = String(localized: "Close level tester")
        close.accessibilityIdentifier = "levelExplorer.close"
        close.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        close.setContentHuggingPriority(.required, for: .horizontal)
        let heading = stack([backButton, titles, close], axis: .horizontal, spacing: 10)
        heading.alignment = .center

        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = String(localized: "World name or level number")
        searchBar.delegate = self
        searchBar.returnKeyType = .search
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.tintColor = Self.berry
        searchBar.searchTextField.backgroundColor = Self.cream
        searchBar.searchTextField.textColor = Self.ink
        searchBar.searchTextField.attributedPlaceholder = NSAttributedString(
            string: String(localized: "World name or level number"),
            attributes: [.foregroundColor: Self.muted])
        searchBar.searchTextField.font = Self.font(.body)
        searchBar.searchTextField.adjustsFontForContentSizeCategory = true
        searchBar.searchTextField.leftView?.tintColor = Self.muted
        searchBar.searchTextField.accessibilityLabel = String(localized: "Search worlds and levels")
        searchBar.accessibilityIdentifier = "levelExplorer.search"
        let chrome = stack([heading, searchBar], spacing: 6)
        chrome.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chrome)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.indicatorStyle = .white
        scrollView.accessibilityIdentifier = "levelExplorer.content"
        view.addSubview(scrollView)
        contentStack.axis = .vertical
        contentStack.spacing = 18
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            chrome.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            chrome.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            chrome.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            scrollView.topAnchor.constraint(equalTo: chrome.bottomAnchor, constant: 2),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 10),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])
    }

    private func renderContent(resetScroll: Bool = false) {
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        backButton.isHidden = selectedWorld == nil && !showsSeedReplay
        searchBar.isHidden = showsSeedReplay
        titleLabel.text = showsSeedReplay ? String(localized: "Replay seed")
            : selectedWorld?.displayName ?? String(localized: "Level explorer")

        let query = (searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if showsSeedReplay { addSeedForm() }
        else if !query.isEmpty { addSearchResults(query) }
        else if let world = selectedWorld { addWorldLevels(world) }
        else { addOverview() }
        if resetScroll { scrollView.setContentOffset(.zero, animated: false) }
    }

    private func addOverview() {
        contentStack.addArrangedSubview(currentLevelCard())
        let previous = button(String(localized: "Previous"), symbol: "chevron.left", fill: UIColor(hex: "#354366"), ink: Self.cream) { [weak self] in
            guard let self else { return }
            self.finish(level: self.config.number - 1)
        }
        previous.isEnabled = (1...Levels.count).contains(config.number - 1)
        previous.accessibilityIdentifier = "levelExplorer.previous"
        let next = button(String(localized: "Next level"), symbol: "chevron.right", fill: Self.berry, ink: .white) { [weak self] in
            guard let self else { return }
            self.finish(level: self.config.number + 1)
        }
        next.configuration?.imagePlacement = .trailing
        next.isEnabled = (1...Levels.count).contains(config.number + 1)
        next.accessibilityIdentifier = "levelExplorer.next"
        contentStack.addArrangedSubview(adaptiveRow([previous, next]))
        contentStack.addArrangedSubview(jumpCard())

        let recent = Self.recentLevels.filter { $0 != config.number }
        if !recent.isEmpty {
            contentStack.addArrangedSubview(sectionTitle(String(localized: "Recent jumps")))
            contentStack.addArrangedSubview(levelGrid(recent))
        }
        let heading = stack([
            sectionTitle(String(localized: "Choose a world")),
            label(String(localized: "\(WorldThemes.all.count) worlds · \(Levels.count) levels"), style: .subheadline, color: UIColor(hex: "#D8CAE2"))
        ], spacing: 4)
        contentStack.addArrangedSubview(heading)
        WorldThemes.all.forEach { contentStack.addArrangedSubview(worldCard($0)) }
        contentStack.addArrangedSubview(label(String(localized: "Jumping does not spend lives or unlock skipped levels. Completing a level still saves normal progress."), style: .footnote, color: UIColor(hex: "#D8CAE2")))
    }

    private func currentLevelCard() -> UIView {
        let world = WorldThemes.theme(for: config.number)
        let campaign = (1...Levels.count).contains(config.number)
        let currentTitle = config.number == Levels.towerLevel ? String(localized: "Sugar Tower")
            : config.number == Levels.endlessLevel ? String(localized: "Score Rush")
            : String(localized: "Level \(config.number)")
        let image = UIImageView(image: UIImage(named: world.backgroundAsset))
        image.contentMode = .scaleAspectFill
        image.clipsToBounds = true
        image.layer.cornerRadius = 15
        image.isAccessibilityElement = false
        image.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            image.widthAnchor.constraint(equalToConstant: 68),
            image.heightAnchor.constraint(equalToConstant: 76)
        ])
        let titles = stack([
            label(String(localized: "CURRENT GAME"), style: .caption1, color: Self.muted),
            label(currentTitle, style: .title2, color: Self.ink, heavy: true),
            label(campaign ? world.displayName : config.difficulty.displayName, style: .subheadline, color: Self.muted)
        ], spacing: 3)
        let heading = stack([image, titles], axis: .horizontal, spacing: 12)
        heading.alignment = .center

        let attempts = stats["attempts"] ?? 0
        let wins = stats["wins"] ?? 0
        let winRate = attempts > 0 ? Double(wins) / Double(attempts)
            : LevelBalanceAnalyzer.estimatedWinRate(for: config)
        let stars = wins > 0 ? Double(stats["stars_total"] ?? 0) / Double(wins)
            : LevelBalanceAnalyzer.estimatedAverageStars(for: config)
        let moves = wins > 0 ? Double(stats["moves_left_total"] ?? 0) / Double(wins)
            : Double(config.moves) * 0.22
        let balanceLabel = LevelBalanceAnalyzer.balanceLabel(winRate: winRate, averageStars: stars)
        let statusText = balanceLabel == "Too hard" ? String(localized: "Too hard")
            : balanceLabel == "Too easy" ? String(localized: "Too easy") : String(localized: "Fair")
        let statusColor = balanceLabel == "Too hard" ? UIColor(hex: "#A52C48")
            : balanceLabel == "Too easy" ? UIColor(hex: "#8B500F") : UIColor(hex: "#176650")
        let source = attempts > 0 ? String(localized: "\(attempts) played attempts") : String(localized: "Catalog estimate")
        let metrics = adaptiveRow([
            metric(String(localized: "Win rate"), value: String(localized: "\(Int((winRate * 100).rounded()))%")),
            metric(String(localized: "Average stars"), value: String(format: "%.1f", stars)),
            metric(String(localized: "Moves left"), value: String(format: "%.1f", moves))
        ])
        let content = stack([
            heading,
            label(String(localized: "\(statusText) · \(source)"), style: .footnote, color: statusColor),
            metrics
        ], spacing: 14)
        let details = button(showsBalanceDetails ? String(localized: "Hide balance details") : String(localized: "Balance details"), symbol: showsBalanceDetails ? "chevron.up" : "chevron.down", fill: UIColor(hex: "#F2DED9"), ink: Self.ink) { [weak self] in
            guard let self else { return }
            self.showsBalanceDetails.toggle()
            self.renderContent()
        }
        details.accessibilityIdentifier = "levelExplorer.balanceDetails"
        details.accessibilityValue = showsBalanceDetails ? String(localized: "Expanded") : String(localized: "Collapsed")
        content.addArrangedSubview(details)
        if showsBalanceDetails {
            content.addArrangedSubview(detail(String(localized: "Goal"), value: config.goal.title))
            content.addArrangedSubview(detail(String(localized: "Board"), value: String(localized: "\(config.rows) × \(config.cols) · \(config.moves) moves")))
            content.addArrangedSubview(detail(String(localized: "Difficulty"), value: config.difficulty.displayName))
            content.addArrangedSubview(detail(config.goal == .score ? String(localized: "Score capacity / target") : String(localized: "Star thresholds"), value: config.goal == .score ? "\(balance.estimatedScoreCapacity) / \(config.target)" : LevelScoring.previewSummary(for: config)))
            if wins == 0 {
                content.addArrangedSubview(label(String(localized: "Stars and moves left are estimates until this level has a recorded win."), style: .footnote, color: Self.muted))
            }
            content.addArrangedSubview(label(balance.warnings.isEmpty ? String(localized: "No balance warnings") : balance.warnings.joined(separator: "\n"), style: .footnote, color: balance.warnings.isEmpty ? UIColor(hex: "#176650") : UIColor(hex: "#9A4713")))
        }
        return panel(content)
    }

    private func jumpCard() -> UIView {
        let field = numberField(text: jumpDraft, placeholder: "1–\(Levels.count)", accessibility: String(localized: "Level number"))
        levelField = field
        field.accessibilityIdentifier = "levelExplorer.levelNumber"
        field.addTarget(self, action: #selector(levelEntryChanged(_:)), for: .editingChanged)
        let play = button(String(localized: "Play"), symbol: "play.fill", fill: Self.berry, ink: .white) { [weak self] in self?.submitLevel() }
        play.accessibilityIdentifier = "levelExplorer.jump"
        let input = stack([field, play], axis: .horizontal, spacing: 10)
        input.alignment = .fill
        play.setContentHuggingPriority(.required, for: .horizontal)
        let error = errorLabel()
        let replay = button(String(localized: "Replay seed"), symbol: "arrow.counterclockwise", fill: UIColor(hex: "#F2DED9"), ink: Self.ink) { [weak self] in self?.showSeedReplay() }
        replay.accessibilityIdentifier = "levelExplorer.seedReplay"
        replay.isEnabled = (1...Levels.count).contains(config.number)
        return panel(stack([
            label(String(localized: "Jump directly"), style: .headline, color: Self.ink, heavy: true),
            input, error, replay
        ], spacing: 12))
    }

    private func addWorldLevels(_ world: WorldThemeDefinition) {
        contentStack.addArrangedSubview(worldCard(world, navigates: false))
        contentStack.addArrangedSubview(sectionTitle(String(localized: "Choose a level")))
        contentStack.addArrangedSubview(levelGrid(Array(world.levels).filter { (1...Levels.count).contains($0) }))
        contentStack.addArrangedSubview(label(String(localized: "Tap a level to start. Jumping does not spend a life."), style: .footnote, color: UIColor(hex: "#D8CAE2")))
    }

    private func worldCard(_ world: WorldThemeDefinition, navigates: Bool = true) -> UIView {
        let current = world.levels.contains(config.number)
        let card = ExplorerWorldCard(world: world, current: current, navigates: navigates)
        if navigates {
            card.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                self.view.endEditing(true)
                self.searchBar.text = ""
                self.selectedWorld = world
                self.renderContent(resetScroll: true)
                UIAccessibility.post(notification: .screenChanged, argument: self.titleLabel)
            }, for: .touchUpInside)
        }
        return card
    }

    private func levelGrid(_ levels: [Int]) -> UIView {
        let grid = stack([], spacing: 10)
        for start in stride(from: 0, to: levels.count, by: gridColumns) {
            let row = stack([], axis: .horizontal, spacing: 10)
            row.distribution = .fillEqually
            for index in start..<min(start + gridColumns, levels.count) {
                let level = levels[index]
                let current = level == config.number
                let tile = button(String(level), fill: current ? Self.berry : UIColor(hex: "#354366"), ink: Self.cream) { [weak self] in
                    self?.finish(level: level)
                }
                tile.configuration?.subtitle = current ? String(localized: "Current") : nil
                tile.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                    var result = attributes
                    result.font = Self.font(.title3, heavy: true)
                    return result
                }
                tile.heightAnchor.constraint(greaterThanOrEqualToConstant: 70).isActive = true
                tile.accessibilityLabel = String(localized: "Level \(level)")
                tile.accessibilityValue = current ? String(localized: "Current level") : nil
                tile.accessibilityHint = String(localized: "Starts this level without spending a life.")
                tile.accessibilityIdentifier = "levelExplorer.level.\(level)"
                if current { tile.accessibilityTraits.insert(.selected) }
                row.addArrangedSubview(tile)
            }
            while row.arrangedSubviews.count < gridColumns { row.addArrangedSubview(UIView()) }
            grid.addArrangedSubview(row)
        }
        return grid
    }

    private func addSearchResults(_ query: String) {
        var numberQuery = query
        let levelPrefix = String(localized: "Level") + " "
        if query.lowercased().hasPrefix(levelPrefix.lowercased()) {
            numberQuery = String(query.dropFirst(levelPrefix.count)).trimmingCharacters(in: .whitespaces)
        }
        if Self.isDecimal(numberQuery) {
            if let level = Int(numberQuery), (1...Levels.count).contains(level) {
                contentStack.addArrangedSubview(sectionTitle(String(localized: "Level \(level)")))
                contentStack.addArrangedSubview(worldCard(WorldThemes.theme(for: level)))
                contentStack.addArrangedSubview(levelGrid([level]))
            } else {
                contentStack.addArrangedSubview(emptyResults(String(localized: "Choose a level from 1–\(Levels.count).")))
            }
            return
        }
        let worlds = WorldThemes.all.filter {
            $0.displayName.localizedStandardContains(query) || $0.id.localizedStandardContains(query)
        }
        if worlds.isEmpty {
            contentStack.addArrangedSubview(emptyResults(String(localized: "Try a world name or a level from 1–\(Levels.count).")))
        } else {
            contentStack.addArrangedSubview(sectionTitle(String(localized: "Matching worlds")))
            worlds.forEach { contentStack.addArrangedSubview(worldCard($0)) }
        }
    }

    private func emptyResults(_ message: String) -> UIView {
        panel(stack([
            label(String(localized: "No results"), style: .title3, color: Self.ink, heavy: true),
            label(message, style: .body, color: Self.muted)
        ], spacing: 8))
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        renderContent(resetScroll: true)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func focusLevelEntry() {
        showWorlds()
        view.layoutIfNeeded()
        levelField?.becomeFirstResponder()
    }

    func showWorlds() {
        view.endEditing(true)
        searchBar.text = ""
        selectedWorld = nil
        showsSeedReplay = false
        renderContent(resetScroll: true)
        UIAccessibility.post(notification: .screenChanged, argument: titleLabel)
    }

    func showSeedReplay() {
        view.endEditing(true)
        searchBar.text = ""
        selectedWorld = nil
        showsSeedReplay = true
        renderContent(resetScroll: true)
        UIAccessibility.post(notification: .screenChanged, argument: titleLabel)
    }

    private func addSeedForm() {
        let field = numberField(text: seedDraft, placeholder: String(openingSeed), accessibility: String(localized: "Opening board seed"))
        seedField = field
        field.accessibilityIdentifier = "levelExplorer.seed"
        field.addTarget(self, action: #selector(seedEntryChanged(_:)), for: .editingChanged)
        let replay = button(String(localized: "Replay level \(config.number)"), symbol: "arrow.counterclockwise", fill: Self.berry, ink: .white) { [weak self] in self?.submitSeed() }
        replay.isEnabled = (1...Levels.count).contains(config.number)
        replay.accessibilityIdentifier = "levelExplorer.replay"
        let current = button(String(localized: "Use current seed"), fill: UIColor(hex: "#F2DED9"), ink: Self.ink) { [weak self] in
            guard let self else { return }
            self.seedDraft = String(self.openingSeed)
            self.seedField?.text = self.seedDraft
            self.entryError?.isHidden = true
        }
        let value = label(String(openingSeed), style: .body, color: Self.ink)
        value.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .semibold))
        value.accessibilityLabel = String(localized: "Current seed: \(String(openingSeed))")
        contentStack.addArrangedSubview(panel(stack([
            label(String(localized: "Replay the opening board"), style: .title3, color: Self.ink, heavy: true),
            label(String(localized: "Paste the seed from this level’s level_start analytics event, or use the current opening seed."), style: .body, color: Self.muted),
            label(String(localized: "Current opening seed"), style: .caption1, color: Self.muted),
            value, current,
            label(String(localized: "Seed to replay"), style: .headline, color: Self.ink, heavy: true),
            field, errorLabel(), replay
        ], spacing: 14)))
        contentStack.addArrangedSubview(label(String(localized: "Replay restarts the current campaign level. It does not spend a life. Completing the level still saves normal progress."), style: .footnote, color: UIColor(hex: "#D8CAE2")))
    }

    private func submitLevel() {
        let text = jumpDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isDecimal(text), let level = Int(text), (1...Levels.count).contains(level) else {
            showEntryError(String(localized: "Enter a whole level number from 1–\(Levels.count)."))
            return
        }
        finish(level: level)
    }

    private func submitSeed() {
        let text = seedDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isDecimal(text), let seed = UInt64(text) else {
            showEntryError(String(localized: "Enter a seed from 0 to 18446744073709551615, using digits only."))
            return
        }
        finish(level: config.number, seed: seed)
    }

    private static func isDecimal(_ text: String) -> Bool {
        !text.isEmpty && text.utf8.allSatisfy { $0 >= 48 && $0 <= 57 }
    }

    @objc private func levelEntryChanged(_ sender: UITextField) {
        jumpDraft = sender.text ?? ""
        entryError?.isHidden = true
    }

    @objc private func seedEntryChanged(_ sender: UITextField) {
        seedDraft = sender.text ?? ""
        entryError?.isHidden = true
    }

    private func showEntryError(_ text: String) {
        entryError?.text = text
        entryError?.isHidden = false
        view.layoutIfNeeded()
        if let error = entryError {
            scrollView.scrollRectToVisible(error.convert(error.bounds, to: scrollView).insetBy(dx: 0, dy: -16), animated: !UIAccessibility.isReduceMotionEnabled)
        }
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        view.layoutIfNeeded()
        scrollView.scrollRectToVisible(textField.convert(textField.bounds, to: scrollView).insetBy(dx: 0, dy: -24), animated: !UIAccessibility.isReduceMotionEnabled)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === seedField { submitSeed() } else { submitLevel() }
        return true
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }

    private func finish(level: Int? = nil, seed: UInt64? = nil) {
        guard !dismissalStarted else { return }
        if let level {
            guard (1...Levels.count).contains(level) else { return }
            pendingSelection = (level, seed)
        }
        dismissalStarted = true
        view.endEditing(true)
        dismiss(animated: !UIAccessibility.isReduceMotionEnabled) { [self] in deliverDismissal() }
    }

    private func deliverDismissal() {
        guard !dismissalDelivered else { return }
        dismissalDelivered = true
        onDismiss?()
        if let selected = pendingSelection { onSelect?(selected.level, selected.seed) }
        onSelect = nil
        onDismiss = nil
    }

    /// A separate DEBUG key; browsing never changes the campaign save or economy.
    static func recordVisit(_ level: Int) {
        guard (1...Levels.count).contains(level) else { return }
        let recent = [level] + recentLevels.filter { $0 != level }
        UserDefaults.standard.set(Array(recent.prefix(6)), forKey: recentKey)
    }

    private static var recentLevels: [Int] {
        var seen = Set<Int>()
        return Array(((UserDefaults.standard.array(forKey: recentKey) as? [Int]) ?? [])
            .filter { (1...Levels.count).contains($0) && seen.insert($0).inserted }.prefix(6))
    }

    // MARK: - Native, scalable components

    fileprivate static func font(_ style: UIFont.TextStyle, heavy: Bool = false) -> UIFont {
        let size: CGFloat
        switch style {
        case .title2: size = 25
        case .title3: size = 20
        case .caption1: size = 12
        case .footnote: size = 13
        case .subheadline: size = 15
        default: size = 17
        }
        let base = UIFont(name: heavy ? "AvenirNext-Heavy" : "AvenirNext-DemiBold", size: size)
            ?? UIFont.systemFont(ofSize: size, weight: heavy ? .heavy : .semibold)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }

    private func label(_ text: String, style: UIFont.TextStyle, color: UIColor, heavy: Bool = false) -> UILabel {
        let result = UILabel()
        result.text = text
        result.font = Self.font(style, heavy: heavy)
        result.textColor = color
        result.numberOfLines = 0
        result.adjustsFontForContentSizeCategory = true
        result.setContentCompressionResistancePriority(.required, for: .vertical)
        return result
    }

    private func sectionTitle(_ text: String) -> UILabel {
        let result = label(text, style: .title3, color: Self.cream, heavy: true)
        result.accessibilityTraits = .header
        return result
    }

    private func metric(_ title: String, value: String) -> UIView {
        let result = stack([
            label(value, style: .title2, color: Self.ink, heavy: true),
            label(title, style: .caption1, color: Self.muted)
        ], spacing: 3)
        result.isAccessibilityElement = true
        result.accessibilityLabel = title
        result.accessibilityValue = value
        return result
    }

    private func detail(_ title: String, value: String) -> UIView {
        stack([label(title, style: .caption1, color: Self.muted), label(value, style: .subheadline, color: Self.ink)], spacing: 3)
    }

    private func stack(_ views: [UIView], axis: NSLayoutConstraint.Axis = .vertical, spacing: CGFloat = 10) -> UIStackView {
        let result = UIStackView(arrangedSubviews: views)
        result.axis = axis
        result.spacing = spacing
        return result
    }

    private func adaptiveRow(_ views: [UIView]) -> UIStackView {
        let result = stack(views, axis: traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal, spacing: 10)
        result.distribution = .fillEqually
        return result
    }

    private func panel(_ content: UIStackView) -> UIView {
        let result = ExplorerGradientView(colors: [.white, Self.cream, UIColor(hex: "#F0DBD3")])
        result.layer.cornerRadius = 22
        result.layer.borderWidth = 1
        result.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
        result.layer.shadowColor = UIColor.black.cgColor
        result.layer.shadowOpacity = 0.15
        result.layer.shadowRadius = 10
        result.layer.shadowOffset = CGSize(width: 0, height: 5)
        content.translatesAutoresizingMaskIntoConstraints = false
        result.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: result.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: result.bottomAnchor, constant: -16),
            content.leadingAnchor.constraint(equalTo: result.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: result.trailingAnchor, constant: -16)
        ])
        return result
    }

    private func button(_ title: String, symbol: String? = nil, fill: UIColor, ink: UIColor, action: @escaping () -> Void) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = symbol.flatMap { UIImage(systemName: $0) }
        configuration.imagePadding = 8
        configuration.baseBackgroundColor = fill
        configuration.baseForegroundColor = ink
        configuration.cornerStyle = .large
        configuration.contentInsets = .init(top: 12, leading: 12, bottom: 12, trailing: 12)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var result = attributes
            result.font = Self.font(.subheadline, heavy: true)
            return result
        }
        let result = UIButton(configuration: configuration)
        result.titleLabel?.numberOfLines = 0
        result.titleLabel?.adjustsFontForContentSizeCategory = true
        result.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        result.addAction(UIAction { _ in action() }, for: .touchUpInside)
        result.configurationUpdateHandler = { control in
            control.alpha = !control.isEnabled ? 0.42 : (control.isHighlighted ? 0.72 : 1)
        }
        return result
    }

    private func numberField(text: String, placeholder: String, accessibility: String) -> UITextField {
        let field = UITextField()
        field.text = text
        field.placeholder = placeholder
        field.keyboardType = .numberPad
        field.returnKeyType = .go
        field.borderStyle = .none
        field.backgroundColor = .white
        field.layer.cornerRadius = 13
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor(hex: "#DAC3D1").cgColor
        field.font = Self.font(.body)
        field.adjustsFontForContentSizeCategory = true
        field.textColor = Self.ink
        field.tintColor = Self.berry
        field.accessibilityLabel = accessibility
        field.delegate = self
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        field.leftViewMode = .always
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        field.rightViewMode = .always
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: String(localized: "Done"), style: .done, target: self, action: #selector(dismissKeyboard))
        ]
        field.inputAccessoryView = toolbar
        return field
    }

    private func errorLabel() -> UILabel {
        let result = label("", style: .footnote, color: UIColor(hex: "#A52C48"))
        result.isHidden = true
        result.accessibilityIdentifier = "levelExplorer.validationError"
        entryError = result
        return result
    }
}

private final class ExplorerGradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    init(colors: [UIColor]) {
        super.init(frame: .zero)
        let gradient = layer as! CAGradientLayer
        gradient.colors = colors.map(\.cgColor)
        gradient.startPoint = CGPoint(x: 0.15, y: 0)
        gradient.endPoint = CGPoint(x: 0.85, y: 1)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// A decorative image fills its card; its source pixel dimensions cannot size
/// an arranged subview in the vertical world list.
private final class ExplorerCardImageView: UIImageView {
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
}

private final class ExplorerWorldCard: UIControl {
    init(world: WorldThemeDefinition, current: Bool, navigates: Bool) {
        super.init(frame: .zero)
        layer.cornerRadius = 20
        layer.borderWidth = current ? 2 : 1
        layer.borderColor = (current ? UIColor(hex: "#FFDC9A") : UIColor.white.withAlphaComponent(0.28)).cgColor
        clipsToBounds = true
        backgroundColor = UIColor(hex: world.secondary)
        let art = ExplorerCardImageView(image: UIImage(named: world.backgroundAsset))
        art.contentMode = .scaleAspectFill
        art.clipsToBounds = true
        art.isUserInteractionEnabled = false
        let shade = ExplorerGradientView(colors: [UIColor(hex: "#141B35").withAlphaComponent(0.12), UIColor(hex: "#141B35").withAlphaComponent(0.92)])
        shade.isUserInteractionEnabled = false
        [art, shade].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
            NSLayoutConstraint.activate([
                $0.topAnchor.constraint(equalTo: topAnchor), $0.bottomAnchor.constraint(equalTo: bottomAnchor),
                $0.leadingAnchor.constraint(equalTo: leadingAnchor), $0.trailingAnchor.constraint(equalTo: trailingAnchor)
            ])
        }
        let title = UILabel()
        title.text = world.displayName
        title.font = LevelExplorerViewController.font(.title3, heavy: true)
        title.textColor = .white
        title.numberOfLines = 0
        title.adjustsFontForContentSizeCategory = true
        title.setContentCompressionResistancePriority(.required, for: .vertical)
        let subtitle = UILabel()
        let range = String(localized: "Levels \(world.levels.lowerBound)–\(world.levels.upperBound)")
        subtitle.text = current ? String(localized: "\(range) · Current world") : range
        subtitle.font = LevelExplorerViewController.font(.footnote)
        subtitle.textColor = UIColor(hex: "#FFF0CB")
        subtitle.numberOfLines = 0
        subtitle.adjustsFontForContentSizeCategory = true
        subtitle.setContentCompressionResistancePriority(.required, for: .vertical)
        let titles = UIStackView(arrangedSubviews: [title, subtitle])
        titles.axis = .vertical
        titles.spacing = 4
        titles.isUserInteractionEnabled = false
        titles.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titles)
        let preferredHeight = heightAnchor.constraint(equalToConstant: navigates ? 110 : 170)
        preferredHeight.priority = .defaultHigh
        NSLayoutConstraint.activate([
            preferredHeight,
            heightAnchor.constraint(greaterThanOrEqualToConstant: navigates ? 110 : 170),
            titles.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 24),
            titles.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titles.trailingAnchor.constraint(equalTo: trailingAnchor, constant: navigates ? -46 : -16),
            titles.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
        if navigates {
            let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
            chevron.tintColor = .white
            chevron.contentMode = .scaleAspectFit
            chevron.translatesAutoresizingMaskIntoConstraints = false
            addSubview(chevron)
            NSLayoutConstraint.activate([
                chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                chevron.centerYAnchor.constraint(equalTo: titles.centerYAnchor),
                chevron.widthAnchor.constraint(equalToConstant: 14),
                chevron.heightAnchor.constraint(equalToConstant: 20)
            ])
        }
        isAccessibilityElement = true
        accessibilityLabel = world.displayName
        accessibilityValue = subtitle.text
        accessibilityTraits = navigates ? .button : .staticText
        accessibilityHint = navigates ? String(localized: "Choose an individual level in this world.") : nil
        accessibilityIdentifier = "levelExplorer.world.\(world.id)"
        isUserInteractionEnabled = navigates
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.75 : 1 }
    }
}
#endif
