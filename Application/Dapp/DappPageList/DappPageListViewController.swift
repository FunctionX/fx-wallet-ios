//
//  Python3
//  MakeSwiftFiles
//
//  Created by HeiHuaBaiHua 
//  Copyright © 2017年 HeiHuaBaiHua. All rights reserved.
//

import WKKit
import RxSwift
import RxCocoa
import XLPagerTabStrip
import Hero

class DappPageListViewController: BaseButtonBarPagerTabStripViewController<DappPageButtonBarCell> {
    var animators: Array<WKHeroAnimator> = Array<WKHeroAnimator>()
    
    var backgoundView = UIView().then {
        $0.backgroundColor = UIColor.white
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    init(wallet: Wallet, coin: Coin) {
        self.viewModel = ViewModel(wallet: wallet, coin: coin)
        self.popularList = DappPopularListBinder(viewModel.popularListVM)
        self.favoriteList = DappFavoriteListBinder(viewModel.favoriteListVM)
        super.init(nibName: nil, bundle: nil)

        self.logWhenDeinit()
        self.configuration()
        self.edgesForExtendedLayout = .all
        self.modalPresentationCapturesStatusBarAppearance = true 
    }

    let viewModel: ViewModel
    let popularList: DappPopularListBinder
    let favoriteList: DappFavoriteListBinder
    var listControllers: [DappSubListBinder] { [popularList, favoriteList] }
    private var lineView: PagerTabStriButtonBarViewDecorator?

    var buttonBarHeight: CGFloat { DappSubListBinder.topEdge }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        listControllers.get(currentIndex)?.refresh()
    }
  
    override func viewDidLoad() {
        super.viewDidLoad()
        self.layoutUI()
        containerView.contentInsetAdjustmentBehavior = .never 
    }
    
    private func didMove(to index: DappPageButtonBarCell?) {
        guard let type = index?.type else { return }
        switch type {
        case .popular:
            popularList.refresh()
        case .favorite:
            favoriteList.refresh()
        }
    }

    //MARK: BaseButtonBarPagerTabStripViewController
    override func viewControllers(for pagerTabStripController: PagerTabStripViewController) -> [UIViewController] { return listControllers }

    override func configure(cell: DappPageButtonBarCell, for indicatorInfo: IndicatorInfo) {
        cell.bind(indicatorInfo)
    }

    private func configuration() {
        settings.style.buttonBarHeight = 0
        settings.style.selectedBarHeight = 3
        settings.style.buttonBarLeftContentInset = 24.auto()
        settings.style.buttonBarRightContentInset = 24.auto()
        settings.style.buttonBarMinimumLineSpacing = 0
        settings.style.buttonBarItemsShouldFillAvailableWidth = true
        settings.style.buttonBarBackgroundColor = .clear
        settings.style.selectedBarBackgroundColor = .clear
        settings.style.buttonBarItemBackgroundColor = .clear
        settings.style.buttonBarBackgroundColor = UIColor.clear
        
        buttonBarItemSpec = ButtonBarItemSpec.cellClass(width: { _ in 2 })
        changeCurrentIndexProgressive = {[weak self](oldCell: DappPageButtonBarCell?, newCell: DappPageButtonBarCell?,
                                                     progressPercentage: CGFloat, changeCurrentIndex: Bool, animated: Bool) -> Void in
            guard changeCurrentIndex == true else { return }
            if oldCell == nil {
                newCell?.textLabel.transform =  CGAffineTransform.identity
                newCell?.textLabel.textColor =  HDA(0x080A32)

                
            }
            if newCell == nil {
                oldCell?.textLabel.transform =  CGAffineTransform.identity.scaledBy(x: 0.8, y: 0.8)
                newCell?.textLabel.textColor =  HDA(0x080A32).withAlphaComponent(0.2)
                
            }
            newCell?.textLabel.font = XWallet.Font(ofSize: 24, weight: .bold)
            oldCell?.textLabel.font = XWallet.Font(ofSize: 24)
            
            self?.didMove(to: newCell)
        }
    }

