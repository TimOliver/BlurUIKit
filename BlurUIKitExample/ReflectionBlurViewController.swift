//
//  ReflectionBlurViewController.swift
//  BlurUIKitExample
//
//  Created by Tim Oliver on 3/10/2026.
//

import UIKit

final class ReflectionBlurViewController: UIViewController {

    private let reflectionView = ReflectionBlurView()
    private let collectionView: UICollectionView

    private static let cellIdentifier = "AppleParkPhotoCell"

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 16.0
        layout.minimumInteritemSpacing = 0.0
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(nibName: nil, bundle: nil)
        tabBarItem.title = "Reflection"
        tabBarItem.image = UIImage(systemName: "square.bottomhalf.filled")
        tabBarItem.selectedImage = UIImage(systemName: "square.bottomhalf.filled")

        collectionView.register(PhotosViewCollectionCell.self,
                                forCellWithReuseIdentifier: Self.cellIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        reflectionView.contentView.addSubview(collectionView)

        reflectionView.minimumBlurRadius = 5.0
        reflectionView.maximumBlurRadius = 50.0
        reflectionView.reflectionAlpha = 0.5
        reflectionView.dimmingTintColor = .black
        reflectionView.dimmingAlpha = .constant(alpha: 0.85)
        view.addSubview(reflectionView)

        // Make the collection view's native scrolling gesture available across the full screen.
        view.addGestureRecognizer(collectionView.panGestureRecognizer)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let bounds: CGRect = {
            var frame = view.bounds
            frame.origin.y += view.safeAreaInsets.top
            frame.size.height -= view.safeAreaInsets.top
            return frame
        }()

        reflectionView.frame = bounds
        reflectionView.layoutIfNeeded()

        let contentBounds = reflectionView.contentView.bounds
        let midpointMargin: CGFloat = 32.0
        let maximumContentHeight = max(contentBounds.height - midpointMargin, 0.0)

        let itemWidth = max(min(contentBounds.width * 0.82, 640.0, maximumContentHeight * (16.0 / 9.0)), 0.0)
        let itemHeight = itemWidth * (9.0 / 16.0)

        collectionView.frame = CGRect(x: contentBounds.minX,
                                      y: contentBounds.maxY - itemHeight - midpointMargin,
                                      width: contentBounds.width,
                                      height: itemHeight)

        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let horizontalInset = max((collectionView.bounds.width - itemWidth) * 0.5, 0.0)
        let itemSize = CGSize(width: itemWidth, height: itemHeight)
        let sectionInset = UIEdgeInsets(top: 0.0,
                                       left: horizontalInset,
                                       bottom: 0.0,
                                       right: horizontalInset)
        guard layout.itemSize != itemSize || layout.sectionInset != sectionInset else { return }

        layout.itemSize = itemSize
        layout.sectionInset = sectionInset
        layout.invalidateLayout()
    }
}

extension ReflectionBlurViewController: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        reflectionView.setNeedsReflectionUpdate()
    }
}

extension ReflectionBlurViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        PhotosViewCollectionCell.imageCount
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Self.cellIdentifier,
                                                            for: indexPath) as? PhotosViewCollectionCell else {
            fatalError("Incorrect cell type")
        }

        cell.index = indexPath.item
        return cell
    }
}
