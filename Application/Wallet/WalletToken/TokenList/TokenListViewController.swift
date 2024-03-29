

import pop
import Hero
import WKKit
import RxSwift
import RxCocoa
import MJRefresh
import SwiftyJSON
import AudioToolbox
import TrustWalletCore
import HapticGenerator
import RxViewController

extension WKWrapper where Base == TokenListViewController {
    var view: TokenListViewController.View { return base.view as! TokenListViewController.View }
    var navigationBar:TokenListViewController.TokenNavigationBar { return base.navigationBar as! TokenListViewController.TokenNavigationBar }
}

extension TokenListViewController {
    
    class override func instance(with context: [String : Any]) -> UIViewController? {
        guard let wallet = context["wallet"] as? WKWallet else { return nil }
        
        return TokenListViewController(wallet: wallet)
    }
}

class TokenListViewController: WKViewController { 
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    init(wallet: WKWallet) {
        self.wallet = wallet
        super.init(nibName: nil, bundle: nil)
    }
    
    let wallet: WKWallet
    lazy var viewModel = ViewModel(wallet)
    override var preferFullTransparentNavBar: Bool { return true }
    
    var moveBeginIndex: IndexPath?
    
    override func getNavigationBar() -> WKNavigationBar {
        return  TokenNavigationBar().then {
            $0.theme = WKNavBarTheme(barTint: .clear, backTint: .white, titleColor: HDA(0x080A32))
            $0.backgroundBlurView.alpha = 0
        }
    } 
    override func navigationItems(_ navigationBar: WKNavigationBar) { bindNavBar() }
    override func loadView() { view = View(frame: ScreenBounds) }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        logWhenDeinit()
        
        syncCoinList()
        
        bindAction()
        bindListView()
        bindMoveCell()
        bindSettings()
        bindScroll()
        
        FxNotificationTransactionServer.sharedSubject.subscribe(onNext: {[weak self] server in
            self?.bindPindView(server: server)
        }).disposed(by: defaultBag)
    }
     
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchData()
    }

    private func syncCoinList() {
        CoinService.current.sync()
    }
    
    private func bindPindView(server:FxNotificationTransactionServer) {
        let pindingView = wk.navigationBar.pindingButton
        server.pindRawUpdateSubject.map { $0 <= 0 }.do(onNext: { value in
            pindingView.loading(!value)
        })
        .bind(to: pindingView.rx.isHidden)
        .disposed(by: defaultBag)
    }
     
    private func bindAction() {
        weak var welf = self
        wk.view.addWalletButton.action { welf?.onClickAddWallet() }
        wk.navigationBar.settingsButton.action {
            Router.pushToSettings() 
        }
 
        wallet.event.isBackuped.subscribe(onNext:  {(value) in
            let image =  value ? IMG("Wallet.Settings") : IMG("Wallet.NeedBackUp")
            welf?.wk.navigationBar.settingsButton.setImage(image, for: .normal)
            welf?.wk.navigationBar.settingsButton.tintColor = value ?  .white : .clear
        }).disposed(by: defaultBag)
    }
    
    private func bindListView() {
        weak var welf = self
        let listView = wk.view.listView
        let listViewModel = self.viewModel
        
        listView.delegate = self
        listView.dataSource = self
        listView.register(Cell.self, forCellReuseIdentifier: Cell.description())
        listView.register(SectionView.self, forHeaderFooterViewReuseIdentifier: SectionView.description())
        
        listViewModel.refreshItems.elements.subscribe(onNext: { (_) in
            welf?.sectionTopMargin.removeAll()
            listView.reloadData()
        }).disposed(by: defaultBag)
        
        wk.view.amountLabel.wk.set(amount: listViewModel.legalBalance.value.value,
                                   thousandth: ThisAPP.CurrencyDecimal, isLegal: true, mb: true, animated: false)
        listViewModel.legalBalance.value
            .distinctUntilChanged()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { welf?.wk.view.amountLabel.wk.set(amount: $0, thousandth: ThisAPP.CurrencyDecimal, isLegal: true, mb: true) })
            .disposed(by: defaultBag)
         
