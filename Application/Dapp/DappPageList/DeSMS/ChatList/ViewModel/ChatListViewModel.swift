//
//  ChatListViewModel.swift
//  XWallet
//
//  Created by HeiHua BaiHua on 2020/3/9.
//  Copyright © 2020 Andy.Chan 6K. All rights reserved.
//

import WKKit
import RxSwift
import FunctionX
import SwiftyJSON
import TrustWalletCore

extension ChatListViewController {
    class ViewModel: WKListViewModel<CellViewModel> {
        
        let service: SmsService
        
        var wallet: FxWallet { service.wallet }
        var address: String { service.address }
        var fetchName: APIAction<String> { service.fetchName }
        private(set) var needReload = PublishSubject<Bool>()
            
        deinit {
            self.service.offline()
        }
        
        init(_ privateKey: PrivateKey) {
            self.service = SmsServiceManager.service(forWallet: FxWallet(privateKey: privateKey, chain: .sms))
            super.init()
            
            self.service.online()
            self.pager.hasNext = { _ in false }
            self.fetchItems = { [weak self] _ -> Observable<[CellViewModel]> in
                guard let this = self else { return Observable.empty() }

                return this.service.refreshContactList.execute()
                    .do(onNext: { this.items = $0 })
            }
            
            service.preload().subscribe().disposed(by: defaultBag)
            
            service.didUpdate.filter{$0}
                .subscribe(onNext: { [weak self] (value) in
                    guard let this = self else { return }
                    
                    this.items = this.service.latestContactList()
                    this.needReload.onNext(value)
            }).disposed(by: defaultBag)
        }
    }
}
