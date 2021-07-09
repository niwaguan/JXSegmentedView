//
//  JXSegmentedListContainerView.swift
//  JXSegmentedView
//
//  Created by jiaxin on 2018/12/26.
//  Copyright © 2018 jiaxin. All rights reserved.
//

import UIKit

/// 列表容器视图的类型
///- ScrollView: UIScrollView。优势：没有其他副作用。劣势：视图内存占用相对大一点。因为所有的列表视图都在UIScrollView的视图层级里面。
/// - CollectionView: 使用UICollectionView。优势：因为列表被添加到cell上，视图的内存占用更少，适合内存要求特别高的场景。劣势：因为cell重用机制的问题，导致列表下拉刷新视图(比如MJRefresh)，会因为被removeFromSuperview而被隐藏。所以，列表有下拉刷新需求的，请使用scrollView type。
public enum JXSegmentedListContainerType {
    case scrollView
    case collectionView
}

@objc
public protocol JXSegmentedListContainerViewListDelegate {
    /// 如果列表是VC，就返回VC.view
    /// 如果列表是View，就返回View自己
    ///
    /// - Returns: 返回列表视图
    func listView() -> UIView
    @objc optional func listWillAppear()
    @objc optional func listDidAppear()
    @objc optional func listWillDisappear()
    @objc optional func listDidDisappear()
}

@objc
public protocol JXSegmentedListContainerViewDataSource {
    /// 返回list的数量
    func numberOfLists(in listContainerView: JXSegmentedListContainerView) -> Int

    /// 根据index初始化一个对应列表实例，需要是遵从`JXSegmentedListContainerViewListDelegate`协议的对象。
    /// 如果列表是用自定义UIView封装的，就让自定义UIView遵从`JXSegmentedListContainerViewListDelegate`协议，该方法返回自定义UIView即可。
    /// 如果列表是用自定义UIViewController封装的，就让自定义UIViewController遵从`JXSegmentedListContainerViewListDelegate`协议，该方法返回自定义UIViewController即可。
    /// 注意：一定要是新生成的实例！！！
    ///
    /// - Parameters:
    ///   - listContainerView: JXSegmentedListContainerView
    ///   - index: 目标index
    /// - Returns: 遵从JXSegmentedListContainerViewListDelegate协议的实例
    func listContainerView(_ listContainerView: JXSegmentedListContainerView, initListAt index: Int) -> JXSegmentedListContainerViewListDelegate


    /// 控制能否初始化对应index的列表。有些业务需求，需要在某些情况才允许初始化某些列表，通过通过该代理实现控制。
    @objc optional func listContainerView(_ listContainerView: JXSegmentedListContainerView, canInitListAt index: Int) -> Bool

    /// 返回自定义UIScrollView或UICollectionView的Class
    /// 某些特殊情况需要自己处理UIScrollView内部逻辑。比如项目用了FDFullscreenPopGesture，需要处理手势相关代理。
    ///
    /// - Parameter listContainerView: JXSegmentedListContainerView
    /// - Returns: 自定义UIScrollView实例
    @objc optional func scrollViewClass(in listContainerView: JXSegmentedListContainerView) -> AnyClass
}

