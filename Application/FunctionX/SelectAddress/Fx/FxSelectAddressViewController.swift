//
//  FxSelectAddressViewController.swift
//  XWallet
//
//  Created by HeiHua BaiHua on 2020/2/27.
//  Copyright © 2020 Andy.Chan 6K. All rights reserved.
//

import WKKit
import RxSwift
import TrustWalletCore

class FxSelectAddressViewController: SelectAddressViewController {
    
    override class func instance(with context: [String : Any] = [:]) -> UIViewController? {
        guard let wallet = context["wallet"] as? Wallet,
            let url = context["url"] as? String else { return nil }
        
        return FxSelectAddressViewController(wallet: wallet, walletConnectURL: url)
    }
    
    let walletConnectURL: String
    
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    init(wallet: Wallet, walletConnectURL: String) {
        self.walletConnectURL = walletConnectURL
        super.init(wallet: wallet)
        
        logWhenDeinit()
    }
    
    override func onClickConfirm() {
        guard let cellVM = self.selectedItem else { return }
        
        Router.pushToFxWalletConnect(url: walletConnectURL, privateKey: cellVM.privateKey)
    }
    
    override var listViewModel: ListViewModel { FxListViewModel(wallet) }
}
