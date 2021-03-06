//
//  ViewController.swift
//  MusicLimit
//
//  Created by Bryan Mazariegos on 9/30/17.
//  Copyright © 2017 ICBM. All rights reserved.
//  Set a timer where music is selected to fit the alloted time within +/- 15s. Uses a slider in the middle to select time. Shows songs in tableview that are in queue. Shows time saved in comparison to last shower. Should have a 3-5 second delay before starting.

import UIKit
import QuartzCore
import AVFoundation

var selectedPlaylist = -1
var choiceNames = [String]()
var VCref:ViewController!

class ViewController: UIViewController, SPTCoreAudioControllerDelegate, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet var loginButton:UIButton!
    @IBOutlet var timerLengthSlider:UISlider!
    @IBOutlet var playButton:UIButton!
    @IBOutlet var minutesRemainingLabel:UILabel!
    @IBOutlet var unitLabel:UILabel!
    @IBOutlet var songTableView:UITableView!
    @IBOutlet var sourceSelect:UIButton!
    @IBOutlet var songTableHeight:NSLayoutConstraint!
    
    var colorLibraryR2W:[CGFloat] = [0.016,0.032,0.064,0.08,0.096,0.112,0.128,0.144,0.16,0.176,0.192,0.208,0.224,0.24,0.256,0.272,0.288,0.304,0.32,0.336,0.352,0.368,0.384,0.4,0.416,0.432,0.448,0.464,0.48,0.496,0.512,0.528,0.544,0.56,0.576,0.592,0.608,0.624,0.64,0.656,0.672,0.688,0.704,0.72,0.736,0.752,0.768,0.784,0.8,0.816,0.832,0.848,0.864,0.88,0.896,0.912,0.928,0.944,0.976,0.992]
    var auth = SPTAuth.defaultInstance()!
    var session:SPTSession!
    var player: SPTAudioStreamingController?
    var loginUrl: URL?
    var usersPlaylist:SPTPlaylistList?
    var itemUrls = [String]()
    var itemsLength = [Double]()
    var timer:Timer!
    var timeRemaining:Double = 0
    var timerTicks = 0
    var songHolder = [SPTPlaylistTrack]()
    var removeTimer = false
    var allowedToGoNext = false
    var lastSliderValue = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setUp()
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.updateAfterFirstLogin), name: Notification.Name(rawValue: "loginSuccessfull"), object: nil)
        VCref = self
        self.updateSourceTitle()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    func updateSourceTitle() {
        print("Playlist: \(selectedPlaylist)")
        if selectedPlaylist == -1 {
            sourceSelect.setTitle("Source: All Playlists", for: .normal)
            sourceSelect.setTitle("Source: All Playlists", for: .highlighted)
        } else {
            sourceSelect.setTitle("Source: \(choiceNames[selectedPlaylist])", for: .normal)
            sourceSelect.setTitle("Source: \(choiceNames[selectedPlaylist])", for: .highlighted)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setUp() {
        auth.clientID = "07e2571edcaa4e619e271a2de33043de"
        auth.redirectURL = URL(string: "MusicLimit://returnAfterLogin")
        auth.requestedScopes = [SPTAuthStreamingScope,SPTAuthUserLibraryReadScope,SPTAuthPlaylistReadPrivateScope,SPTAuthPlaylistReadCollaborativeScope]
        auth.tokenRefreshURL = URL(string: "MusicLimit://returnAfterLogin")
        loginUrl = auth.spotifyWebAuthenticationURL()
    }
    
    @objc func updateAfterFirstLogin () {
        print("Ye 1")
        if let sessionObj:AnyObject = userDefaults.object(forKey: "SpotifySession") as AnyObject? {
            let sessionDataObj = sessionObj as! Data
            let firstTimeSession = NSKeyedUnarchiver.unarchiveObject(with: sessionDataObj) as! SPTSession
            self.session = firstTimeSession
            initializePlayer(authSession: session)
        }
    }
    
    func initializePlayer(authSession:SPTSession) {
        if self.player == nil {
            print("Ye 2")
            self.player = SPTAudioStreamingController.sharedInstance()
            self.player!.playbackDelegate = self
            self.player!.delegate = self
            do {
                try self.player!.start(withClientId: auth.clientID)
            } catch {
                print("Failed to start with clientId")
            }
            
            self.player!.login(withAccessToken: authSession.accessToken)
            UIView.animate(withDuration: 1.5, animations: {
                self.songTableHeight.constant = 190
                self.updateViewConstraints()
            })
            self.findSongs()
        }
    }
    
    @IBAction func login(_ sender:UIButton) {
        if player == nil {
            UIApplication.shared.open(loginUrl!, options: [:], completionHandler: { _ in
                if self.auth.canHandle(self.auth.redirectURL) {
                    
                }
            })
        } else {
            print("Should be good 2 go")
        }
    }
    
    @IBAction func reselectSongs() {
        itemsLength = [Double]()
        itemUrls = [String]()
        songHolder = [SPTPlaylistTrack]()
        findSongs()
    }
    
    @IBAction func updateTimerLength() {
        minutesRemainingLabel.text = "\(Int(timerLengthSlider.value))"
        let position = Int(timerLengthSlider.value.rounded()) - 1
        let color = UIColor(red: 1, green: colorLibraryR2W[59 - position], blue: colorLibraryR2W[59 - position], alpha: 1)
        timerLengthSlider.thumbTintColor = color
        timerLengthSlider.minimumTrackTintColor = color
        minutesRemainingLabel.textColor = color
        unitLabel.textColor = color
    }
    
    func startPlayingSongs() {
        // after a user authenticates a session, the SPTAudioStreamingController is then initialized and this method called
        if self.player!.loggedIn && self.itemUrls.count > 0 {
            lastSliderValue = Int(timerLengthSlider.value)
            print(self.itemUrls.count)
            timeRemaining = durationOfItems(itemsLength)/60
            self.player!.playSpotifyURI(self.itemUrls[0], startingWith: 0, startingWithPosition: 0, callback: { (error) in
                if (error != nil) {
                    print("\(error!)")
                }
            })
            self.timerLengthSlider.value += 1
            self.timeRemaining = durationOfItems(itemsLength)
            
            if self.timeRemaining >= 1 {
                self.timerLengthSlider.isUserInteractionEnabled = false
                self.timerLengthSlider.value -= Float(CGFloat(self.timerLengthSlider.value)/CGFloat(self.timeRemaining))
                self.timeRemaining -= 1
                let seconds = Int(self.timeRemaining.truncatingRemainder(dividingBy: 60).rounded() - 1)
                if seconds < 10 {
                    self.minutesRemainingLabel.text = "\(Int(self.timeRemaining/60)):0\(seconds)"
                } else {
                    self.minutesRemainingLabel.text = "\(Int(self.timeRemaining/60)):\(seconds)"
                }
            }
            
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
                if !self.removeTimer {
                    self.timerLengthSlider.isUserInteractionEnabled = false
                    self.timerLengthSlider.value -= Float(CGFloat(self.timerLengthSlider.value)/CGFloat(self.timeRemaining))
                    
                    let seconds = Int(self.timeRemaining.truncatingRemainder(dividingBy: 60).rounded() - 1)
                    if seconds < 10 {
                        self.minutesRemainingLabel.text = "\(Int(self.timeRemaining/60)):0\(seconds)"
                    } else {
                        self.minutesRemainingLabel.text = "\(Int(self.timeRemaining/60)):\(seconds)"
                    }
                    self.timeRemaining -= 1
                    
                    if Int(self.timeRemaining.rounded()) % 5 == 0 {
                        DispatchQueue.main.async {
                            self.songTableView.reloadData()
                        }
                    }
                    
                    if self.timeRemaining == 0 {
                        self.removeTimer = true
                    }
                    
                    print(self.player!.playbackState.position)
                    
                    if self.allowedToGoNext && self.player!.playbackState.position == 0.0 {
                        if self.itemUrls.count > 0 {
                            print("Should be going to next song")
                            self.itemUrls.remove(at: 0)
                            self.itemsLength.remove(at: 0)
                            self.songHolder.remove(at: 0)
                            self.playNext()
                        } else {
                            print("No songs next, we're done here!")
                            if self.timer != nil {
                                self.removeTimer = false
                                if self.timer.isValid {
                                    self.timer.invalidate()
                                }
                                self.timer = nil
                                self.reselectSongs()
                                self.timerLengthSlider.value = Float(self.lastSliderValue)
                                self.minutesRemainingLabel.text = "\(self.lastSliderValue)"
                                self.timerLengthSlider.isUserInteractionEnabled = true
                                self.player!.setIsPlaying(false, callback: {_ in
                                    
                                })
                            }
                            self.playButton.setImage(UIImage(named: "playIcon"), for: .normal)
                        }
                        self.allowedToGoNext = false
                    } else {
                        self.allowedToGoNext = true
                    }
                } else {
                    self.removeTimer = false
                    self.timer.invalidate()
                    self.timerLengthSlider.value = Float(self.lastSliderValue)
                    self.minutesRemainingLabel.text = "\(self.lastSliderValue)"
                    self.timerLengthSlider.isUserInteractionEnabled = true
                    self.timer = nil
                }
            })
        }
    }
    
    func playNext() {
        self.player!.setIsPlaying(false, callback: {_ in
            
        })
        
        if self.itemUrls.count > 0 {
            self.player!.playSpotifyURI(self.itemUrls[0], startingWith: 0, startingWithPosition: 0, callback: { (error) in
                if (error != nil) {
                    print("\(error!)")
                }
            })
        }
    }
    
    @IBAction func playSongs() {
        if timer != nil {
            self.removeTimer = false
            if timer.isValid {
                self.timer.invalidate()
            }
            self.timer = nil
            self.reselectSongs()
            self.timerLengthSlider.value = Float(self.lastSliderValue)
            self.minutesRemainingLabel.text = "\(self.lastSliderValue)"
            self.timerLengthSlider.isUserInteractionEnabled = true
            self.player!.setIsPlaying(false, callback: {_ in
                
            })
            self.playButton.setImage(UIImage(named: "playIcon"), for: .normal)
        } else {
            self.startPlayingSongs()
            self.playButton.setImage(UIImage(named: "pauseIcon"), for: .normal)
        }
    }
    
    func findSongs() {
        itemsLength = [Double]()
        itemUrls = [String]()
        songHolder = [SPTPlaylistTrack]()
        SPTPlaylistList.playlists(forUser: auth.session.canonicalUsername, withAccessToken: auth.session.accessToken, callback: { (error, playlist) in
            if playlist != nil {
                self.usersPlaylist = playlist as? SPTPlaylistList
                if selectedPlaylist == -1 && self.usersPlaylist!.items != nil {
                    var usedX_Nums = [Int]()
                    while usedX_Nums.count < self.usersPlaylist!.items.count {
                        let rand = Int(arc4random_uniform(UInt32(self.usersPlaylist!.items.count)))
                        if !usedX_Nums.contains(rand) {
                            usedX_Nums.append(rand)
                            let pp = self.usersPlaylist!.items[rand] as! SPTPartialPlaylist
                            print(pp.name)
                            print(pp.trackCount)
                            SPTPlaylistSnapshot.playlist(withURI: pp.uri, accessToken: self.auth.session.accessToken, callback: { (error,snap) in
                                if let snapShot = snap as? SPTPlaylistSnapshot {
                                    if snapShot.firstTrackPage != nil {
                                        if snapShot.firstTrackPage.items != nil {
                                            var usedY_Nums = [Int]()
                                            while usedY_Nums.count < snapShot.firstTrackPage.items.count {
                                                let randY = Int(arc4random_uniform(UInt32(snapShot.firstTrackPage.items.count)))
                                                if !usedY_Nums.contains(randY) {
                                                    usedY_Nums.append(randY)
                                                    if let currTrack = snapShot.firstTrackPage.items[randY] as? SPTPlaylistTrack {
                                                        if self.durationOfItems(self.itemsLength) + currTrack.duration < Double(Int(self.timerLengthSlider.value) * 60) + 15 && (!self.songHolder.contains(currTrack) || self.songHolder.count == 0) && currTrack.playableUri != nil {
                                                            self.songHolder.append(currTrack)
                                                            self.itemsLength.append(currTrack.duration)
                                                            self.itemUrls.append(currTrack.playableUri.absoluteString)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        /*
                                         snapShot.firstTrackPage.requestNextPage(withAccessToken: self.auth.session.accessToken, callback: { (error,snap2) in
                                         if let snapShot2 = snap2 as? SPTPlaylistSnapshot {
                                         if snapShot2.firstTrackPage != nil {
                                         if snapShot2.firstTrackPage.items != nil {
                                         var y = 0
                                         while y < snapShot2.firstTrackPage.items.count {
                                         if let currTrack = snapShot2.firstTrackPage.items[y] as? SPTPlaylistTrack {
                                         if self.durationOfItems(self.itemsLength) + currTrack.duration < Double(Int(self.timerLengthSlider.value) * 60) + 15 && (!self.songHolder.contains(currTrack) || self.songHolder.count == 0) {
                                         self.songHolder.append(currTrack)
                                         self.itemsLength.append(currTrack.duration)
                                         self.itemUrls.append(currTrack.playableUri.absoluteString)
                                         }
                                         }
                                         y += 1
                                         }
                                         }
                                         }
                                         }
                                         })
                                         */
                                    }
                                }
                            })
                        }
                    }
                } else if self.usersPlaylist!.items != nil {
                    let pp = self.usersPlaylist!.items[selectedPlaylist] as! SPTPartialPlaylist
                    print(pp.name)
                    print(pp.trackCount)
                    SPTPlaylistSnapshot.playlist(withURI: pp.uri, accessToken: self.auth.session.accessToken, callback: { (error,snap) in
                        if let snapShot = snap as? SPTPlaylistSnapshot {
                            if snapShot.firstTrackPage != nil {
                                if snapShot.firstTrackPage.items != nil {
                                    var usedY_Nums = [Int]()
                                    while usedY_Nums.count < snapShot.firstTrackPage.items.count {
                                        let randY = Int(arc4random_uniform(UInt32(snapShot.firstTrackPage.items.count)))
                                        if !usedY_Nums.contains(randY) {
                                            usedY_Nums.append(randY)
                                            if let currTrack = snapShot.firstTrackPage.items[randY] as? SPTPlaylistTrack {
                                                if self.durationOfItems(self.itemsLength) + currTrack.duration < Double(Int(self.timerLengthSlider.value) * 60) + 15 && (!self.songHolder.contains(currTrack) || self.songHolder.count == 0) && currTrack.playableUri != nil {
                                                    self.songHolder.append(currTrack)
                                                    self.itemsLength.append(currTrack.duration)
                                                    self.itemUrls.append(currTrack.playableUri.absoluteString)
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                /*
                                 snapShot.firstTrackPage.requestNextPage(withAccessToken: self.auth.session.accessToken, callback: { (error,snap2) in
                                 if let snapShot2 = snap2 as? SPTPlaylistSnapshot {
                                 if snapShot2.firstTrackPage != nil {
                                 if snapShot2.firstTrackPage.items != nil {
                                 var y = 0
                                 while y < snapShot2.firstTrackPage.items.count {
                                 if let currTrack = snapShot2.firstTrackPage.items[y] as? SPTPlaylistTrack {
                                 if self.durationOfItems(self.itemsLength) + currTrack.duration < Double(Int(self.timerLengthSlider.value) * 60) + 15 && (!self.songHolder.contains(currTrack) || self.songHolder.count == 0) {
                                 self.songHolder.append(currTrack)
                                 self.itemsLength.append(currTrack.duration)
                                 self.itemUrls.append(currTrack.playableUri.absoluteString)
                                 }
                                 }
                                 y += 1
                                 }
                                 }
                                 }
                                 }
                                 })
                                 */
                            }
                        }
                    })
                }
                
                if self.durationOfItems(self.itemsLength) < Double(Int(self.timerLengthSlider.value) * 60 - 30) || self.durationOfItems(self.itemsLength) > Double(Int(self.timerLengthSlider.value) * 60 + 15)  {
                    self.findSongs()
                    print("Songs were repicked")
                } else {
                    DispatchQueue.main.async {
                        self.songTableView.reloadData()
                    }
                }
                print("Chosen song combo duration: \(self.durationOfItems(self.itemsLength))")
            }
        })
    }
    
    func durationOfItems(_ items:[Double]) -> Double {
        var totalDuration:Double = 0
        
        var x = 0
        while x < items.count {
            totalDuration += Double(items[x])
            x += 1
        }
        
        return totalDuration
    }
    
    @IBAction func selectSource() {
        choiceNames = [String]()
        var x = 0
        while x < self.usersPlaylist!.items.count {
            choiceNames.append((self.usersPlaylist!.items[x] as! SPTPartialPlaylist).name)
            x += 1
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songHolder.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.songTableView.dequeueReusableCell(withIdentifier: "musicCell") as! MusicCell
        if indexPath.row < songHolder.count {
            do {
                let imgData = try Data(contentsOf: songHolder[indexPath.row].album.smallestCover.imageURL)
                cell.trackThumbnail.image = UIImage(data: imgData)
                cell.trackThumbnail.layer.cornerRadius = cell.trackThumbnail.image!.size.width/2
                cell.trackThumbnail.clipsToBounds = true
            } catch {
                
            }
            cell.trackInfo.text = songHolder[indexPath.row].name + " - " + (songHolder[indexPath.row].artists as! [SPTPartialArtist])[0].name
        }
            
        return cell
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}

extension ViewController: SPTAudioStreamingDelegate, SPTAudioStreamingPlaybackDelegate {
    func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController!) {
        loginButton.isHidden = true
        unitLabel.isHidden = false
        sourceSelect.isHidden = false
        minutesRemainingLabel.isHidden = false
        timerLengthSlider.isHidden = false
        playButton.isHidden = false
        print("logged in")
        
    }
    
    func audioStreamingDidEncounterTemporaryConnectionError(_ audioStreaming: SPTAudioStreamingController!) {
        print("Oh no...")
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didChangePlaybackStatus isPlaying: Bool) {
        if isPlaying {
            self.activateAudioSession()
        } else {
            self.deactivateAudioSession()
        }
    }
    
    func activateAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    // MARK: Deactivate audio session
    
    func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

