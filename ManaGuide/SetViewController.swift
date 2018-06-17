//
//  SetViewController.swift
//  ManaGuide
//
//  Created by Jovito Royeca on 21/07/2017.
//  Copyright © 2017 Jovito Royeca. All rights reserved.
//

import UIKit
import DATASource
import Font_Awesome_Swift
import InAppSettingsKit
import ManaKit
import MBProgressHUD
import PromiseKit

enum SetViewControllerSegmentedIndex: Int {
    case cards
    case wiki
    
    var description : String {
        switch self {
        // Use Internationalization, as appropriate.
        case .cards: return "Cards"
        case .wiki: return "Wiki"
        }
    }
    
    static var count: Int {
        return 2
    }
}

class SetViewController: BaseViewController {

    // MARK: Constants
    let searchController = UISearchController(searchResultsController: nil)

    // MARK: Variables
    var set:CMSet?
    var dataSource: DATASource?
    var sectionIndexTitles = [String]()
    var sectionTitles = [String]()
    var collectionView: UICollectionView?
    var firstLoad = false
    
    // MARK: Outlets
    @IBOutlet weak var contentSegmentedControl: UISegmentedControl!
    @IBOutlet weak var rightMenuButton: UIBarButtonItem!
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: Actions
    
    @IBAction func contentAction(_ sender: UISegmentedControl) {
        updateDataDisplay()
    }
    
    @IBAction func showRightMenuAction(_ sender: UIBarButtonItem) {
        showSettingsMenu(file: "Set")
    }
    
