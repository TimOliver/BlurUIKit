//
//  PhotosViewCollectionCell.swift
//  BlurUIKitExample
//
//  Created by Tim Oliver on 20/12/2024.
//

import UIKit

final class PhotosViewCollectionCell: UICollectionViewCell {
    
    let imageView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        imageView.backgroundColor = .red
        imageView.layer.masksToBounds = true
        imageView.layer.cornerCurve = .continuous
        contentView.addSubview(imageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = contentView.bounds
        imageView.layer.cornerRadius = contentView.bounds.width * 0.1
    }
    
}
