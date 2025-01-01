//
//  PhotosViewCollectionCell.swift
//  BlurUIKitExample
//
//  Created by Tim Oliver on 20/12/2024.
//

import UIKit

private var appleParkAtlas: UIImage = {
    if let image = UIImage(named: "AppleParkAtlas")?.preparingForDisplay() {
        return image
    }
    fatalError("Cannot find image")
}()

final class PhotosViewCollectionCell: UICollectionViewCell {
    
    public var index: Int = 0 {
        didSet { setNeedsLayout() }
    }
    
    static let atlasImageSize = CGSize(width: 0.499, height: 0.249)
    private let imageView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        imageView.image = appleParkAtlas
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
        
        let origin = CGPoint(x: CGFloat(index % 2) * 0.5, y: (CGFloat(index / 2) * 0.25))
        imageView.layer.contentsRect = CGRect(origin: origin, size: Self.atlasImageSize)
    }
    
}
