//
//  MnemonicViewController.swift
//  XWallet
//
//  Created by HeiHuaBaiHua on 2019/11/26.
//  Copyright © 2019 Andy.Chan 6K. All rights reserved.
//

import UIKit
import WKKit
import RxSwift
import HDWalletKit

extension MnemonicViewController {
    override class func instance(with context: [String : Any] = [:]) -> UIViewController? {
        
        let vc = MnemonicViewController()
        if let mnemonic = context["mnemonic"] as? String {
            vc.mnemonic = mnemonic
        }
        return vc
    }
}

class MnemonicViewController: WKViewController {

    private var items: [String] = []
    private var mnemonic = "" {
        didSet {
            items = mnemonic.components(separatedBy: " ")
        }
    }
    
    override func loadView() { self.view = View(frame: ScreenBounds) }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        logWhenDeinit()
        configuration()
        
        bind()
        
        XWallet.Event.User.didBackupMnemonic()
    }
    
    //MARK: Bind
    func bind() {
        
        let view = self.view as! View
        view.listView.delegate = self
        view.listView.dataSource = self
        view.listView.register(Cell.self, forCellWithReuseIdentifier: Cell.description())
        
        self.navigationBar.isHidden = true
        view.navBar.backButton.rx.tap.subscribe(onNext: { [weak self](_) in
            self?.navigationController?.popViewController(animated: true)
        }).disposed(by: defaultBag)
        
        view.navBar.rightButton.isHidden = true
//        view.navBar.rightButton.rx.tap.subscribe(onNext: { [weak self](_) in
//            Router.pushToVerifyMnemonic(mnemonic: self?.mnemonic ?? "")
//        }).disposed(by: defaultBag)
        
        NotificationCenter.default.rx
            .notification(UIApplication.userDidTakeScreenshotNotification)
            .takeUntil(self.rx.deallocated)
            .subscribe(onNext: { (_) in
                view.hud?.text(m: TR("Mnemonic.ScreenshotTip"))
        }).disposed(by: defaultBag)
    }
    
    func configuration() {
        if items.isEmpty {
            mnemonic = Mnemonic.create(strength: .hight)
        }
    }
}

//MARK: CollectionView
extension MnemonicViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
        
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: (ScreenWidth - 20.1)/2, height: 30)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0001
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0001
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Cell.description(), for: indexPath) as! Cell
        cell.textLabel.text = items[indexPath.row]
        cell.numberLabel.text = (indexPath.row + 1).s
        return cell
    }
}