open class JXSegmentedListContainerView: UIView, JXSegmentedViewListContainer, JXSegmentedViewRTLCompatible {
    open private(set) var type: JXSegmentedListContainerType
    open private(set) weak var dataSource: JXSegmentedListContainerViewDataSource?
    open private(set) var scrollView: UIScrollView!
    /// 已经加载过的列表字典。key是index，value是对应的列表
    open private(set) var validListDict = [Int:JXSegmentedListContainerViewListDelegate]()
    /// 滚动切换的时候，滚动距离超过一页的多少百分比，就触发列表的初始化。默认0.01（即列表显示了一点就触发加载）。范围0~1，开区间不包括0和1
    open var initListPercent: CGFloat = 0.01 {
        didSet {
            if initListPercent <= 0 || initListPercent >= 1 {
                assertionFailure("initListPercent值范围为开区间(0,1)，即不包括0和1")
            }
        }
    }
    open var listCellBackgroundColor: UIColor = .white
    /// 需要和segmentedView.defaultSelectedIndex保持一致，用于触发默认index列表的加载
    open var defaultSelectedIndex: Int = 0 {
        didSet {
            currentIndex = defaultSelectedIndex
        }
    }
    private var currentIndex: Int = 0
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        if let collectionViewClass = dataSource?.scrollViewClass?(in: self) as? UICollectionView.Type {
            return collectionViewClass.init(frame: CGRect.zero, collectionViewLayout: layout)
        }else {
            return UICollectionView.init(frame: CGRect.zero, collectionViewLayout: layout)
        }
    }()
    private lazy var containerVC = JXSegmentedListContainerViewController()
    private var willAppearIndexes: [Int] = []
    {
        didSet {
            debugPrint("✅willAppearIndex: \(willAppearIndexes)")
        }
    }
    private var willDisappearIndex: Int = -1
    {
        didSet {
            debugPrint("❌willDisappearIndex: \(willDisappearIndex)")
        }
    }

    public init(dataSource: JXSegmentedListContainerViewDataSource, type: JXSegmentedListContainerType = .scrollView) {
        self.dataSource = dataSource
        self.type = type
        super.init(frame: CGRect.zero)

        commonInit()
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open func commonInit() {
        containerVC.view.backgroundColor = .clear
        addSubview(containerVC.view)
        containerVC.viewWillAppearClosure = {[weak self] in
            self?.listWillAppear(at: self?.currentIndex ?? 0)
        }
        containerVC.viewDidAppearClosure = {[weak self] in
            self?.listDidAppear(at: self?.currentIndex ?? 0)
        }
        containerVC.viewWillDisappearClosure = {[weak self] in
            self?.listWillDisappear(at: self?.currentIndex ?? 0)
        }
        containerVC.viewDidDisappearClosure = {[weak self] in
            self?.listDidDisappear(at: self?.currentIndex ?? 0)
        }
        if type == .scrollView {
            if let scrollViewClass = dataSource?.scrollViewClass?(in: self) as? UIScrollView.Type {
                scrollView = scrollViewClass.init()
            }else {
                scrollView = UIScrollView.init()
            }
            scrollView.delegate = self
            scrollView.isPagingEnabled = true
            scrollView.showsVerticalScrollIndicator = false
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.scrollsToTop = false
            scrollView.bounces = false
            if #available(iOS 11.0, *) {
                scrollView.contentInsetAdjustmentBehavior = .never
            }
            if segmentedViewShouldRTLLayout() {
                segmentedView(horizontalFlipForView: scrollView)
            }
            containerVC.view.addSubview(scrollView)
        }else if type == .collectionView {
            collectionView.isPagingEnabled = true
            collectionView.showsHorizontalScrollIndicator = false
            collectionView.showsVerticalScrollIndicator = false
            collectionView.scrollsToTop = false
            collectionView.bounces = false
            collectionView.dataSource = self
            collectionView.delegate = self
            collectionView.register(JXSegmentedRTLCollectionCell.self, forCellWithReuseIdentifier: "cell")
            if #available(iOS 10.0, *) {
                collectionView.isPrefetchingEnabled = false
            }
            if #available(iOS 11.0, *) {
                self.collectionView.contentInsetAdjustmentBehavior = .never
            }
            if segmentedViewShouldRTLLayout() {
                collectionView.semanticContentAttribute = .forceLeftToRight
                segmentedView(horizontalFlipForView: collectionView)
            }
            containerVC.view.addSubview(collectionView)
            //让外部统一访问scrollView
            scrollView = collectionView
        }
    }

    open override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        var next: UIResponder? = newSuperview
        while next != nil {
            if let vc = next as? UIViewController{
                vc.addChild(containerVC)
                containerVC.didMove(toParent: vc)
                break
            }
            next = next?.next
        }
    }

    open override func layoutSubviews() {
        super.layoutSubviews()

        containerVC.view.frame = bounds
        guard let count = dataSource?.numberOfLists(in: self) else {
            return
        }
        if type == .scrollView {
            if scrollView.frame == CGRect.zero || scrollView.bounds.size != bounds.size {
                scrollView.frame = bounds
                scrollView.contentSize = CGSize(width: scrollView.bounds.size.width*CGFloat(count), height: scrollView.bounds.size.height)
                for (index, list) in validListDict {
                    list.listView().frame = CGRect(x: CGFloat(index)*scrollView.bounds.size.width, y: 0, width: scrollView.bounds.size.width, height: scrollView.bounds.size.height)
                }
            }else {
                scrollView.frame = bounds
                scrollView.contentSize = CGSize(width: scrollView.bounds.size.width*CGFloat(count), height: scrollView.bounds.size.height)
            }
            scrollView.contentOffset = CGPoint(x: CGFloat(currentIndex)*scrollView.bounds.size.width, y: 0)
        }else {
            if collectionView.frame == CGRect.zero || collectionView.bounds.size != bounds.size {
                collectionView.frame = bounds
                collectionView.collectionViewLayout.invalidateLayout()
            }else {
                collectionView.frame = bounds
            }
            collectionView.setContentOffset(CGPoint(x: CGFloat(currentIndex)*collectionView.bounds.size.width, y: 0), animated: false)
        }
    }

    //MARK: - JXSegmentedViewListContainer

    public func contentScrollView() -> UIScrollView {
           return scrollView
       }

    public func scrolling(from leftIndex: Int, to rightIndex: Int, percent: CGFloat, selectedIndex: Int) {
    }

    open func didClickSelectedItem(at index: Int) {
        guard checkIndexValid(index) else {
            return
        }
        willAppearIndexes = []
        willDisappearIndex = -1
        if currentIndex != index {
            listWillDisappear(at: currentIndex)
            listWillAppear(at: index)
            listDidDisappear(at: currentIndex)
            listDidAppear(at: index)
        }
    }

    open func reloadData() {
        guard let dataSource = dataSource else { return }
        if currentIndex < 0 || currentIndex >= dataSource.numberOfLists(in: self) {
            defaultSelectedIndex = 0
            currentIndex = 0
        }
        validListDict.values.forEach { (list) in
            if let listVC = list as? UIViewController {
                listVC.willMove(toParent: nil)
                listVC.removeFromParent()
            }
            list.listView().removeFromSuperview()
        }
        validListDict.removeAll()
        if type == .scrollView {
            scrollView.contentSize = CGSize(width: scrollView.bounds.size.width*CGFloat(dataSource.numberOfLists(in: self)), height: scrollView.bounds.size.height)
        }else {
            collectionView.reloadData()
        }
        listWillAppear(at: currentIndex)
        listDidAppear(at: currentIndex)
    }
    
    /// 批量更新
    public func performBatchUpdate(deletes: IndexSet, inserts: IndexSet, moves: [JXMoveIndex]) {
        guard let dataSource = dataSource else { return }
        
        // 需要删除的，清理记录
        deletes.forEach { i in
            if let removed = validListDict.removeValue(forKey: i) {
                if let vc = removed as? UIViewController {
                    vc.willMove(toParent: nil)
                    vc.removeFromParent()
                }
                removed.listView().removeFromSuperview()
            }
        }
        // 添加上的无需操作，后面会动态加载
        
        switch type {
        case .scrollView:
            scrollView.contentSize = CGSize(width: scrollView.bounds.size.width*CGFloat(dataSource.numberOfLists(in: self)), height: scrollView.bounds.size.height)
            
            /// 原始数据备份
            let backup = validListDict
            /// 处理过的记录
            var processed: [JXMoveIndex] = []
            /// 判断给定移动数据是否被处理过
            let fromShouldRemove: (JXMoveIndex) -> Bool = { i in
                return processed.first(where: { i.from == $0.to }) == nil
            }
            
            moves.forEach { i in
                let fromView = backup[i.from], toView = backup[i.to]
                /// 都没有加载，就跳过
                if fromView == nil && toView == nil {
                    return
                } else {
                    // 之前的移动操作覆盖了本次移动的起点，则不能删除；
                    // 否则就删除掉，将删除过的添加到目标位置
                    if fromShouldRemove(i) {
                        validListDict.removeValue(forKey: i.from)
                    }
                    validListDict[i.to] = fromView
                    fromView?.listView().frame = CGRect(x: CGFloat(i.to)*scrollView.bounds.size.width, y: 0, width: scrollView.bounds.size.width, height: scrollView.bounds.size.height)
                }
                processed.append(i)
            }
            break
        case .collectionView:
            
            moves.forEach { i in
                if let removed = validListDict.removeValue(forKey: i.from) {
                    validListDict[i.to] = removed
                }
            }
            
            break
        }
        if (containerVC.viewIsVisible) {
            listWillAppear(at: currentIndex)
            listDidAppear(at: currentIndex)
        }
        setNeedsLayout()
        layoutIfNeeded()
    }

    //MARK: - Private
    func initListIfNeeded(at index: Int) {
        guard let dataSource = dataSource else { return }
        if dataSource.listContainerView?(self, canInitListAt: index) == false {
            return
        }
        var existedList = validListDict[index]
        if existedList != nil {
            //列表已经创建好了
            return
        }
        existedList = dataSource.listContainerView(self, initListAt: index)
        guard let list = existedList else {
            return
        }
        if let vc = list as? UIViewController {
            containerVC.addChild(vc)
        }
        validListDict[index] = list
        if type == .scrollView {
            list.listView().frame = CGRect(x: CGFloat(index)*scrollView.bounds.size.width, y: 0, width: scrollView.bounds.size.width, height: scrollView.bounds.size.height)
            scrollView.addSubview(list.listView())
            
            if segmentedViewShouldRTLLayout() {
                segmentedView(horizontalFlipForView: list.listView())
            }
        }else {
            let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0))
            cell?.contentView.subviews.forEach { $0.removeFromSuperview() }
            list.listView().frame = cell?.contentView.bounds ?? CGRect.zero
            cell?.contentView.addSubview(list.listView())
        }
        
        if let vc = list as? UIViewController {
            vc.didMove(toParent: containerVC)
        }
    }

    private func listWillAppear(at index: Int) {
        guard let dataSource = dataSource else { return }
        guard checkIndexValid(index) else {
            return
        }
        var existedList = validListDict[index]
        if existedList != nil {
            existedList?.listWillAppear?()
            if let vc = existedList as? UIViewController {
                vc.beginAppearanceTransition(true, animated: false)
            }
        }else {
            //当前列表未被创建（页面初始化或通过点击触发的listWillAppear）
            guard dataSource.listContainerView?(self, canInitListAt: index) != false else {
                return
            }
            existedList = dataSource.listContainerView(self, initListAt: index)
            guard let list = existedList else {
                return
            }
            if let vc = list as? UIViewController {
                containerVC.addChild(vc)
            }
            validListDict[index] = list
            if type == .scrollView {
                if list.listView().superview == nil {
                    list.listView().frame = CGRect(x: CGFloat(index)*scrollView.bounds.size.width, y: 0, width: scrollView.bounds.size.width, height: scrollView.bounds.size.height)
                    scrollView.addSubview(list.listView())
                    
                    if segmentedViewShouldRTLLayout() {
                        segmentedView(horizontalFlipForView: list.listView())
                    }
                }
                list.listWillAppear?()
                if let vc = list as? UIViewController {
                    vc.beginAppearanceTransition(true, animated: false)
                }
            }else {
                let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0))
                cell?.contentView.subviews.forEach { $0.removeFromSuperview() }
                list.listView().frame = cell?.contentView.bounds ?? CGRect.zero
                cell?.contentView.addSubview(list.listView())
                list.listWillAppear?()
                if let vc = list as? UIViewController {
                    vc.beginAppearanceTransition(true, animated: false)
                }
            }
        }
    }

    private func listDidAppear(at index: Int) {
        guard checkIndexValid(index) else {
            return
        }
        currentIndex = index
        let list = validListDict[index]
        list?.listDidAppear?()
        if let vc = list as? UIViewController {
            vc.endAppearanceTransition()
        }
    }

    private func listWillDisappear(at index: Int) {
        guard checkIndexValid(index) else {
            return
        }
        let list = validListDict[index]
        list?.listWillDisappear?()
        if let vc = list as? UIViewController {
            vc.beginAppearanceTransition(false, animated: false)
        }
    }

    private func listDidDisappear(at index: Int) {
        guard checkIndexValid(index) else {
            return
        }
        let list = validListDict[index]
        list?.listDidDisappear?()
        if let vc = list as? UIViewController {
            vc.endAppearanceTransition()
        }
    }
    
    private func fixStableIndex(in scrollView: UIScrollView) {
        debugPrint(#function)
        /// 应该显示的索引
        let appearIndex = Int(scrollView.contentOffset.x/scrollView.bounds.size.width)
        
        if appearIndex == willDisappearIndex {
            // 预测出现的，现在消失了
            willAppearIndexes.forEach {
                debugPrint("❌ \($0)")
                listWillDisappear(at: $0)
                listDidDisappear(at: $0)
            }
            /// 预测消失的，现在出现了
            debugPrint("✅ \(appearIndex)")
            listWillAppear(at: appearIndex)
            listDidAppear(at: appearIndex)
        }
        else {
            // appearIndex 可能不在willAppearIndexes列表中，记录下
            let inAppearance = willAppearIndexes.contains(appearIndex)
            // 预测出现的，现在消失了
            willAppearIndexes.removeAll(where: { $0 == appearIndex })
            willAppearIndexes.forEach {
                debugPrint("❌ \($0)")
                listWillDisappear(at: $0)
                listDidDisappear(at: $0)
            }
            // 预测消失的，真的消失了
            debugPrint("❌ \(willDisappearIndex)")
            listDidDisappear(at: willDisappearIndex)
            // 预测出现的，现在真的出现了
            debugPrint("✅ \(appearIndex)")
            if !inAppearance {
                listWillAppear(at: appearIndex)
            }
            listDidAppear(at: appearIndex)
        }
        willAppearIndexes = []
        willDisappearIndex = -1
    }

    private func checkIndexValid(_ index: Int) -> Bool {
        guard let dataSource = dataSource else { return false }
        let count = dataSource.numberOfLists(in: self)
        if count <= 0 || index >= count || index < 0 {
            return false
        }
        return true
    }
}

