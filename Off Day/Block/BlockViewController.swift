//
//  BlockViewController.swift
//  Off Day
//
//  Created by zici on 2024/1/2.
//

import UIKit
import SnapKit
import Toast
import ZCCalendar

class BlockViewController: BlockBaseViewController, DisplayHandlerDelegate {
    static let monthTagElementKind: String = "monthTagElementKind"
    
    // Data
    
    internal var dataSource: UICollectionViewDiffableDataSource<Section, Item>! = nil
    
    private var events: [Event] = [] {
        didSet {
            eventsDict = [:]
            for event in events {
                let dateType = displayHandler.getDateType()
                let start = event.startDate.leadingIndex(for: dateType)
                let end = event.endDate.trailingIndex(for: dateType)
                for i in start...end {
                    var result: [Event] = eventsDict[i] ?? []
                    result.append(event)
                    eventsDict[i] = result
                }
            }
            applyData()
        }
    }
    
    private var eventsDict: [Int : [Event]] = [:]
    
    // Handler
    
    private var displayHandler: DisplayHandler!
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        displayHandler = DayDisplayHandler(delegate: self)
        
        title = String(localized: "controller.calendar.title")
        tabBarItem = UITabBarItem(title: String(localized: "controller.calendar.title"), image: UIImage(systemName: "calendar"), tag: 0)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("BlockViewController is deinited")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .oneBackground
        updateNavigationBarStyle()
        
        configureHierarchy()
        configureDataSource()
        
        addGestures()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: .DatabaseUpdated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: .TodayUpdated, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reloadData()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func tap(in indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) else {
            return
        }
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        switch item {
        case .info, .tag, .invisible:
            break
        case .block(let blockItem):
            impactFeedbackGeneratorCoourred()
            tap(in: cell, for: blockItem)
        }
    }
    
    func filter(events: [Event], from startIndex: Int, to endIndex: Int) -> [Event] {
        return events.filter({ event in
            let dateType = self.displayHandler.getDateType()
            if event.endDate.trailingIndex(for: dateType) < startIndex {
                return false
            } else if event.startDate.leadingIndex(for: dateType) > endIndex {
                return false
            } else {
                return true
            }
        })
    }
    
    override func hover(in indexPath: IndexPath) {
        super.hover(in: indexPath)
        guard let blockItem = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        switch blockItem {
        case .info, .tag, .invisible:
            break
        case .block(let blockItem):
            if blockItem.isDay {
                view.makeToast(blockItem.day.formatString(), position: .top)
            } else {
                view.makeToast(blockItem.yearMonth.title, position: .top)
            }
        }
    }
    
    private func tap(in targetView: UIView, for blockItem: BlockItem) {
//        if blockItem.events?.count ?? 0 > 0 {
//            showBlockDetailPopoverView(at: targetView, for: blockItem)
//        } else {
//            let addViewController = EventEditorViewController.emptyEvent(for: blockItem)
//            showPopoverView(at: targetView, contentViewController: addViewController)
//        }
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = .vertical
        let layout = UICollectionViewCompositionalLayout(sectionProvider: { [weak self] index, environment in
            guard let self = self else {
                return nil
            }
            return self.sectionProvider(index: index, environment: environment)
        }, configuration: config)
        return layout
    }
    
    private func configureDataSource() {
        let infoCellRegistration = getInfoSectionCellRegistration()
        let blockCellRegistration = getBlockCellRegistration()
        let weekCellRegistration = getWeekCellRegistration()
        let invisibleCellRegistration = UICollectionView.CellRegistration<UICollectionViewCell, Item> { (cell, indexPath, identifier) in
        }
        let monthTagRegistration = getMonthTagRegistration()
        
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { [weak self]
            (collectionView: UICollectionView, indexPath: IndexPath, identifier: Item) -> UICollectionViewCell? in
            // Return the cell.
            guard let self = self else { return nil }
            guard let section = self.dataSource.sectionIdentifier(for: indexPath.section) else { fatalError("Unknown section") }
            switch section {
            case .info:
                return collectionView.dequeueConfiguredReusableCell(using: infoCellRegistration, for: indexPath, item: identifier)
            case .topTag:
                return collectionView.dequeueConfiguredReusableCell(using: weekCellRegistration, for: indexPath, item: identifier)
            case .row:
                switch identifier {
                case .info, .tag:
                    fatalError("Wrong Identifier")
                case .block:
                    return collectionView.dequeueConfiguredReusableCell(using: blockCellRegistration, for: indexPath, item: identifier)
                case .invisible:
                    return collectionView.dequeueConfiguredReusableCell(using: invisibleCellRegistration, for: indexPath, item: identifier)
                }
            }
        }
        dataSource.supplementaryViewProvider = { [weak self] (view, kind, index) in
            guard let self = self else { return nil }
            if kind == Self.monthTagElementKind {
                return self.collectionView.dequeueConfiguredReusableSupplementary(using: monthTagRegistration, for: index)
            } else {
                return nil
            }
        }
    }
    
    private func configureHierarchy() {
        collectionView = UIDraggableCollectionView(frame: CGRect.zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .oneBackground
        collectionView.delaysContentTouches = false
        collectionView.canCancelContentTouches = true
        collectionView.delegate = self
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalTo(view)
        }
        collectionView.scrollIndicatorInsets = UIEdgeInsets(top: CGFloat.leastNormalMagnitude, left: 0.0, bottom: 0.0, right: 0.0)
    }

    @objc
    internal func reloadData() {
        // TODO: Apply Active Handler for reduce request
        EventManager.shared.fetch { [weak self] events in
            guard let self = self else { return }
            self.events = filter(events: events.sortedByStart(), from: self.displayHandler.getLeading(), to: self.displayHandler.getTrailing())
        }
    }
    
    private func applyData() {
        if let snapshot = displayHandler.getSnapshot(eventsDict: eventsDict) {
            dataSource.apply(snapshot, animatingDifferences: true)
            self.updateVisibleItems()
        }
    }
    
    internal func getCatalogueMenu() -> UIMenu? {
        let children = displayHandler.getCatalogueMenuElements()
        return UIMenu(children: children)
    }
}