    // MARK: Overrides
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        contentSegmentedControl.setFAIcon(icon: .FADatabase, forSegmentAtIndex: 0)
        contentSegmentedControl.setFAIcon(icon: .FAWikipediaW, forSegmentAtIndex: 1)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: kIASKAppSettingChanged), object:nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateData(_:)), name: NSNotification.Name(rawValue: kIASKAppSettingChanged), object: nil)
        
        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Filter"
        definesPresentationContext = true
        
        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
            navigationItem.hidesSearchBarWhenScrolling = false
        } else {
            tableView.tableHeaderView = searchController.searchBar
        }

        rightMenuButton.image = UIImage.init(icon: .FABars, size: CGSize(width: 30, height: 30), textColor: .white, backgroundColor: .clear)
        rightMenuButton.title = nil
        
        tableView.register(ManaKit.sharedInstance.nibFromBundle("CardTableViewCell"), forCellReuseIdentifier: "CardCell")
        tableView.register(UINib(nibName: "BrowserTableViewCell", bundle: nil), forCellReuseIdentifier: "SetInfoCell")
        tableView.keyboardDismissMode = .onDrag
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !firstLoad {
            firstLoad = true
            updateDataDisplay()
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showCard" {
            if let dest = segue.destination as? CardViewController,
                let dict = sender as? [String: Any] {
                
                dest.cardIndex = dict["cardIndex"] as! Int
                dest.cards = dict["cards"] as? [CMCard]
            }
        } else if segue.identifier == "showCardModal" {
            if let nav = segue.destination as? UINavigationController {
                if let dest = nav.childViewControllers.first as? CardViewController,
                    let dict = sender as? [String: Any] {
                    dest.cardIndex = dict["cardIndex"] as! Int
                    dest.cards = dict["cards"] as? [CMCard]
                    dest.title = dest.cards?[dest.cardIndex].name
                }
            }
        } else if segue.identifier == "showSearch" {
            if let dest = segue.destination as? SearchViewController,
                let request = sender as? NSFetchRequest<NSFetchRequestResult> {
                
                dest.request = request
                dest.title = "Search Results"
                dest.customSectionName = "nameSection"
            }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        updateDataDisplay()
    }
    
    // MARK: Custom methods
    func updateDataDisplay() {
        let defaults = defaultsValue()
        let setDisplayBy = defaults["setDisplayBy"] as! String
        
        switch contentSegmentedControl.selectedSegmentIndex {
        case SetViewControllerSegmentedIndex.cards.rawValue:
            if #available(iOS 11.0, *) {
                navigationItem.searchController?.searchBar.isHidden = false
                navigationItem.hidesSearchBarWhenScrolling = false
            } else {
                tableView.tableHeaderView = searchController.searchBar
            }
            
            switch setDisplayBy {
            case "list":
                dataSource = getDataSource(nil)
                updateSections()
            case "grid":
                tableView.dataSource = self
            default:
                ()
            }
        case SetViewControllerSegmentedIndex.wiki.rawValue:
            if #available(iOS 11.0, *) {
                navigationItem.searchController?.searchBar.isHidden = true
                navigationItem.hidesSearchBarWhenScrolling = true
            } else {
                tableView.tableHeaderView = nil
            }
            
            tableView.dataSource = self
        default:
            ()
        }
        
        tableView.delegate = self
        tableView.reloadData()
    }
    
    func getDataSource(_ fetchRequest: NSFetchRequest<NSFetchRequestResult>?) -> DATASource? {
        var request:NSFetchRequest<NSFetchRequestResult>?
        let defaults = defaultsValue()
        let setSectionName = defaults["setSectionName"] as! String
        let setSecondSortBy = defaults["setSecondSortBy"] as! String
        let setOrderBy = defaults["setOrderBy"] as! Bool
        let setDisplayBy = defaults["setDisplayBy"] as! String
        var ds: DATASource?
        
        if let fetchRequest = fetchRequest {
            request = fetchRequest
        } else {
            request = NSFetchRequest(entityName: "CMCard")
            
            request!.sortDescriptors = [NSSortDescriptor(key: setSectionName, ascending: setOrderBy),
                                        NSSortDescriptor(key: setSecondSortBy, ascending: setOrderBy)]
            request!.predicate = NSPredicate(format: "set.code = %@", set!.code!)
        }
        
        switch setDisplayBy {
        case "list":
            ds = DATASource(tableView: tableView, cellIdentifier: "CardCell", fetchRequest: request!, mainContext: ManaKit.sharedInstance.dataStack!.mainContext, sectionName: setSectionName == "numberOrder" ? nil : setSectionName, configuration: { cell, item, indexPath in
                if let card = item as? CMCard,
                    let cardCell = cell as? CardTableViewCell {
                    
                    cardCell.card = card
                    cardCell.updateDataDisplay()
                }
            })
        case "grid":
            if let collectionView = collectionView {
                ds = DATASource(collectionView: collectionView, cellIdentifier: "CardImageCell", fetchRequest: request!, mainContext: ManaKit.sharedInstance.dataStack!.mainContext, sectionName: setSectionName == "numberOrder" ? nil : setSectionName, configuration: { cell, item, indexPath in
                    if let card = item as? CMCard {
                        if let imageView = cell.viewWithTag(100) as? UIImageView {
                            if let image = ManaKit.sharedInstance.cardImage(card, imageType: .normal) {
                                imageView.image = image
                            } else {
                                imageView.image = ManaKit.sharedInstance.cardBack(card)
                                
                                firstly {
                                    ManaKit.sharedInstance.downloadImage(ofCard: card, imageType: .normal)
                                }.done { (image: UIImage?) in
                                    if let image = image {
                                        UIView.transition(with: imageView,
                                                          duration: 1.0,
                                                          options: .transitionFlipFromLeft,
                                                          animations: {
                                                              imageView.image = image
                                                          },
                                                          completion: nil)
                                    }
                                }.catch { error in
                                    print("\(error)")
                                }
                            }
                        }
                    }
                })
            }
        default:
            ()
        }
    
        if let ds = ds {
            ds.delegate = self
            return ds
        }
        return nil
    }
    
    func updateSections() {
        if let dataSource = dataSource {
            let cards = dataSource.all() as [CMCard]
            sectionIndexTitles = [String]()
            sectionTitles = [String]()
            
            let defaults = defaultsValue()
            let setSectionName = defaults["setSectionName"] as! String
            let setDisplayBy = defaults["setDisplayBy"] as! String
            
            switch setSectionName {
            case "nameSection":
                for card in cards {
                    if let nameSection = card.nameSection {
                        if !sectionIndexTitles.contains(nameSection) {
                            sectionIndexTitles.append(nameSection)
                        }
                    }
                }
            case "typeSection":
                for card in cards {
                    if let typeSection = card.typeSection {
                        let prefix = String(typeSection.prefix(1))
                        
                        if !sectionIndexTitles.contains(prefix) {
                            sectionIndexTitles.append(prefix)
                        }
                    }
                }
            case "rarity_.name":
                for card in cards {
                    if let rarity = card.rarity_ {
                        let prefix = String(rarity.name!.prefix(1))
                        
                        if !sectionIndexTitles.contains(prefix) {
                            sectionIndexTitles.append(prefix)
                        }
                    }
                }
            case "artist_.name":
                for card in cards {
                    if let artist = card.artist_ {
                        let prefix = String(artist.name!.prefix(1))
                        
                        if !sectionIndexTitles.contains(prefix) {
                            sectionIndexTitles.append(prefix)
                        }
                    }
                }
            default:
                ()
            }
            
            
            var sections = 0
            switch contentSegmentedControl.selectedSegmentIndex {
            case SetViewControllerSegmentedIndex.cards.rawValue:
                switch setDisplayBy {
                case "list":
                    sections = dataSource.numberOfSections(in: tableView)
                case "grid":
                    if let collectionView = collectionView {
                        sections = dataSource.numberOfSections(in: collectionView)
                    }
                default:
                    ()
                }
            default:
                ()
            }
            
            if sections > 0 {
                for i in 0...sections - 1 {
                    if let sectionTitle = dataSource.titleForHeader(i) {
                        sectionTitles.append(sectionTitle)
                    }
                }
            }
        }
        
        sectionIndexTitles.sort()
        sectionTitles.sort()
    }
    
    func updateData(_ notification: Notification) {
        if let userInfo = notification.userInfo as? [String: Any] {
            let defaults = defaultsValue()
            var setSectionName = defaults["setSectionName"] as! String
            var setSortBy = defaults["setSortBy"] as! String
            var setSecondSortBy = defaults["setSecondSortBy"] as! String
            var setOrderBy = defaults["setOrderBy"] as! Bool
            var setDisplayBy = defaults["setDisplayBy"] as! String
            
            if let value = userInfo["setSortBy"] as? String {
                setSortBy = value
                
                switch setSortBy {
                case "name":
                    setSectionName = "nameSection"
                    setSecondSortBy = "name"
                case "numberOrder":
                    setSectionName = "numberOrder"
                    setSecondSortBy = "name"
                case "typeSection":
                    setSectionName = "typeSection"
                    setSecondSortBy = "name"
                case "rarity_.name":
                    setSectionName = "rarity_.name"
                    setSecondSortBy = "name"
                case "artist_.name":
                    setSectionName = "artist_.name"
                    setSecondSortBy = "name"
                default:
                    ()
                }
            }
            
            if let value = userInfo["setOrderBy"] as? Bool {
                setOrderBy = value
            }
            
            if let value = userInfo["setDisplayBy"] as? String {
                setDisplayBy = value
            }
            
            UserDefaults.standard.set(setSectionName, forKey: "setSectionName")
            UserDefaults.standard.set(setSortBy, forKey: "setSortBy")
            UserDefaults.standard.set(setSecondSortBy, forKey: "setSecondSortBy")
            UserDefaults.standard.set(setOrderBy, forKey: "setOrderBy")
            UserDefaults.standard.set(setDisplayBy, forKey: "setDisplayBy")
            UserDefaults.standard.synchronize()
            
            updateDataDisplay()
        }
    }
    
    func defaultsValue() -> [String: Any] {
        var values = [String: Any]()
        
        if let value = UserDefaults.standard.value(forKey: "setSectionName") as? String {
            values["setSectionName"] = value
        } else {
            values["setSectionName"] = "nameSection"
        }
        
        if let value = UserDefaults.standard.value(forKey: "setSortBy") as? String {
            values["setSortBy"] = value
        } else {
            values["setSortBy"] = "name"
        }
        
        if let value = UserDefaults.standard.value(forKey: "setSecondSortBy") as? String {
            values["setSecondSortBy"] = value
        } else {
            values["setSecondSortBy"] = "name"
        }
        
        if let value = UserDefaults.standard.value(forKey: "setOrderBy") as? Bool {
            values["setOrderBy"] = value
        } else {
            values["setOrderBy"] = true
        }
        
        if let value = UserDefaults.standard.value(forKey: "setDisplayBy") as? String {
            values["setDisplayBy"] = value
        } else {
            values["setDisplayBy"] = "list"
        }
        
        return values
    }
    
    func wikiURL(ofSet set: CMSet) -> URL? {
        var path = ""
        
        if let name = set.name,
            let code = set.code {
            
            if code == "LEA" {
                path = "Alpha"
            } else if code == "LEB" {
                path = "Beta"
            } else {
                path = name.replacingOccurrences(of: " and ", with: " & ")
                       .replacingOccurrences(of: " ", with: "_")
            }
        }
        
        return URL(string: "https://mtg.gamepedia.com/\(path)")
    }
    
    func doSearch() {
        var newRequest:NSFetchRequest<NSFetchRequestResult>?
        let defaults = defaultsValue()
        
        if let setSectionName = defaults["setSectionName"] as? String,
            let setSecondSortBy = defaults["setSecondSortBy"] as? String,
            let setOrderBy = defaults["setOrderBy"] as? Bool,
            let searchDisplayBy = defaults["setDisplayBy"] as? String {
        
            if let text = searchController.searchBar.text {
                if text.count > 0 {
                    newRequest = NSFetchRequest(entityName: "CMCard")
                    
                    newRequest!.sortDescriptors = [NSSortDescriptor(key: setSectionName, ascending: setOrderBy),
                                                   NSSortDescriptor(key: setSecondSortBy, ascending: setOrderBy)]
                    
                    if text.count == 1 {
                        newRequest!.predicate = NSPredicate(format: "set.code = %@ AND name BEGINSWITH[cd] %@", set!.code!, text)
                    } else if text.count > 1 {
                        newRequest!.predicate = NSPredicate(format: "set.code = %@ AND (name CONTAINS[cd] %@ OR name CONTAINS[cd] %@)", set!.code!, text, text)
                    }
                    dataSource = getDataSource(newRequest)
                    
                } else {
                    dataSource = getDataSource(nil)
                }
            }
        
            updateSections()
            switch searchDisplayBy {
            case "list":
                tableView.reloadData()
            case "grid":
                collectionView?.reloadData()
            default:
                ()
            }
        }
    }
}

