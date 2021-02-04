//
//  SecurityVerificationController.swift
//  XWallet
//
//  Created by HeiHuaBaiHua on 2020/10/21.
//  Copyright © 2020 Andy.Chan 6K. All rights reserved.
//

import WKKit
import RxSwift
import RxCocoa

class SecurityVerificationNavController: WKNavigationController {
    override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        self.modalPresentationStyle = .fullScreen
        self.hero.isEnabled = false
        self.hero.navigationAnimationType = .none
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension WKWrapper where Base == SecurityVerificationController {
    var view: Base.View { return base.view as! Base.View }
}

class SecurityVerificationController: WKViewController {
    let didComplatedSubject:PublishSubject = PublishSubject<Void>()
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    deinit { Router.isSecurityVerifying = false }
    
    override func loadView() { view = View(frame: ScreenBounds) }
    override func viewDidLoad() {
        super.viewDidLoad() 
        bind()
    }
     
    func toStartVerify(delay milliseconds:Int = 0) {
        Router.isSecurityVerifying = true
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
            self.startVerify(delay: milliseconds)
        }
    }
    
    override func bindNavBar() { navigationBar.isHidden = true }
    
    private func bind() {
        guard let wallet = XWallet.currentWallet?.wk else { return }
        
        switch wallet.securityType {
        case .pwd:
            wk.view.verifyIV.image = IMG("Bio.Lock_White")
            wk.view.verifyLabel.text = TR("SecurityVerify.tip$", TR("Password").lowercased())
        default:
            
            let isAuthFace = LocalAuthManager.shared.isAuthFace
            let type = TR(isAuthFace ? "Face" : "Fingerprint").lowercased()
            wk.view.verifyIV.image = IMG(isAuthFace ? "Bio.FaceId_White" : "Bio.TouchId_White")
            wk.view.verifyLabel.text = TR("SecurityVerify.tip$", type)
        }
        
        weak var welf = self
        wk.view.actionButton.action { welf?.startFullVerify() }
        wk.view.resetWalletButton.action {
            Router.showResetWalletNoticeAlert { (error) in
                guard error == nil else { return }
                welf?.deleteWallet()
            }
        }
    }
    
    private func startVerify(delay milliseconds:Int = 0) {
        if LocalAuthManager.shared.isUsable {
            startBioVerify(delay: milliseconds)
        } else {
            startFullVerify()
        }
    }
    
    private func startBioVerify(delay milliseconds:Int = 0) {
        var config = LocalAuthConfiguration()
        config.authReason = TR(LocalAuthManager.shared.isAuthTouch ? "Biometrics.AuthTouchID" : "Biometrics.AuthFaceID")
        LocalAuthManager.shared.auth(config: config, delay: milliseconds) { [weak self](result) in
            switch result {
            case .errorUserCancel: break
            default:
                if result.isSuccess {
                    self?.dismiss(animated: false, completion: {
                        self?.didComplatedSubject.onNext(())
                        self?.didComplatedSubject.onCompleted()
                    })
                }
            }
        }
    }
    
    private func startFullVerify() {
        if XWallet.currentWallet?.wk.securityType == .bio {
            startBioVerify()
        } else {
            Router.showVerifyPasswordAlert(dissmissWhenCompeted: false) {[weak self] (error) in
                if error == nil {
                    self?.dismiss(animated: false, completion: { 
                        self?.didComplatedSubject.onNext(())
                        self?.didComplatedSubject.onCompleted()
                    })
                }
            }
        }
    }
    
    private func deleteWallet() {
        guard let wallet = XWallet.sharedKeyStore.currentWallet else { return }
        FxAPIManager.fx.userLogOut().subscribe(onNext: { (json) in
            WKLog.Info("-")
        }, onError: {[weak self] (e) in
            self?.hud?.text(m: e.asWKError().msg, p: .topCenter)
        }).disposed(by: defaultBag)
        
        let error = XWallet.sharedKeyStore.delete(wallet: wallet)
        if let error = error {
            self.hud?.text(m: error.localizedDescription)
            Router.resetRootController(wallet: nil, animated: true)
        } else {
            Router.resetRootController(wallet: nil, animated: true).done { (result) in
                XWallet.clear(wallet)
            }
        }
    }
    
    
}

extension SecurityVerificationController: NotificationToastProtocol {
    func allowToast(notif: FxNotification) -> Bool { false }
}

extension SecurityVerificationController {
    class View: UIView {
        
        lazy var logoIV = UIImageView(image: IMG("Security.logo"))
        
        fileprivate lazy var verifyIV = UIImageView()
        fileprivate lazy var verifyLabel = UILabel(text: TR("SecurityVerify.tip$", ""), font: XWallet.Font(ofSize: 16), lines: 0, alignment: .center)
        fileprivate lazy var actionButton = UIButton(.clear)
        
        fileprivate lazy var resetWalletButton: UIButton = {
            let v = UIButton()
            v.title = TR("ResetWallet.Title")
            v.titleFont = XWallet.Font(ofSize: 16)
            v.titleColor = UIColor.white.withAlphaComponent(0.5)
            return v
        }()
        
        required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override init(frame: CGRect) {
            super.init(frame: frame)
            logWhenDeinit()
            
            configuration()
            layoutUI()
        }
        
        private func configuration() {
            backgroundColor = HDA(0x080A32)
        }
        
        private func layoutUI() {
            addSubviews([logoIV, verifyIV, verifyLabel, actionButton, resetWalletButton])
            
            logoIV.snp.makeConstraints { (make) in
                make.top.equalTo(StatusBarHeight + 54.auto())
                make.centerX.equalToSuperview()
            }
            
            verifyIV.snp.makeConstraints { (make) in
                make.centerY.equalToSuperview().offset(-25.auto())
                make.centerX.equalToSuperview()
                make.size.equalTo(CGSize(width: 50, height: 50).auto())
            }
            
            verifyLabel.snp.makeConstraints { (make) in
                make.top.equalTo(verifyIV.snp.bottom).offset(16.auto())
                make.left.right.equalToSuperview().inset(24.auto())
            }
            
            actionButton.snp.makeConstraints { (make) in
                make.top.left.right.equalToSuperview()
                make.bottom.equalTo(resetWalletButton.snp.top)
            }
            
            resetWalletButton.snp.makeConstraints { (make) in
                make.bottom.equalTo(-50)
                make.centerX.equalToSuperview()
                make.size.equalTo(CGSize(width: 240, height: 30))
            }
        }
    }
}

extension SecurityVerificationController {
    override func heroAnimator(from: String, to: String) -> WKHeroAnimator? {
        switch (from, to) {
        case ("SecurityVerificationController", "VerifyPasswordAlertController"): return nil
        default: return nil
        }
    }
}