//        navigationBar.isHidden = true
//        wk.view.listView.rx.contentOffset
//            .subscribe(onNext: {  point in
//                welf?.bindSectionScroll(offset: point)
//        }).disposed(by: defaultBag)
    }
    
    var sectionTopMargin:Dictionary<Int,CGFloat> = [:]
    fileprivate func bindSectionScroll(offset:CGPoint) {
        let view = wk.view
        let listView = wk.view.listView
        let listViewModel = self.viewModel
        sectionTopMargin.removeAll()
        let nBottom = navigationBar.bottom
        
        for i in 0..<listViewModel.displayItems.count {
            if let sectionView = listView.headerView(forSection: i) as? SectionView {
                
                let aframe = listView.convert(sectionView.frame, to: view)
                if sectionTopMargin[i] == nil {
                    sectionTopMargin[i] = aframe.origin.y + offset.y - nBottom
                }
                var nOffsetY:CGFloat = 0
                if aframe.origin.y <= nBottom {
                    let offsetY = offset.y - (sectionTopMargin[i] ?? 0)
                    if let nView = listView.headerView(forSection: i + 1) as? SectionView {
                        let nTransY = nView.transform.ty
                        let tframe = CGRect(origin: CGPoint(x: nView.origin.x,
                                                            y: nView.origin.y + nTransY),
                                            size: nView.size)
                        let nframe = listView.convert(tframe, to: view)
                        let tOffsetY = (offsetY + aframe.origin.y + aframe.height) - nframe.origin.y
                        if tOffsetY > 0 {
                            nOffsetY = max(0, tOffsetY)
                        }
                    }  
                    sectionView.mContentView.transform = CGAffineTransform(translationX: 0, y: min(nBottom, max(0, offsetY - nOffsetY)))
                    sectionView.blurView.alpha = min(1.0, offsetY * 0.1)
                } else {
                    sectionView.mContentView.transform = .identity
                    sectionView.blurView.alpha = 0
                }
            }
        }
    }
    
    private func bindSettings() {
        FxConfigServer.config?.map { "@ \( $0.account.nickName )" }
            .bind(to: wk.view.nameLabel.rx.text).disposed(by: defaultBag)
    }
    
    private func onClickAddWallet() {
        Router.pushToAddToken(wallet: wallet)
    }
    
    private func fetchData() {
        viewModel.refresh()
    }
     
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.view.height = ScreenHeight 
    }
}

//MARK: UITableViewDelegate, UITableViewDataSource
extension TokenListViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.displayItems.count
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { return 30.auto() }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: SectionView.description()) as? SectionView
        let coin = viewModel.displayItems[section].coin
        let chainName = coin.isFxCore ? "\(Node.Chain.functionX.rawValue)-Function X" : nil
        view?.tokenButton.bind(coin, string: chainName)
        return view
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { return 10.auto() }
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { return "" }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.displayItems[section].items.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80.auto()
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: Cell.description()) as! Cell
        cell.bind(viewModel.displayItems[indexPath.section].items[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath as IndexPath) as? Cell {
            let cellVM = viewModel.displayItems[indexPath.section].items[indexPath.row]
            (animators["0"] as? TokenRootViewController.InfoAnimator)?.cell = cell
            Router.pushTokenInfo(wallet: cellVM.wallet, coin: cellVM.coin)
        }
    }
}

//MARK: Drag/Drop Item
extension TokenListViewController: UITableViewDragDelegate, UITableViewDropDelegate {
    
    private func bindMoveCell() {
        
        let listView = wk.view.listView
        CoinService.current.didSync.subscribe(onNext: { (v) in
            listView.dragInteractionEnabled = v
        }).disposed(by: defaultBag)
        
        viewModel.refreshItems.elements.subscribe(onNext: { [weak self](items) in
            let enabled = items.count > 1
            listView.dropDelegate = enabled ? self : nil
            listView.dragDelegate = enabled ? self : nil
        }).disposed(by: defaultBag)
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        self.moveBeginIndex = nil
        guard sourceIndexPath.section == destinationIndexPath.section else { return }
        
        viewModel.exchangeItem(from: sourceIndexPath, to: destinationIndexPath)
        sectionTopMargin.removeAll()
        tableView.reloadData()
        tableView.contentOffset = tableView.contentOffset
        tableView.inactiveAWhile(1)
    }
    