// MARK: UITableViewDataSource
extension SetViewController : UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let rows = 1
        
        return rows
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let defaults = defaultsValue()
        let setDisplayBy = defaults["setDisplayBy"] as! String
        var cell: UITableViewCell?
        
        switch contentSegmentedControl.selectedSegmentIndex {
        case SetViewControllerSegmentedIndex.cards.rawValue:
            switch setDisplayBy {
            case "grid":
                if let c = tableView.dequeueReusableCell(withIdentifier: "GridCell") {
                    if let collectionView = c.viewWithTag(100) as? UICollectionView {
                        self.collectionView = collectionView
                        collectionView.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: "Header")
                        collectionView.delegate = self
                        
                        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                            let width = tableView.frame.size.width
                            let height = tableView.frame.size.height - kCardTableViewCellHeight - CGFloat(44)
                            
                            flowLayout.itemSize = cardSize(inFrame: CGSize(width: width, height: height))
                            flowLayout.minimumInteritemSpacing = CGFloat(0)
                            flowLayout.minimumLineSpacing = CGFloat(10)
                            flowLayout.headerReferenceSize = CGSize(width: width, height: 22)
                            flowLayout.sectionHeadersPinToVisibleBounds = true
                        }
                    }
                    cell = c
                }
            default:
                ()
            }
        case SetViewControllerSegmentedIndex.wiki.rawValue:
            if let c = tableView.dequeueReusableCell(withIdentifier: "SetInfoCell") as? BrowserTableViewCell,
                let set = set {
                c.webView.delegate = self
                let request = URLRequest(url: wikiURL(ofSet: set)!, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 10.0)
                c.webView.loadRequest(request)
                cell = c
            }
        default:
            ()
        }
        
        return cell!
    }
}

