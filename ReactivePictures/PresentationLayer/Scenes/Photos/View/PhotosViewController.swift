//
//  PhotosViewController.swift
//  ReactivePictures
//
//  Created by Amg on 02/06/2020.
//  Copyright © 2020 Amg-Gauthier. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class PhotosViewController: UIViewController {
    
    // MARK: - Private Properties
    
    private let photosViewModel: PhotosViewModelImplementation
    private let disposeBag = DisposeBag()
    private var cachedImages: [Int: UIImage] = [:]
    private var bottomConstraint: NSLayoutConstraint?
    private let photoId = "photoCell"
    
    private lazy var photosCollectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout())
        collectionView.backgroundColor = .white
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: photoId)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private lazy var bottomActivityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // MARK: - Inits
    
    init(photosViewModel: PhotosViewModelImplementation) {
        self.photosViewModel = photosViewModel
        super.init(nibName: "PhotosViewController", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindCollectionView()
        bindLoadingState()
        bindBottomActivityIndicator()
        
        photosViewModel.viewDidLoad.accept(())
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupNavigationBar()
        setupNavigationItem()
    }
    
}

// MARK: - Binding
extension PhotosViewController {
    private func bindCollectionView() {
        /// Bind unsplash photos to the collection view items
        photosViewModel.unsplashPhotos
            .bind(to: photosCollectionView.rx.items(
                cellIdentifier: photoId,
                cellType: PhotoCell.self)) { _, _, _ in }
            .disposed(by: disposeBag)
        
        /// Prepare for cell to be displayed. Launch photo loading operation if no cached image is found
        photosCollectionView.rx.willDisplayCell
            .filter { $0.cell.isKind(of: PhotoCell.self) }
            .map { ($0.cell as! PhotoCell, $0.at.item)}
            .do(onNext: { (cell, index) in
                cell.imageView.image = nil
            })
            .subscribe(onNext: { [weak self] (cell, index) in
                if let cachedImage = self?.cachedImages[index] {
                    print("Using cached image for: \(index)")
                    cell.imageView.image = cachedImage
                } else {
                    cell.activityIndicator.startAnimating()
                    self?.photosViewModel
                        .willDisplayCellAtIndex
                        .accept(index)
                }
            })
            .disposed(by: disposeBag)
        
        /// On image retrival, 1)stop activity indicator, 2) animate the cell, 3) assign the image, and 4) add it to cached images
        photosViewModel.imageRetrievedSuccess
            .debug("imageRetrievedSuccess", trimOutput: false)
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] (image, index) in
                if let cell = self?.photosCollectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? PhotoCell {
                    
                    // 1
                    cell.activityIndicator.stopAnimating()
                    
                    // 2
                    cell.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                    UIView.animate(withDuration: 0.25) {
                        cell.transform = .identity
                    }
                    
                    // 3
                    cell.imageView.image = image
                    
                    // 4
                    self?.cachedImages[index] = image
                }
            })
            .disposed(by: disposeBag)
        
        /// On image retrieval error, stop activity indicator, and assign image to **nil**
        photosViewModel.imageRetrievedError
            .debug("imageRetrievedSuccess", trimOutput: false)
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] (index) in
                if let cell = self?.photosCollectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? PhotoCell {
                    cell.activityIndicator.stopAnimating()
                    cell.imageView.image = nil
                }
            })
            .disposed(by: disposeBag)
        
        /// Cancelling image loading operation for a cell that disappeared
        photosCollectionView.rx.didEndDisplayingCell
            .map { $0.1 }
            .map { $0.item }
            .bind(to: photosViewModel.didEndDisplayingCellAtIndex)
            .disposed(by: disposeBag)
        
        photosCollectionView.rx.modelSelected(UnsplashPhoto.self)
            .compactMap { $0.id }
            .bind(to: photosViewModel.didChoosePhotoWithId)
            .disposed(by: disposeBag)
        
        /// Infinite scrolling
        photosCollectionView.rx.willDisplayCell
            .flatMap({ (_, indexPath) -> Observable<(section: Int, row: Int)> in
                return Observable.of((indexPath.section, indexPath.row))
            })
            .filter { (section, row) in
                let numberOfSections = self.photosCollectionView.numberOfSections
                let numberOfItems = self.photosCollectionView.numberOfItems(inSection: section)
                
                return section == numberOfSections - 1
                    && row == numberOfItems - 1
        }
        .map { _ in () }
        .bind(to: photosViewModel.didScrollToTheBottom)
        .disposed(by: disposeBag)
    }
    
    private func bindLoadingState() {
        photosViewModel.isLoadingFirstPage
            .observeOn(MainScheduler.instance)
            .map({ (isLoading) in
                return isLoading ? "Fetching..." : "Unsplash Photos"
            })
            .bind(to: navigationItem.rx.title)
            .disposed(by: disposeBag)
    }
    
    private func bindBottomActivityIndicator() {
        photosViewModel.isLoadingAdditionalPhotos
            .observeOn(MainScheduler.instance)
            .do(onNext: { [weak self] isLoading in
                self?.updateConstraintForMode(loadingMorePhotos: isLoading)
            })
            .bind(to: bottomActivityIndicator.rx.isAnimating)
            .disposed(by: disposeBag)
    }
}

// MARK: - UI Setup
extension PhotosViewController {
    private func setupUI() {
        if #available(iOS 13.0, *) {
            self.overrideUserInterfaceStyle = .light
        }
        self.view.backgroundColor = .white
        self.view.addSubview(photosCollectionView)
        self.view.addSubview(bottomActivityIndicator)
        
        bottomConstraint = photosCollectionView.bottomAnchor
            .constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor)
        
        NSLayoutConstraint.activate([
            photosCollectionView.leftAnchor
                .constraint(equalTo: self.view.leftAnchor),
            photosCollectionView.topAnchor
                .constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            photosCollectionView.rightAnchor
                .constraint(equalTo: self.view.rightAnchor),
            bottomConstraint!
        ])
        
        NSLayoutConstraint.activate([
            bottomActivityIndicator.centerXAnchor
                .constraint(equalTo: self.view.centerXAnchor),
            bottomActivityIndicator.bottomAnchor
                .constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor),
            bottomActivityIndicator.widthAnchor
                .constraint(equalToConstant: 44),
            bottomActivityIndicator.heightAnchor
                .constraint(equalToConstant: 44)
        ])
    }
    
    /// Changes photoCollectionView's bottom constraint with a subtle animation
    private func updateConstraintForMode(loadingMorePhotos: Bool) {
        self.bottomConstraint?.constant = loadingMorePhotos ? -20 : 0
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func setupNavigationBar() {
        self.navigationController?.navigationBar.tintColor = .black
        self.navigationController?.navigationBar.barTintColor = .white
        self.navigationController?.navigationBar.isTranslucent = false
    }
    
    private func setupNavigationItem() {
        self.navigationItem.title = "Unsplash Photos"
    }
    
    private func collectionViewLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.itemSize = Dimensions.photosItemSize
        let numberOfCellsInRow = floor(Dimensions.screenWidth / Dimensions.photosItemSize.width)
        let inset = (Dimensions.screenWidth - (numberOfCellsInRow * Dimensions.photosItemSize.width)) / (numberOfCellsInRow + 1)
        layout.sectionInset = .init(top: inset,
                                    left: inset,
                                    bottom: inset,
                                    right: inset)
        return layout
    }
}