    //MARK: UITableViewDropDelegate
    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: NSString.self)
    }
    
    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        if moveBeginIndex?.section != destinationIndexPath?.section { return UITableViewDropProposal(operation: .cancel) }
        
        return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }
    
    func tableView(_ tableView: UITableView, dropPreviewParametersForRowAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        return previewParameters(at: indexPath)
    }
    
    //MARK: UITableViewDragDelegate
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        self.moveBeginIndex = indexPath
        Haptic.impactMedium.generate()
        return [UIDragItem(itemProvider: NSItemProvider(object: NSString()))]
    }
    
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        
    }
    
    func tableView(_ tableView: UITableView, dragPreviewParametersForRowAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        return previewParameters(at: indexPath)
    }
    
    private func previewParameters(at indexPath: IndexPath) -> UIDragPreviewParameters {
        let param = UIDragPreviewParameters()
        param.visiblePath = UIBezierPath(roundedRect: CGRect(x: 16, y: 0,
                                                             width: ScreenWidth - 16 * 2,
                                                             height: Cell.height(model: nil)), cornerRadius: 16)
        return param
    }
}
 
extension TokenListViewController {
    private func applyTransform(view:UIView, withScale scale: CGFloat, anchorPoint: CGPoint) {
        view.layer.anchorPoint = anchorPoint
        var scale = scale != 0 ? scale : CGFloat.leastNonzeroMagnitude
        scale = floor(scale * 100) / 100
        let xPadding = 1/scale * (anchorPoint.x - 0.5)*view.bounds.width
        let yPadding = 1/scale * (anchorPoint.y - 0.5)*view.bounds.height
        view.transform = CGAffineTransform.identity.scaledBy(x: scale, y: scale).translatedBy(x: CGFloat(xPadding),y: CGFloat(yPadding))
    }
    
    private func bindScroll() {
        
        let viewSize = wk.view.bounds.size
        let listHeaderHeight = wk.view.listHeaderView.height
        wk.view.listView.rx.contentOffset
            .asObservable().subscribe(onNext: {[weak self] point in
                let offsetY = listHeaderHeight - 16.auto()
                self?.wk.view.bgroundView.frame = CGRect(x: 0, y: offsetY - point.y, width: viewSize.width, height: viewSize.height - offsetY + point.y + 200)
                self?.scrollProgress(offset: point)
            }).disposed(by: defaultBag)
        
        wk.view.amountLabel.rx
            .observe(String.self, "text")
            .bind(to: wk.navigationBar.amountLabel.rx.text)
            .disposed(by: wk.view.amountLabel.defaultBag)
        
        wk.view.listView.rx.observe(UIEdgeInsets.self, "contentInset")
            .distinctUntilChanged()
            .filterNil()
            .subscribe(onNext: {[weak self] (inset) in
                let height = UIApplication.shared.statusBarFrame.height + 56 + inset.top 
                self?.navigationBar.snp.updateConstraints { (make) in
                    make.height.equalTo(height)
                }
                self?.view.layoutIfNeeded()
                let offset:CGPoint = self?.wk.view.listView.contentOffset ?? .zero
                self?.scrollProgress(offset: offset) 
            }).disposed(by: defaultBag)
        
        scrollProgress(offset: CGPoint(x: 0, y: 1))
    }
    
    private func scrollProgress(offset:CGPoint)  {
        
        if wk.view.amountLabel.width > 0 &&
            wk.view.amountLabel.height > 0 && wk.navigationBar.bottom > 0 {
            let idistance:CGFloat = 36
            let minSacel:CGFloat = 0.5
            let iAlpha:CGFloat = minSacel + 0.1
            let rect = wk.view.listHeaderView.convert(wk.view.amountLabel.frame, to: view)
            let toRect = wk.view.convert(rect, to: navigationBar) 
            if toRect.maxY < wk.navigationBar.titleLabel.bottom {
                wk.view.amountLabel.alpha = 0
                wk.navigationBar.amountLabel.alpha = 1
                wk.navigationBar.amountLabel.frame = CGRect(origin: CGPoint(x: toRect.origin.x,
                                                                            y: wk.navigationBar.titleLabel.bottom - toRect.height), size: toRect.size)
            }else {
                wk.view.amountLabel.alpha = 1
                wk.navigationBar.amountLabel.frame = toRect
                wk.navigationBar.amountLabel.alpha = 0
            }
            let referRect = wk.view.listHeaderView.convert(wk.view.nameLabel.frame, to: view)
            let referOffsetY:CGFloat =  wk.view.amountLabelHeight * minSacel + 4.auto()
            let referDistance = referRect.minY - wk.navigationBar.bottom - referOffsetY 
            if referDistance >= 0 {
                let scale:CGFloat = referDistance >= idistance ? 1 : min(((1 - minSacel) + (referDistance * minSacel / idistance)), 1.02)
                applyTransform(view: wk.view.amountLabel, withScale: scale, anchorPoint: CGPoint(x: 0, y: 1))
                applyTransform(view: wk.navigationBar.amountLabel, withScale: scale, anchorPoint: CGPoint(x: 0, y: 1))
                let alpha = scale <= iAlpha ? min((iAlpha - scale) / (iAlpha - minSacel), 1) : 0
                wk.navigationBar.backgroundBlurView.alpha = 1
                wk.navigationBar.titleLabel.alpha = 1 - alpha
                wk.view.nameLabel.alpha = 1 - alpha
                wk.navigationBar.amountLabel.alpha = 0
                wk.navigationBar.titleLabel.snp.updateConstraints { (make) in
                    make.bottom.equalToSuperview()
                }
            }else {
                applyTransform(view: wk.view.amountLabel, withScale: minSacel, anchorPoint: CGPoint(x: 0, y: 1))
                applyTransform(view: wk.navigationBar.amountLabel, withScale: minSacel, anchorPoint: CGPoint(x: 0, y: 1))
                wk.navigationBar.backgroundBlurView.alpha = 1
                wk.navigationBar.titleLabel.alpha = 0
                wk.navigationBar.amountLabel.alpha = 1
                wk.view.nameLabel.alpha = 0 
                if (rect.origin.y + rect.height) <= wk.navigationBar.bottom  {
                    let distance0 = wk.navigationBar.bottom - (rect.origin.y + rect.height)
                    wk.navigationBar.titleLabel.snp.updateConstraints { (make) in
                        make.bottom.equalToSuperview().inset(min(16, distance0))
                    }
                }else {
                    wk.navigationBar.titleLabel.snp.updateConstraints { (make) in
                        make.bottom.equalToSuperview()
                    }
                }
            }
        }
    }
}