// MARK: UITableViewDelegate
extension SetViewController : UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let defaults = defaultsValue()
        let setDisplayBy = defaults["setDisplayBy"] as! String
        var height = CGFloat(0)

        switch contentSegmentedControl.selectedSegmentIndex {
        case SetViewControllerSegmentedIndex.cards.rawValue:
            switch setDisplayBy {
            case "list":
                height = kCardTableViewCellHeight
            case "grid":
                height = tableView.frame.size.height
            default:
                ()
            }
        case SetViewControllerSegmentedIndex.wiki.rawValue:
            height = tableView.frame.size.height
        default:
            ()
        }
        
        return height
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch contentSegmentedControl.selectedSegmentIndex {
        case SetViewControllerSegmentedIndex.cards.rawValue:
            let card = dataSource!.object(indexPath)
            let cards = dataSource!.all()
            let cardIndex = cards.index(of: card!)
            let identifier = UIDevice.current.userInterfaceIdiom == .phone ? "showCard" : "showCardModal"
            let sender = ["cardIndex": cardIndex as Any,
                          "cards": cards]
            performSegue(withIdentifier: identifier, sender: sender)
        default:
            ()
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let defaults = defaultsValue()
        let setDisplayBy = defaults["setDisplayBy"] as! String

        switch contentSegmentedControl.selectedSegmentIndex {
        case SetViewControllerSegmentedIndex.cards.rawValue:
            switch setDisplayBy {
            case "grid":
                dataSource = getDataSource(nil)
                updateSections()
            default:
                ()
            }
        default:
            ()
        }
    }
}