    private func layoutUI() {
        self.view.backgroundColor = .clear
        self.view.insertSubview(backgoundView, at: 0)
        backgoundView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        self.containerView.backgroundColor = UIColor.clear
        self.view.addSubview(buttonBarView)
        self.lineView = PagerTabStriButtonBarViewDecorator(view: buttonBarView)
        buttonBarView.backgroundColor = .clear
        buttonBarView.size = CGSize(width: (ScreenWidth - 24.auto() * 2) * 0.5, height: buttonBarHeight)
        buttonBarView.snp.makeConstraints { (make) in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(buttonBarHeight)
        }
        
        containerView.snp.remakeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        // Tab滚动效果
        containerView.rx.contentOffset.subscribe(onNext: {[weak self] point in
            self?.tabProgress(offset: point)
        }).disposed(by: defaultBag)
        
     
    }
    
    private func tabProgress(offset:CGPoint) {
        let pageIndex =  self.pageFor(contentOffset: offset.x)
        let pageWidth = self.pageWidth
        let minSacel:CGFloat = 0.8
        let minColorAlpha:CGFloat = 0.2
        let textColorBlock:(CGFloat) ->UIColor = { _sacel in
            let alpha =  1 - ((1 - _sacel) * minSacel / minColorAlpha)
            return HDA(0x080A32).withAlphaComponent(alpha)
        }
         
        let setCellBlock:(CGFloat, Int, DappPageButtonBarCell) ->Void = {[weak self] _offsetX, _pageIndex , _cell in
            let pageOffsetX = self?.pageOffsetForChild(at: _pageIndex) ?? 0
            let distance = abs(_offsetX - pageOffsetX)
            let sacel = min((1 - min((distance / pageWidth), 1)) * (1 - minSacel) + minSacel, 1)
            _cell.textLabel.transform =  CGAffineTransform.identity.scaledBy(x: sacel, y: sacel)
            _cell.textLabel.textColor = textColorBlock(sacel)
        }
        
        if let pageTabCell = buttonBarView.cellForItem(at: IndexPath(row: pageIndex, section: 0)) as? DappPageButtonBarCell {
            setCellBlock(offset.x, pageIndex, pageTabCell)
            
            if let pageTabCell_1 = buttonBarView.cellForItem(at: IndexPath(row: pageIndex + 1, section: 0) ) as? DappPageButtonBarCell  {
                setCellBlock(offset.x, pageIndex+1, pageTabCell_1)
            }
            
            if pageIndex - 1 >= 0 , let pageTabCell_0 = buttonBarView.cellForItem(at: IndexPath(row: pageIndex - 1, section: 0) ) as? DappPageButtonBarCell  {
                setCellBlock(offset.x, pageIndex-1, pageTabCell_0)
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.view.height = ScreenHeight 
    }
}


//MARK: Extension Of XLPagerTabStrip
extension IndicatorInfo { 
    fileprivate init(title: String, type: DappPageButtonBarCell.Types) {
        self.init(title: title)
        self.userInfo = type
    }

    fileprivate var type: DappPageButtonBarCell.Types? {
        return userInfo as? DappPageButtonBarCell.Types
    }
}

extension DappPopularListBinder: IndicatorInfoProvider {
    func indicatorInfo(for pagerTabStripController: PagerTabStripViewController) -> IndicatorInfo {
        return IndicatorInfo(title: TR("Dapp.Page.Popular"), type: .popular)
    }
}

extension DappFavoriteListBinder: IndicatorInfoProvider {
    func indicatorInfo(for pagerTabStripController: PagerTabStripViewController) -> IndicatorInfo {
        return IndicatorInfo(title: TR("Dapp.Page.Favorite"), type: .favorite)
    }
}