/*
 import Web3
 import XChains
 import FunctionX
 
 private let npxs = "0xA42E12cB783f9FBEB3d9c6314707bBE1fe1EB96a"
 private let fx = "0x0AD5CE837A789423CC6158053CAd5eB75A6183AC"
 private let dai = "0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD"
 private let fxUSD = "0x26544fA15e98cd6DaCcB749406D6c0147b7825a1"
 
 private var node: Node { NodeManager.shared.currentEthereumNode }
 private lazy var ethNode = EthereumNode(endpoint: node.url, chainId: node.chainId.i)
 private func testFX() {
//        testMint(token: npxs)
//        testApproveDeposit(contract: ThisAPP.FxConfig.collateralDAI(), token: dai)
//        testDeposit(contract: ThisAPP.FxConfig.collateralDAI())
     
//        testDraw(contract: ThisAPP.FxConfig.collateralDAI())
//        testMaxDrawAmount(contract: ThisAPP.FxConfig.collateralDAI(), token: "DAI").subscribe(onNext: { value in
//            print("xxx", value)
//        }, onError: { (e) in
//            print("xxxE", e.localizedDescription)
//        }).disposed(by: defaultBag)
     
//        testWithdraw(contract: ThisAPP.FxConfig.collateralDAI())
//        testMaxWithdrawAmount(contract: ThisAPP.FxConfig.collateralDAI(), token: "NPXS").subscribe(onNext: { value in
//            print("xxx", value)
//        }, onError: { (e) in
//            print("xxxE", e.localizedDescription)
//        }).disposed(by: defaultBag)
     
//        testRepay(contract: ThisAPP.FxConfig.collateralDAI())
//        testClose(contract: ThisAPP.FxConfig.collateralDAI())
     
//        testMint(token: fx)
//        testDeposit(contract: ThisAPP.FxConfig.collateralFX())
//        testDraw(contract: ThisAPP.FxConfig.collateralFX())
 }
 
 private func testMint(token: String) {
     
     let erc20 = EthereumContractNode(endpoint: node.url, chainId: node.chainId.i, contract: token)
     let mint = erc20.mint(to: "0x77F2022532009c5EB4c6C70f395DEAaA793481Bc", amount: 1000000.eth, gasLimit: 900000, gasPrice: 10.gwei, privateKey: "0xd118917c51830407ec2e59fd339c8b64dff3d8d001842ae21e55bbe68d2b5d1e")
     mint.subscribe(onNext: { value in
         print("xxx", value.hex())
     }, onError: { (e) in
         print("xxxE", e.localizedDescription)
     }).disposed(by: defaultBag)
 }
 
 private func testApproveDeposit(contract: String, token: String) {
     
     print("----begin----")
     let account = Keypair(privateKey: PrivateKey(data: Data(hex: "3741e28e26d1df113bffff063d4121d1559f9efa87cf0110aa3d0be1cf742018"))!, address: "0x77F2022532009c5EB4c6C70f395DEAaA793481Bc", derivationPath: "")
     let node = FunctionXEthereumBridge(rpc: ethNode.endpoint, chainId: 42, contract: contract)
     var tx = node.buildApproveTx(erc20: token, owner: account.address)!
     tx.gasPrice = EthereumQuantity(quantity: 10.gwei)
     tx.gas = EthereumQuantity(quantity: 900000)
     ethNode.send(tx: tx, privateKey: account.privateKey.data.hexString).subscribe(onNext: { value in
         print("xxx", value.hex())
     }, onError: { (e) in
         print("xxxE", e.localizedDescription)
     }).disposed(by: defaultBag)
 }
 
 private func testDeposit(contract: String) {
     
     print("----begin----")
     let account = Keypair(privateKey: PrivateKey(data: Data(hex: "3741e28e26d1df113bffff063d4121d1559f9efa87cf0110aa3d0be1cf742018"))!, address: "0x77F2022532009c5EB4c6C70f395DEAaA793481Bc", derivationPath: "")
     let collateral = FunctionXEthereumCollateral(rpc: node.url, chainId: node.chainId.i, contract: contract)
     var tx = collateral.buildDepositTx(from: account.address, amount: 100.eth)!
     tx.gasPrice = EthereumQuantity(quantity: 10.gwei)
     tx.gas = EthereumQuantity(quantity: 900000)
     ethNode.send(tx: tx, privateKey: account.privateKey.data.hexString).subscribe(onNext: { value in
         print("xxx", value.hex())
     }, onError: { (e) in
         print("xxxE", e.localizedDescription)
     }).disposed(by: defaultBag)
 }
 
 private func testMaxDrawAmount(contract: String, token: String) -> Observable<BigUInt> {
     
     print("----begin----")
     let account = Keypair(privateKey: PrivateKey(data: Data(hex: "3741e28e26d1df113bffff063d4121d1559f9efa87cf0110aa3d0be1cf742018"))!, address: "0x77F2022532009c5EB4c6C70f395DEAaA793481Bc", derivationPath: "")
     let collateral = FunctionXEthereumCollateral(rpc: node.url, chainId: node.chainId.i, contract: contract)
     let exchangeRate = FunctionXEthereumExchangeRates(rpc: node.url, chainId: node.chainId.i, contract: ThisAPP.FxConfig.collateralExchanges())
     
     let loan = collateral.getLoan(of: account.address)
     let minCratio = collateral.minCratio()
     let rate = exchangeRate.effectiveValue(sourceSymbol: token, sourceAmount: 1.eth, destinationSymbol: "fxUSD")
     
     let decimal = 18
     return Observable.combineLatest(loan, minCratio, rate).map{ (loan, minCratio, rate) in
         
         let collateral = loan.0
         let debt = loan.1
         
         let rateValue = rate.description.div10(decimal, decimal)
         let minCratioValue = minCratio.description.div10(decimal, decimal)
         
         let collateralFxUSD = collateral.description.mul(rateValue, decimal)
         let maxCollateralFxUSD = collateralFxUSD.div(minCratioValue)
         let availableFxUSD = maxCollateralFxUSD.sub(debt.description)
         
         return BigUInt(availableFxUSD) ?? 0
     }
 }
 
 private func testDraw(contract: String) {
     
     print("----begin----")
     let account = Keypair(privateKey: PrivateKey(data: Data(hex: "3741e28e26d1df113bffff063d4121d1559f9efa87cf0110aa3d0be1cf742018"))!, address: "0x77F2022532009c5EB4c6C70f395DEAaA793481Bc", derivationPath: "")
     let collateral = FunctionXEthereumCollateral(rpc: node.url, chainId: node.chainId.i, contract: contract)
     var tx = collateral.buildDrawTx(from: account.address, amount: 50.eth)!
     tx.gasPrice = EthereumQuantity(quantity: 10.gwei)
     tx.gas = EthereumQuantity(quantity: 900000)
     ethNode.send(tx: tx, privateKey: account.privateKey.data.hexString).subscribe(onNext: { value in
         print("xxx", value.hex())
     }, onError: { (e) in
         print("xxxE", e.localizedDescription)
     }).disposed(by: defaultBag)
 }
 
 private func testMaxWithdrawAmount(contract: String, token: String) -> Observable<BigUInt> {
     
     print("----begin----")
     let account = Keypair(privateKey: PrivateKey(data: Data(hex: "3741e28e26d1df113bffff063d4121d1559f9efa87cf0110aa3d0be1cf742018"))!, address: "0x77F2022532009c5EB4c6C70f395DEAaA793481Bc", derivationPath: "")
     let collateral = FunctionXEthereumCollateral(rpc: node.url, chainId: node.chainId.i, contract: contract)
     let exchangeRate = FunctionXEthereumExchangeRates(rpc: node.url, chainId: node.chainId.i, contract: ThisAPP.FxConfig.collateralExchanges())
     
     let loan = collateral.getLoan(of: account.address)
     let minCratio = collateral.minCratio()
     let rate = exchangeRate.effectiveValue(sourceSymbol: "fxUSD", sourceAmount: 1.eth, destinationSymbol: token)
     
     let decimal = 18
     return Observable.combineLatest(loan, minCratio, rate).map{ (loan, minCratio, rate) in
         
         let collateral = loan.0
         let debt = loan.1
         print("load", collateral.description, debt.description)
         
         let rateValue = rate.description.div10(decimal, decimal)
         let minCratioValue = minCratio.description.div10(decimal, decimal)
         
         let minDebtFxUSD = debt.description.mul(minCratioValue)
         let minDebtToken = minDebtFxUSD.mul(rateValue, decimal)
         let availableWithdraw = collateral.description.sub(minDebtToken.description)
         
         return BigUInt(availableWithdraw) ?? 0
     }
 }
 
 private func testWithdraw(contract: String) {
     
     print("----begin----")
     let account = Keypair(privateKey: PrivateKey(data: Data(hex: "3741e28e26d1df113bffff063d4121d1559f9efa87cf0110aa3d0be1cf742018"))!, address: "0x77F2022532009c5EB4c6C70f395DEAaA793481Bc", derivationPath: "")
     let collateral = FunctionXEthereumCollateral(rpc: node.url, chainId: node.chainId.i, contract: contract)
     var tx = collateral.buildWithdrawTx(from: account.address, amount: BigUInt("10".wei)!)!
     tx.gasPrice = EthereumQuantity(quantity: 10.gwei)
     tx.gas = EthereumQuantity(quantity: 900000)
     ethNode.send(tx: tx, privateKey: account.privateKey.data.hexString).subscribe(onNext: { value in
         print("xxx", value.hex())
     }, onError: { (e) in
         print("xxxE", e.localizedDescription)
     }).disposed(by: defaultBag)
 }
 
 private func testRepay(contract: String) {
     
     print("----begin----")
     let account = Keypair(privateKey: PrivateKey(data: Data(hex: "3741e28e26d1df113bffff063d4121d1559f9efa87cf0110aa3d0be1cf742018"))!, address: "0x77F2022532009c5EB4c6C70f395DEAaA793481Bc", derivationPath: "")
     let collateral = FunctionXEthereumCollateral(rpc: node.url, chainId: node.chainId.i, contract: contract)
     var tx = collateral.buildRepayTx(from: account.address, amount: BigUInt("10".wei)!)!
     tx.gasPrice = EthereumQuantity(quantity: 10.gwei)
     tx.gas = EthereumQuantity(quantity: 900000)
     ethNode.send(tx: tx, privateKey: account.privateKey.data.hexString).subscribe(onNext: { value in
         print("xxx", value.hex())
     }, onError: { (e) in
         print("xxxE", e.localizedDescription)
     }).disposed(by: defaultBag)
 }
 
 private func testClose(contract: String) {
     
     print("----begin----")
     let account = Keypair(privateKey: PrivateKey(data: Data(hex: "3741e28e26d1df113bffff063d4121d1559f9efa87cf0110aa3d0be1cf742018"))!, address: "0x77F2022532009c5EB4c6C70f395DEAaA793481Bc", derivationPath: "")
     let collateral = FunctionXEthereumCollateral(rpc: node.url, chainId: node.chainId.i, contract: contract)
     var tx = collateral.buildCloseTx(from: account.address)!
     tx.gasPrice = EthereumQuantity(quantity: 10.gwei)
     tx.gas = EthereumQuantity(quantity: 900000)
     ethNode.send(tx: tx, privateKey: account.privateKey.data.hexString).subscribe(onNext: { value in
         print("xxx", value.hex())
     }, onError: { (e) in
         print("xxxE", e.localizedDescription)
     }).disposed(by: defaultBag)
 }
 
 */