// MARK: DATASourceDelegate
extension SetViewController : DATASourceDelegate {
    // return list of section titles to display in section index view (e.g. "ABCD...Z#")
    func sectionIndexTitlesForDataSource(_ dataSource: DATASource, tableView: UITableView) -> [String] {
        return sectionIndexTitles
    }
    
    // tell table which section corresponds to section title/index (e.g. "B",1))
    func dataSource(_ dataSource: DATASource, tableView: UITableView, sectionForSectionIndexTitle title: String, atIndex index: Int) -> Int {
        let defaults = defaultsValue()
        let setOrderBy = defaults["setOrderBy"] as! Bool
        var sectionIndex = 0
        
        for i in 0...sectionTitles.count - 1 {
            if sectionTitles[i].hasPrefix(title) {
                if setOrderBy {
                    sectionIndex = i
                } else {
                    sectionIndex = (sectionTitles.count - 1) - i
                }
                break
            }
        }
        
        return sectionIndex
    }
    
    func dataSource(_ dataSource: DATASource, collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: IndexPath, withTitle title: Any?) -> UICollectionReusableView? {
        var v: UICollectionReusableView?
        
        if kind == UICollectionElementKindSectionHeader {
            v = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionElementKindSectionHeader, withReuseIdentifier:"Header", for: indexPath)
            v!.backgroundColor = UIColor(red: 247/255, green: 247/255, blue: 247/255, alpha: 1)
            
            if v!.subviews.count == 0 {
                let label = UILabel(frame: CGRect(x: 20, y: 0, width: collectionView.frame.size.width - 20, height: 22))
                label.tag = 100
                v!.addSubview(label)
            }
            
            if let lab = v!.viewWithTag(100) as? UILabel {
                let defaults = defaultsValue()
                let setOrderBy = defaults["setOrderBy"] as! Bool
                var sectionTitle: String?
                
                if setOrderBy {
                    sectionTitle = sectionTitles[indexPath.section]
                } else {
                    sectionTitle = sectionTitles[sectionTitles.count - 1 - indexPath.section]
                }
                
                lab.text = sectionTitle
            }
        }
        
