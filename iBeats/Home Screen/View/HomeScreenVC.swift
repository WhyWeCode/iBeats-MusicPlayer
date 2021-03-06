//
//  HomeScreenVC.swift
//  iBeats
//
//  Created by Mukesh on 10/03/19.
//  Copyright © 2019 Mukesh. All rights reserved.
//

import UIKit
import Alamofire

private enum HomeScreenStrings: String {
    case listScreenIdentifier = "ListScreenVC"
    case noAlbumAvailable = "No saved albums yet!!"
}

class HomeScreenVC: UIViewController {
    
    private var homeScreenVM: HomeScreenViewModel?
    private static let homeScreenCell = "HomeScreenCell"
    
    @IBOutlet weak var albumCollection: UICollectionView!
    @IBOutlet weak var searchBar: UISearchBar!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        viewSetup()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.isNavigationBarHidden = true

        homeScreenVM?.getAlbumInfoCount() ?? 0 > 0 ? albumCollection.restore() : albumCollection.setEmptyMessage(HomeScreenStrings.noAlbumAvailable.rawValue)
        albumCollection.reloadData()
    }
    
    // MARK: Setup Screen
    
    private func viewSetup() {
        
        homeScreenVM = HomeScreenViewModel()
        homeScreenVM?.albumDetails.notify(notifier: { [weak self] (info) in
            
            self?.updateScreen()
        })
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        searchBar.setShowsCancelButton(true, animated: true)
    }
    
    // MARK: Update Screen
    
    func updateScreen() {
        
        if let listScreenVC = storyboard?.instantiateViewController(withIdentifier: HomeScreenStrings.listScreenIdentifier.rawValue) as? ListScreenVC {
            
            listScreenVC.albumDetails = homeScreenVM?.albumDetails.value
            
            self.navigationController?.pushViewController(listScreenVC, animated: true)
        }
    }
    
    // MARK: Dismiss Keyboard
    
    @objc func dismissKeyboard() {
        
        view.endEditing(true)
    }
    
    @IBAction func deleteAlbumTapped(_ sender: UIButton) {
        
        if homeScreenVM?.getAlbumInfoCount() ?? 0 > 0, let albumDetails = homeScreenVM?.getAlbumLInfo(withIndex: sender.tag) {
            
            let detail = AlbumDetail.init(name: albumDetails.albumName, artist: albumDetails.artistName, url: nil, image: nil)
            
            homeScreenVM?.deleteAlbum(withAlbumDetail: detail)
            
            homeScreenVM?.getAlbumInfoCount() ?? 0 > 0 ? albumCollection.restore() : albumCollection.setEmptyMessage(HomeScreenStrings.noAlbumAvailable.rawValue)
            albumCollection.reloadData()
        }
    }
}

// MARK: Searchbar Delegates

extension HomeScreenVC: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        
        if let albumName = searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) , albumName.count > 0 {
            
            homeScreenVM?.searchAlbum(name: albumName)
        }
        
        dismissKeyboard()
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        
        searchBar.text = nil
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        
        searchBar.text = nil
        dismissKeyboard()
    }
}

// MARK: Collectionview Delegates and Datasource

extension HomeScreenVC: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return homeScreenVM?.getAlbumInfoCount() ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HomeScreenVC.homeScreenCell, for: indexPath) as? HomeScreenCell, let albumDetails = homeScreenVM?.getAlbumLInfo(withIndex: indexPath.row) else {
            
            return UICollectionViewCell()
        }
        
        cell.albumCover.image = UIImage(named: "PlaceholderImage")
        cell.deleteAlbumBtn.tag = indexPath.row
        cell.tappableView.tag = indexPath.row
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(gesture:)))
        cell.tappableView.addGestureRecognizer(tapGesture)
        
        if let imageURL = albumDetails.coverPicURL {
            
            // Download image in background
            DispatchQueue.global(qos: .background).async {
                
                Alamofire.request(imageURL).responseImage { response in
                    
                    if let image = response.result.value {
                        // Update image in main thread
                        DispatchQueue.main.async {
                            cell.albumCover.image = image
                        }
                    }
                }
            }
        }
        
        cell.loadDataWith(albumInfo: albumDetails)

        return cell
    }
    
    // MARK: Show Album Info Screen
    
    @objc func handleTapGesture(gesture : UITapGestureRecognizer) {
        // Preparing data to pass
        
        guard let albumInfoScreenVC = storyboard?.instantiateViewController(withIdentifier: AlbumInfoScreenVC.identifier) as? AlbumInfoScreenVC, let selectedTag = gesture.view?.tag, let albumDetail = homeScreenVM?.getAlbumLInfo(withIndex: selectedTag) else {
            
            return
        }
        
        let coverImgURL = CoverImage.init(image: albumDetail.coverPicURL, size: nil)
        
        let detailInfo = AlbumDetail.init(name: albumDetail.albumName ?? "", artist: albumDetail.artistName ?? "", url: nil, image: [coverImgURL])
        albumInfoScreenVC.albumDetail = detailInfo
        albumInfoScreenVC.isFromSearch = false
        
        // Navigate to Album info screen
        self.navigationController?.pushViewController(albumInfoScreenVC, animated: true)
    }
}

extension UICollectionView {
    
    // Show empty message when no saved album is available
    
    func setEmptyMessage(_ message: String) {
        let messageLabel = UILabel(frame: CGRect(x: 0, y: 0, width: self.bounds.size.width, height: self.bounds.size.height))
        messageLabel.text = message
        messageLabel.textColor = .black
        messageLabel.numberOfLines = 0;
        messageLabel.textAlignment = .center;
        messageLabel.sizeToFit()
        
        self.backgroundView = messageLabel;
    }
    
    func restore() {
        self.backgroundView = nil
    }
}
