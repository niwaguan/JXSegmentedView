//
//  JXSegmentedCustomCell.swift
//  JXSegmentedView
//
//  Created by jiaxin on 2018/12/28.
//  Copyright © 2018 jiaxin. All rights reserved.
//

import UIKit

open class JXSegmentedCustomCell: JXSegmentedTitleCell {
    public let numberLabel = UILabel()
    public let markerImageView = UIImageView()
    private var currentImageInfo: String?
    public let markerDot = UILabel()
    
    open override func commonInit() {
        super.commonInit()
        
        numberLabel.isHidden = true
        numberLabel.textAlignment = .center
        numberLabel.layer.masksToBounds = true
        contentView.addSubview(numberLabel)
        
        markerImageView.isHidden = true
        markerImageView.contentMode = .scaleAspectFit
        contentView.addSubview(markerImageView)
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        guard let myItemModel = itemModel as? JXSegmentedCustomItemModel else {
            return
        }
        
        numberLabel.sizeToFit()
        let height = myItemModel.numberHeight
        numberLabel.layer.cornerRadius = height/2
        numberLabel.bounds.size = CGSize(width: numberLabel.bounds.size.width + myItemModel.numberWidthIncrement, height: height)
        numberLabel.center = CGPoint(x: titleLabel.frame.maxX + myItemModel.numberOffset.x, y: titleLabel.frame.minY + myItemModel.numberOffset.y)
        
        markerImageView.center = CGPoint(x: numberLabel.center.x + markerImageView.bounds.size.width * 0.5 + myItemModel.imageOffsetX, y: numberLabel.center.y + myItemModel.imageOffsetY)
    }
    
    open override func reloadData(itemModel: JXSegmentedBaseItemModel, selectedType: JXSegmentedViewItemSelectedType) {
        super.reloadData(itemModel: itemModel, selectedType: selectedType )
        
        guard let myItemModel = itemModel as? JXSegmentedCustomItemModel else {
            return
        }
        
        var hiddenMarkerNumber = true
        var hiddenMarkerImage = true
        var hiddenMarkerDot = true
        
        switch myItemModel.type {
        case .number:
            hiddenMarkerNumber = myItemModel.number == 0
        case .image:
            currentImageInfo = myItemModel.imageInfo
            hiddenMarkerImage = currentImageInfo?.count == 0
        case .dot:
            hiddenMarkerDot = true
        default:
            break
        }
        
        numberLabel.isHidden = hiddenMarkerNumber
        markerImageView.isHidden = hiddenMarkerImage
        markerDot.isHidden = hiddenMarkerDot
        
        if !hiddenMarkerNumber {
            numberLabel.backgroundColor = myItemModel.numberBackgroundColor
            numberLabel.textColor = myItemModel.numberTextColor
            numberLabel.text = myItemModel.numberString
            numberLabel.font = myItemModel.numberFont
        }
        
        if !hiddenMarkerImage {
            if currentImageInfo != nil {
                markerImageView.image = UIImage(named: currentImageInfo!)
                markerImageView.bounds = CGRect.init(x: 0, y: 0, width: myItemModel.imageSize.width, height: myItemModel.imageSize.height)
            }
            else {
                markerImageView.image = nil
            }
        }
        
        if !hiddenMarkerDot {
            
        }
        
        setNeedsLayout()
    }
}
