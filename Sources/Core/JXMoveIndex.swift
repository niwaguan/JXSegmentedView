//
//  JXMoveIndex.swift
//  JXSegmentedView
//
//  Created by Gaoyang on 2021/6/9.
//

import Foundation

/// 批量更新时，移动记录
public struct JXMoveIndex {
    let from: Int
    let to: Int
    public init(from: Int, to: Int) {
        self.from = from
        self.to = to
    }
}
