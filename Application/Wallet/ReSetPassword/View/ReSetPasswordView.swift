//
//
//  XWallet
//
//  Created by May on 2020/12/17.
//  Copyright © 2020 May All rights reserved.
//

import WKKit

extension ReSetPasswordViewController {
    class View: SetPasswordViewController.View {
        
        required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override init(frame: CGRect) {
            super.init(frame: frame)
            logWhenDeinit()
            
            configuration()
            layoutUI()
        }
        
        private func configuration() {
            subtitleLabel.text = TR("SetPwd.Confirm.Title")
            doneButton.title = TR("Confirm")
        }
        
        private func layoutUI() {
            
        }
    }
}
        