        return v
    }
}

// UICollectionViewDelegate
extension SetViewController : UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let card = dataSource!.object(indexPath)
        let cards = dataSource!.all()
        let cardIndex = cards.index(of: card!)
        let identifier = UIDevice.current.userInterfaceIdiom == .phone ? "showCard" : "showCardModal"
        let sender = ["cardIndex": cardIndex as Any,
                      "cards": cards]
        
        performSegue(withIdentifier: identifier, sender: sender)
    }
}

// MARK: UIWebViewDelegate
extension SetViewController : UIWebViewDelegate {
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        
        var willLoad = false
        if let url = request.url {
            if let host = url.host {
                if host.contains("gamepedia.com") {
                    willLoad = true
                } else if host.contains("magiccards.info") ||
                    host.contains("scryfall.com") {
                    // Show the card instead opening the link!!!
                    let urlComponents = URLComponents(string: url.absoluteString)
                    let queryItems = urlComponents?.queryItems
                    let q = queryItems?.filter({$0.name == "q"}).first
                    if let value = q?.value {
                        let r = value.index(value.startIndex, offsetBy: 1)
                        let cardName = value.substring(from: r).replacingOccurrences(of: "+", with: " ")
                                       .replacingOccurrences(of: "\"", with: "")
                        
                        let request:NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CMCard")
                        request.predicate = NSPredicate(format: "name = %@", cardName)
                        request.sortDescriptors = [NSSortDescriptor(key: "nameSection", ascending: true),
                                                    NSSortDescriptor(key: "name", ascending: true)]
                        
                        let results = try! ManaKit.sharedInstance.dataStack!.mainContext.fetch(request)
                        if results.count == 1 {
                            if let card = results.first as? CMCard {
                                if UIDevice.current.userInterfaceIdiom == .phone {
                                    performSegue(withIdentifier: "showCard", sender: ["cardIndex": 0 as Any,
                                                                                      "cards": [card]])
                                } else if UIDevice.current.userInterfaceIdiom == .pad {
                                    performSegue(withIdentifier: "showCardModal", sender: ["cardIndex": 0 as Any,
                                                                                           "cards": [card]])
                                }
                            }
                        } else if results.count > 1 {
                            performSegue(withIdentifier: "showSearch", sender: request)
                        } else {
                            let alertVC = UIAlertController(title: "Card Not found", message: "The card: \(cardName) was not found in the database", preferredStyle: .alert)
                            let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
                            alertVC.addAction(okAction)
                            present(alertVC, animated: true, completion: nil)
                        }
                    }
                }
            }
        }
        
        return willLoad
    }
    
    func webViewDidStartLoad(_ webView: UIWebView) {
        MBProgressHUD.showAdded(to: webView, animated: true)
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        MBProgressHUD.hide(for: webView, animated: true)
        
        if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? BrowserTableViewCell {
            cell.backButton.isEnabled = webView.canGoBack
            cell.forwardButton.isEnabled = webView.canGoForward
            cell.refreshButton.isEnabled = true
        }
    }
    
    func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        MBProgressHUD.hide(for: webView, animated: true)
        
        if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? BrowserTableViewCell {
            cell.backButton.isEnabled = webView.canGoBack
            cell.forwardButton.isEnabled = webView.canGoForward
            cell.refreshButton.isEnabled = true
        }
        
        var html = "<html><body><center>"
        html.append(error.localizedDescription)
        html.append("</center></body></html>")
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: UISearchResultsUpdating
extension SetViewController : UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(doSearch), object: nil)
        perform(#selector(doSearch), with: nil, afterDelay: 0.5)
    }
}

