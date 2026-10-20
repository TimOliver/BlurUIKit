//
//  PhotosViewController.swift
//  BlurUIKitExample
//
//  Created by Tim Oliver on 30/9/2024.
//

import Foundation
import UIKit

final class PhotosViewController: UIViewController {

    private let statusBarBlurView = VariableBlurView()
    private let collectionView = UICollectionView(frame: .zero,
                                          collectionViewLayout: UICollectionViewFlowLayout())
    
    private let cellIdentifier = "CollectionCell"
    private let cellMargin: CGFloat = 24.0
    
    init() {
        super.init(nibName: nil, bundle: nil)
        tabBarItem.title = "Photos"
        tabBarItem.image = UIImage(systemName: "photo.stack")
        tabBarItem.selectedImage = UIImage(systemName: "photo.stack")

        collectionView.register(PhotosViewCollectionCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView.dataSource = self
        // Account for the safe area once, while allowing photos to scroll behind the blur.
        collectionView.contentInsetAdjustmentBehavior = .never
        view.addSubview(collectionView)
        
        statusBarBlurView.dimmingTintColor = .systemBackground
        view.addSubview(statusBarBlurView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Clamp the status bar blur view to the top safe area
        statusBarBlurView.frame = CGRect(origin: .zero,
                                         size: CGSize(width: view.bounds.width, height: view.safeAreaInsets.top))
        
        collectionView.frame = view.bounds
        let contentInset = UIEdgeInsets(top: max(view.safeAreaInsets.top, cellMargin),
                                        left: 0,
                                        bottom: max(view.safeAreaInsets.bottom, cellMargin),
                                        right: 0)
        if collectionView.contentInset != contentInset {
            collectionView.contentInset = contentInset
        }

        // Center one column within the safe area, including when its sides are asymmetric.
        let safeFrame = view.safeAreaLayoutGuide.layoutFrame
        let itemWidth = max(0, min(650, view.readableContentGuide.layoutFrame.width,
                                   safeFrame.width - cellMargin * 2))
        let horizontalMargin = (safeFrame.width - itemWidth) * 0.5
        let sectionInset = UIEdgeInsets(top: 0,
                                        left: safeFrame.minX - view.bounds.minX + horizontalMargin,
                                        bottom: 0,
                                        right: view.bounds.maxX - safeFrame.maxX + horizontalMargin)
        let itemSize = CGSize(width: itemWidth, height: itemWidth * 9.0 / 16.0)
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        // These setters invalidate the flow layout only when its geometry actually changes.
        if layout.itemSize != itemSize {
            layout.itemSize = itemSize
        }
        if layout.sectionInset != sectionInset {
            layout.sectionInset = sectionInset
        }
    }
}

extension PhotosViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        PhotosViewCollectionCell.imageCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier,
                                                            for: indexPath) as? PhotosViewCollectionCell else {
            fatalError("Incorrect cell type")
        }
        cell.index = indexPath.item
        return cell
    }
}

