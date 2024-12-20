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
    
    private var readableWidth: CGFloat {
        view.readableContentGuide.layoutFrame.width
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
        tabBarItem.title = "Home"
        tabBarItem.image = UIImage(systemName: "house")
        tabBarItem.selectedImage = UIImage(systemName: "house.fill")
        
        collectionView.register(PhotosViewCollectionCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
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
        
        // Clamp the collection view to the screen's readable width
        let readableWidth = view.readableContentGuide.layoutFrame.width
        let insets = (view.frame.width - readableWidth) / 2.0
        collectionView.frame = view.bounds
        collectionView.contentInset.left = insets
        collectionView.contentInset.right = insets
        collectionView.collectionViewLayout.invalidateLayout()
    }
}

extension PhotosViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        5
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath)
    }
}

extension PhotosViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Given the readable width of the available screen, apply a standardized aspect ratio
        // to get a consistent height
        CGSize(width: readableWidth, height: readableWidth * 0.475)
    }
}
