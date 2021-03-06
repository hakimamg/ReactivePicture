//
//  UnsplashPhotosService.swift
//  ReactivePictures
//
//  Created by Amg on 02/06/2020.
//  Copyright © 2020 Amg-Gauthier. All rights reserved.
//

import RxSwift

protocol UnsplashPhotosService: class {
    /// Returns by default 10 photos
    func getPhotos() -> Observable<([UnsplashPhoto]?, Error?)>
    /// Specify a different count
    func getPhotos(pageNumber: Int, perPage: Int) -> Observable<([UnsplashPhoto]?, Error?)>
    
    /// Returns random photos
    func getRandomPhotos(count: Int) -> Observable<([UnsplashPhoto]?, Error?)>
    
    /// Return a photo by the given **id**
    func getPhoto(id: String) -> Observable<(UnsplashPhoto?, Error?)>
}

class UnsplashPhotosServiceImplementation: UnsplashPhotosService {
    
    // MARK: - Properties
    
    private let networkClient = NetworkClient(baseUrlString: BaseURLs.unsplash)
    
    // MARK: - Public Methods
    
    func getPhotos() -> Observable<([UnsplashPhoto]?, Error?)> {
        self.networkClient.getArray([UnsplashPhoto].self,
                                    UnsplashEndpoints.getPhotos)
    }
    
    func getPhotos(pageNumber: Int, perPage: Int) -> Observable<([UnsplashPhoto]?, Error?)> {
        return Observable.deferred {
            let parameter = ["page": String(pageNumber),
                             "per_page": String(perPage),
                             "order_by": "popular"]
            return self.networkClient.getArray([UnsplashPhoto].self,
                                               UnsplashEndpoints.getPhotos,
                                               parameters: parameter)
        }
    }
    
    func getRandomPhotos(count: Int) -> Observable<([UnsplashPhoto]?, Error?)> {
        return Observable.deferred {
            let parameter = ["count": String(count)]
            return self.networkClient.getArray([UnsplashPhoto].self,
                                               UnsplashEndpoints.getRandomPhotos,
                                               parameters: parameter)
        }
    }
    
    func getPhoto(id: String) -> Observable<(UnsplashPhoto?, Error?)> {
        return Observable.deferred {
            return self.networkClient.get(UnsplashPhoto.self,
                                          "\(UnsplashEndpoints.getPhotoById)\(id)",
                                          printURL: true)
        }
    }
}
