//
//  CardActivityItemProvider.swift
//  ManaGuide
//
//  Created by Jovito Royeca on 16/06/2018.
//  Copyright © 2018 Jovito Royeca. All rights reserved.
//

import UIKit
import ManaKit

class CardActivityItemProvider: UIActivityItemProvider {
    let card: CMCard
    
    init(_ card: CMCard) {
        self.card = card
        
        super.init(placeholderItem: card.image(type: .normal,
                                               faceOrder: 0,
                                               roundCornered: true)!)
    }
    
    override var item: Any {
        get {
            return card.image(type: .normal,
                              faceOrder: 0,
                              roundCornered: true)!
        }
    }
}