extension JXSegmentedListContainerView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let dataSource = dataSource else { return 0 }
        return dataSource.numberOfLists(in: self)
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        cell.contentView.backgroundColor = listCellBackgroundColor
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        let list = validListDict[indexPath.item]
        if list != nil {
            list?.listView().frame = cell.contentView.bounds
            cell.contentView.addSubview(list!.listView())
        }
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return bounds.size
    }
    
    /// 在滚动过程中收集信息：消失的、出现的（可能有多个）
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.isTracking || scrollView.isDragging else {
            return
        }
        let percent = scrollView.contentOffset.x/scrollView.bounds.size.width
        let maxCount = Int(round(scrollView.contentSize.width/scrollView.bounds.size.width))
        var leftIndex = Int(floor(Double(percent)))
        leftIndex = max(0, min(maxCount - 1, leftIndex))
        let rightIndex = leftIndex + 1;
        //        debugPrint("left: \(leftIndex), current: \(currentIndex), right: \(rightIndex)")
        let remainderRatio = percent - CGFloat(leftIndex)
        if rightIndex == currentIndex {
            //当前选中的在右边，用户正在从右边往左边滑动
            if validListDict[leftIndex] == nil && remainderRatio < (1 - initListPercent) {
                initListIfNeeded(at: leftIndex)
            } else if validListDict[leftIndex] != nil && !willAppearIndexes.contains(leftIndex) {
                willAppearIndexes.append(leftIndex)
                listWillAppear(at: leftIndex)
            }
            
            if willDisappearIndex == -1 {
                willDisappearIndex = rightIndex
                listWillDisappear(at: willDisappearIndex)
            }
        } else {
            //当前选中的在左边，用户正在从左边往右边滑动
            if validListDict[rightIndex] == nil && remainderRatio > initListPercent {
                initListIfNeeded(at: rightIndex)
            } else if validListDict[rightIndex] != nil && !willAppearIndexes.contains(rightIndex) {
                willAppearIndexes.append(rightIndex)
                listWillAppear(at: rightIndex)
            }
            if willDisappearIndex == -1 {
                willDisappearIndex = leftIndex
                listWillDisappear(at: willDisappearIndex)
            }
        }
    }
    
    /// 滚动结束后，根据当前屏幕正在显示的索引和之前收集的信息，更新所有list的状态
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            fixStableIndex(in: scrollView)
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        fixStableIndex(in: scrollView)
    }
}

class JXSegmentedListContainerViewController: UIViewController {
    var viewWillAppearClosure: (()->())?
    var viewDidAppearClosure: (()->())?
    var viewWillDisappearClosure: (()->())?
    var viewDidDisappearClosure: (()->())?

    var viewIsVisible = false
    
    override var shouldAutomaticallyForwardAppearanceMethods: Bool { return false }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewWillAppearClosure?()
        viewIsVisible = true
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewDidAppearClosure?()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewWillDisappearClosure?()
        viewIsVisible = false
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewDidDisappearClosure?()
    }
}
