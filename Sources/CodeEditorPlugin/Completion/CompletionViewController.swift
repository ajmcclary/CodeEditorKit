import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

/// Modern completion view controller with table view interface
@MainActor
public final class CompletionViewController: NSViewController, CompletionViewControllerProtocol {
    public typealias Item = any CompletionItem
    
    // MARK: - Public Properties
    
    public var items: [Item] = [] {
        didSet {
            updateCompletionItems()
        }
    }
    
    public weak var delegate: CompletionViewControllerDelegate?
    
    // Modern completion items
    public var completionItems: [CompletionItemModel] = [] {
        didSet {
            tableView.reloadData()
            updateSelection()
        }
    }
    
    // MARK: - Private Properties
    
    private lazy var scrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = PlatformColors.controlBackground
        return scrollView
    }()
    
    private lazy var tableView: NSTableView = {
        let tableView = NSTableView()
        tableView.style = .plain
        tableView.headerView = nil
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.backgroundColor = PlatformColors.controlBackground
        tableView.selectionHighlightStyle = .regular
        tableView.allowsEmptySelection = false
        tableView.allowsMultipleSelection = false
        tableView.usesAlternatingRowBackgroundColors = false
        
        // Add column
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("completion"))
        column.isEditable = false
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        
        tableView.delegate = self
        tableView.dataSource = self
        
        return tableView
    }()
    
    private var selectedIndex: Int = 0
    
    // MARK: - Initialization
    
    public init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - View Lifecycle
    
    override public func loadView() {
        view = NSView()
        setupUI()
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        scrollView.documentView = tableView
        view.addSubview(scrollView)
        
        // Setup constraints
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func configureAppearance() {
        // Configure visual appearance
        view.wantsLayer = true
        view.layer?.backgroundColor = PlatformColors.controlBackground.cgColor
        view.layer?.cornerRadius = 6
        view.layer?.borderWidth = 1
        view.layer?.borderColor = PlatformColors.separator.cgColor
        
        // Add shadow
        view.shadow = NSShadow()
        view.layer?.shadowColor = PlatformColors.black.cgColor
        view.layer?.shadowOpacity = 0.2
        view.layer?.shadowOffset = NSSize(width: 0, height: -2)
        view.layer?.shadowRadius = 4
    }
    
    // MARK: - Public Methods
    
    /// Update completion items from new completion models
    public func updateCompletionItems() {
        // Convert legacy CompletionItem to CompletionItemModel if needed
        // For now, we'll focus on the new completion model system
        tableView.reloadData()
        updateSelection()
    }
    
    /// Set the selected completion item
    public func setSelectedIndex(_ index: Int) {
        guard index >= 0 && index < completionItems.count else { return }
        
        selectedIndex = index
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
    }
    
    /// Get the currently selected completion item
    public func selectedCompletionItem() -> CompletionItemModel? {
        guard selectedIndex >= 0 && selectedIndex < completionItems.count else { return nil }
        return completionItems[selectedIndex]
    }
    
    /// Insert the selected completion item
    public func insertSelectedItem() {
        guard let item = selectedCompletionItem() else { return }
        delegate?.completionViewController(self, complete: CompletionItemAdapter(item), movement: .return)
    }
    
    // MARK: - Navigation
    
    /// Move selection up
    public func selectPrevious() {
        let newIndex = max(0, selectedIndex - 1)
        setSelectedIndex(newIndex)
    }
    
    /// Move selection down
    public func selectNext() {
        let newIndex = min(completionItems.count - 1, selectedIndex + 1)
        setSelectedIndex(newIndex)
    }
    
    // MARK: - Private Methods
    
    private func updateSelection() {
        guard !completionItems.isEmpty else { return }
        
        // Select first item by default, or maintain current selection
        let newIndex = min(selectedIndex, completionItems.count - 1)
        setSelectedIndex(newIndex)
    }
    
    deinit {
        // Cleanup if needed
    }
}

// MARK: - NSTableViewDataSource

extension CompletionViewController: NSTableViewDataSource {
    public func numberOfRows(in _: NSTableView) -> Int {
        completionItems.count
    }
    
