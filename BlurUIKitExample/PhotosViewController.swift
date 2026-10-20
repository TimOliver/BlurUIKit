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
    private let cellMargin = 24.0
    
    private var readableWidth: CGFloat {
        let safeAreaInsets = view.safeAreaInsets
        let horizontalSafeWidth = safeAreaInsets.left + safeAreaInsets.right
        let availableViewWidth = view.frame.width - (horizontalSafeWidth + cellMargin * 2.0)
        return min(650, min(view.readableContentGuide.layoutFrame.width, availableViewWidth))
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
        tabBarItem.title = "Photos"
        tabBarItem.image = UIImage(systemName: "photo.stack")
        tabBarItem.selectedImage = UIImage(systemName: "photo.stack")

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
        let insets = (view.frame.width - readableWidth) / 2.0
        collectionView.frame = view.bounds
        collectionView.contentInset.top = max(view.safeAreaInsets.top, 24)
        collectionView.contentInset.top = max(view.safeAreaInsets.bottom, 24)
        collectionView.contentInset.left = insets + view.safeAreaInsets.left
        collectionView.contentInset.right = insets + view.safeAreaInsets.right
        collectionView.collectionViewLayout.invalidateLayout()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { (_) in
            self.collectionView.collectionViewLayout.invalidateLayout()
        }, completion: nil)
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

extension PhotosViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Given the readable width of the available screen, apply a standardized aspect ratio
        // to get a consistent height
        CGSize(width: readableWidth, height: readableWidth / 1.777)
    }
}
