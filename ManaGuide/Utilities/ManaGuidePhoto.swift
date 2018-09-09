//
//  ManaGuidePhoto.swift
//  ManaGuide
//
//  Created by Jovito Royeca on 10/06/2018.
//  Copyright © 2018 Jovito Royeca. All rights reserved.
//

import UIKit
import CoreData
import IDMPhotoBrowser
import ManaKit
import PromiseKit

class ManaGuidePhoto : NSObject, IDMPhotoProtocol {
    var cardMID: NSManagedObjectID?
    var progressUpdateBlock: IDMProgressUpdateBlock?
    private var _underlyingImage: UIImage?
    
    init(cardMID: NSManagedObjectID) {
        self.cardMID = cardMID
    }
    
    func underlyingImage() -> UIImage? {
        return _underlyingImage
    }
    
    func loadUnderlyingImageAndNotify() {
        guard let cardMID = cardMID,
            let card = ManaKit.sharedInstance.dataStack?.mainContext.object(with: cardMID) as? CMCard else {
            return
        }
        
        firstly {
            ManaKit.sharedInstance.downloadImage(ofCard: card, imageType: .normal)
        }.done {
            self._underlyingImage = ManaKit.sharedInstance.cardImage(card, imageType: .normal)
            self.imageLoadingComplete()
        }.catch { error in
            self.unloadUnderlyingImage()
            self.imageLoadingComplete()
        }
    }
    
    func unloadUnderlyingImage() {
        _underlyingImage = nil
    }
    
    func placeholderImage() -> UIImage? {
        guard let cardMID = cardMID,
            let card = ManaKit.sharedInstance.dataStack?.mainContext.object(with: cardMID) as? CMCard else {
            return nil
        }
        
        return ManaKit.sharedInstance.cardBack(card)
    }
    
    func caption() -> String? {
        return nil
    }
    
    func imageLoadingComplete() {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: IDMPhoto_LOADING_DID_END_NOTIFICATION),
                                        object: self)
    }

}