    public func tableView(_: NSTableView, objectValueFor _: NSTableColumn?, row: Int) -> Any? {
        guard row >= 0 && row < completionItems.count else { return nil }
        return completionItems[row]
    }
}

// MARK: - NSTableViewDelegate

extension CompletionViewController: NSTableViewDelegate {
    public func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0 && row < completionItems.count else { return nil }
        
        let item = completionItems[row]
        let identifier = NSUserInterfaceItemIdentifier("CompletionCell")
        
        var cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? CompletionCellView
        if cellView == nil {
            cellView = CompletionCellView()
            cellView?.identifier = identifier
        }
        
        cellView?.configure(with: item)
        return cellView
    }
    
    public func tableView(_: NSTableView, heightOfRow _: Int) -> CGFloat {
        24 // Standard completion item height
    }
    
    public func tableViewSelectionDidChange(_: Notification) {
        selectedIndex = tableView.selectedRow
    }
    
    public func tableView(_: NSTableView, shouldSelectRow row: Int) -> Bool {
        row >= 0 && row < completionItems.count
    }
}

private final class CompletionCellView: NSTableCellView {
    deinit {}
    
    private lazy var iconLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = PlatformFonts.systemFont(ofSize: 12)
        label.textColor = PlatformColors.secondaryLabel
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = PlatformFonts.systemFont(ofSize: 13)
        label.textColor = PlatformColors.label
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var detailLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = PlatformFonts.systemFont(ofSize: 11)
        label.textColor = PlatformColors.secondaryLabel
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        addSubview(iconLabel)
        addSubview(titleLabel)
        addSubview(detailLabel)
        
        NSLayoutConstraint.activate([
            // Icon
            iconLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 16),
            
            // Title
            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -2),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: detailLabel.leadingAnchor, constant: -8),
            
            // Detail
            detailLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            detailLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 2),
            detailLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 120)
        ])
        
        // Set content hugging priorities
        titleLabel.setContentHuggingPriority(NSLayoutConstraint.Priority(249), for: .horizontal)
        detailLabel.setContentHuggingPriority(NSLayoutConstraint.Priority(251), for: .horizontal)
    }
    
    func configure(with item: CompletionItemModel) {
        iconLabel.stringValue = item.kind.icon
        titleLabel.stringValue = item.label
        detailLabel.stringValue = item.detail ?? ""
        
        // Highlight deprecated items
        if item.deprecated {
            titleLabel.textColor = PlatformColors.disabledControlText
            titleLabel.font = PlatformFonts.systemFont(ofSize: 13, weight: .light)
        } else {
            titleLabel.textColor = PlatformColors.label
            titleLabel.font = PlatformFonts.systemFont(ofSize: 13)
        }
    }
}

#elseif canImport(UIKit)
import UIKit

/// iOS completion view controller implementation
@MainActor
public final class BasicCompletionViewController: UIViewController, CompletionViewControllerProtocol {
    public typealias Item = any CompletionItem
    
    // MARK: - Public Properties
    
    public var items: [Item] = [] {
        didSet {
            updateCompletionItems()
        }
    }
    
    public weak var delegate: CompletionViewControllerDelegate?
    
    // Modern completion items
    public var completionItems: [CompletionItemModel] = [] {
        didSet {
            tableView.reloadData()
            updateSelection()
        }
    }
    
    // MARK: - Private Properties
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = PlatformColors.systemBackground
        tableView.separatorStyle = .singleLine
        tableView.allowsSelection = true
        tableView.allowsMultipleSelection = false
        tableView.rowHeight = 44
        tableView.register(CompletionTableViewCell.self, forCellReuseIdentifier: "CompletionCell")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private var selectedIndex: Int = 0
    
    // MARK: - Initialization
    
    public init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - View Lifecycle
    
