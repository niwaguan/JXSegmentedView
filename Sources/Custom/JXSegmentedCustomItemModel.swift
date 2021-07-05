//
//  JXSegmentedCustomItemModel.swift
//  JXSegmentedView
//
//  Created by jiaxin on 2018/12/28.
//  Copyright © 2018 jiaxin. All rights reserved.
//

import Foundation
import UIKit

open class JXSegmentedCustomItemModel: JXSegmentedTitleItemModel {
    var type: CornerMarkerType = .none
    
    // case number
    open var number: Int = 0
    open var numberString: String = "0"
    open var numberBackgroundColor: UIColor = .red
    open var numberTextColor: UIColor = .white
    open var numberWidthIncrement: CGFloat = 0
    open var numberFont: UIFont = UIFont.systemFont(ofSize: 11)
    open var numberOffset: CGPoint = CGPoint.zero
    open var numberHeight: CGFloat = 14
    
    // case image
    open var imageInfo: String?
    open var imageSize: CGSize = CGSize.zero
    open var imageOffsetX: CGFloat = 0
    open var imageOffsetY: CGFloat = 0
    
    // case dot
    open var dotState = false
    open var dotSize = CGSize.zero
    open var dotCornerRadius: CGFloat = 0
    open var dotColor = UIColor.red
    open var dotOffset: CGPoint = CGPoint.zero
}
