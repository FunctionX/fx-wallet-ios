//
//  FxCloudSubmitPublicKeyViewController.swift
//  XWallet
//
//  Created by HeiHuaBaiHua on 2020/5/20.
//  Copyright © 2020 Andy.Chan 6K. All rights reserved.
//

import WKKit
import FunctionX
import SwiftyJSON
import TrustWalletCore

extension FxCloudSubmitValidatorPublicKeyViewController {
    
    override class func instance(with context: [String : Any] = [:]) -> UIViewController? {
        guard let privateKey = context["privateKey"] as? PrivateKey else { return nil }
        
        let vc = FxCloudSubmitValidatorPublicKeyViewController(privateKey)
        if let parameter = context["parameter"] as? [String: Any] { vc.parameter = JSON(parameter) }
        return vc
    }
}

class FxCloudSubmitValidatorPublicKeyViewController: FxCloudWidgetActionViewController {
    
    required public init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    init(_ privateKey: PrivateKey) {
        self.keypair = FunctionXValidatorKeypair(privateKey)
        super.init(hrp: "", chainName: "")
    }
    
    let keypair: FunctionXValidatorKeypair
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override var titleText: String { TR("CloudWidget.SubValidatorPK.Title") }
    
    override func bindList() {
        super.bindList()
        
        listBinder.push(InfoTitleCell.self) { $0.titleLabel.text = TR("CloudWidget.SubValidatorPK.ValidatorPublickey") }
        listBinder.push(PublicKeyCell.self) { $0.publicKeyLabel.text = self.keypair.encodedPublicKey() ?? "" }
    }
    
    override func bindAction() {
        wk.view.confirmButton.title = TR("Submit_U")
        
        let keypair = self.keypair
        wk.view.confirmButton.rx.action = CocoaAction({
            Router.pushToSubmitValidatorPublicKeyCompleted(keypair: keypair)
        })
    }
}