    override public func loadView() {
        view = UIView()
        setupUI()
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func configureAppearance() {
        view.backgroundColor = PlatformColors.systemBackground
        view.layer.cornerRadius = 8
        view.layer.borderWidth = 1
        view.layer.borderColor = PlatformColors.separator.cgColor
        
        // Add shadow
        view.layer.shadowColor = PlatformColors.black.cgColor
        view.layer.shadowOpacity = 0.2
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
    }
    
    // MARK: - Public Methods
    
    /// Update completion items from new completion models
    public func updateCompletionItems() {
        tableView.reloadData()
        updateSelection()
    }
    
    /// Set the selected completion item
    public func setSelectedIndex(_ index: Int) {
        guard index >= 0 && index < completionItems.count else { return }
        
        selectedIndex = index
        let indexPath = IndexPath(row: index, section: 0)
        tableView.selectRow(at: indexPath, animated: false, scrollPosition: .middle)
    }
    
    /// Get the currently selected completion item
    public func selectedCompletionItem() -> CompletionItemModel? {
        guard selectedIndex >= 0 && selectedIndex < completionItems.count else { return nil }
        return completionItems[selectedIndex]
    }
    
    /// Insert the selected completion item
    public func insertSelectedItem() {
        guard let item = selectedCompletionItem() else { return }
        delegate?.completionViewController(self, complete: CompletionItemAdapter(item), movement: .return)
    }
    
    // MARK: - Navigation
    
    /// Move selection up
    public func selectPrevious() {
        let newIndex = max(0, selectedIndex - 1)
        setSelectedIndex(newIndex)
    }
    
    /// Move selection down
    public func selectNext() {
        let newIndex = min(completionItems.count - 1, selectedIndex + 1)
        setSelectedIndex(newIndex)
    }
    
    // MARK: - Private Methods
    
    private func updateSelection() {
        guard !completionItems.isEmpty else { return }
        
        let newIndex = min(selectedIndex, completionItems.count - 1)
        setSelectedIndex(newIndex)
    }
    
    deinit {
        // Cleanup if needed
    }
}

// MARK: - UITableViewDataSource

extension BasicCompletionViewController: UITableViewDataSource {
    public func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        completionItems.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "CompletionCell", for: indexPath) as? CompletionTableViewCell else {
            fatalError("Failed to dequeue CompletionTableViewCell")
        }
        let item = completionItems[indexPath.row]
        cell.configure(with: item)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension BasicCompletionViewController: UITableViewDelegate {
    public func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedIndex = indexPath.row
        insertSelectedItem()
    }
}

private final class CompletionTableViewCell: UITableViewCell {
    deinit {}
    
    private lazy var iconLabel: UILabel = {
        let label = UILabel()
        label.font = PlatformFonts.systemFont(ofSize: 16)
        label.textColor = PlatformColors.secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = PlatformFonts.systemFont(ofSize: 16)
        label.textColor = PlatformColors.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var detailLabel: UILabel = {
        let label = UILabel()
        label.font = PlatformFonts.systemFont(ofSize: 14)
        label.textColor = PlatformColors.secondaryLabel
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        contentView.addSubview(iconLabel)
        contentView.addSubview(titleLabel)
        contentView.addSubview(detailLabel)
        
        NSLayoutConstraint.activate([
            // Icon
            iconLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 20),
            
            // Title
            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: detailLabel.leadingAnchor, constant: -8),
            
            // Detail
            detailLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            detailLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            detailLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 120)
        ])
        
        titleLabel.setContentHuggingPriority(UILayoutPriority(249), for: .horizontal)
        detailLabel.setContentHuggingPriority(UILayoutPriority(251), for: .horizontal)
    }
    
    func configure(with item: CompletionItemModel) {
        iconLabel.text = item.kind.icon
        titleLabel.text = item.label
        detailLabel.text = item.detail
        
        // Handle deprecated items
        if item.deprecated {
            titleLabel.textColor = PlatformColors.tertiaryLabel
            titleLabel.font = PlatformFonts.systemFont(ofSize: 16, weight: .light)
        } else {
            titleLabel.textColor = PlatformColors.label
            titleLabel.font = PlatformFonts.systemFont(ofSize: 16)
        }
    }
}

#endif
