//
//  ChatAvatarBinder.swift
//  XWallet
//
//  Created by HeiHua BaiHua on 2020/3/17.
//  Copyright © 2020 Andy.Chan 6K. All rights reserved.
//

import WKKit

private let colors: [UIColor] = [HDA(0xC27573),
                                 HDA(0xEE9C6C),
                                 HDA(0xCC9C75),
                                 HDA(0x58705A),
                                 HDA(0x3AA6B7),
                                 HDA(0x4378A2),
                                 HDA(0x534666),
                                 HDA(0xA29193)]

class ChatAvatarBinder: ChatAvatarView {
    
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        configuration()
    }
    
    private var text: String?
    private var image: UIImage?
    func set(text: String? = nil, image: UIImage? = nil) {
        self.text = text
        self.image = image
        draw()
    }
    
    private func draw() {
        
        imageView.isHidden = self.image == nil
        textLabel.isHidden = self.image != nil
        self.backgroundColor = COLOR.backgroud
        if let image = self.image {
            imageView.image = image
        } else if let text = self.text {
            guard text != textLabel.text else { return }
            
            textLabel.text = text.substring(to: 0).uppercased()
            let byte = Int(text.data(using: .utf8)?.bytes.first ?? 0)
            self.backgroundColor = colors[byte % colors.count]
        }
    }
    
    private func configuration() {
        self.layer.cornerRadius = frame.height * 0.5
        self.layer.masksToBounds = true
    }
    
}


class ChatAvatarView: UIView {
        
    lazy var textLabel: UILabel = {
        let v = UILabel()
        v.font = XWallet.Font(ofSize: 32, weight: .bold)
        v.textColor = .white
        v.backgroundColor = .clear
        v.textAlignment = .center
        return v
    }()
    
    lazy var imageView: UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFit
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
        backgroundColor = .white
    }
    
    private func layoutUI() {
        addSubviews([textLabel, imageView])
        
        textLabel.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        imageView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
}
