
import UIKit
import MediaPlayer
import AVFoundation

class StationsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var stationNowPlayingButton: UIButton!
    @IBOutlet weak var nowPlayingAnimationImageView: UIImageView!
    
    var stations = [RadioStation]()
    var currentStation: RadioStation?
    var currentTrack: Track?
    var refreshControl: UIRefreshControl!
    var firstTime = true
    
    //*****************************************************************
    // MARK: - ViewDidLoad
    //*****************************************************************
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Register 'Nothing Found' cell xib
        let cellNib = UINib(nibName: "NothingFoundCell", bundle: nil)
        tableView.registerNib(cellNib, forCellReuseIdentifier: "NothingFound")
        
        preferredStatusBarStyle()
        
        // Load Data
        loadStationsFromJSON()
        
        // Setup TableView
        tableView.backgroundColor = UIColor.clearColor()
        tableView.backgroundView = nil
        tableView.separatorStyle = UITableViewCellSeparatorStyle.None
        
        // Setup Pull to Refresh
        setupPullToRefresh()
        
        // Create NowPlaying Animation
        createNowPlayingAnimation()
        
        // Set AVFoundation category, required for background audio
        var error: NSError?
        var success: Bool
        do {
            try AVAudioSession.sharedInstance().setCategory(
                AVAudioSessionCategoryPlayAndRecord,
                withOptions: .DefaultToSpeaker)
            success = true
        } catch let error1 as NSError {
            error = error1
            success = false
        }
        if !success {
            if DEBUG_LOG { print("Failed to set audio session category.  Error: \(error)") }
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        self.title = "Swift Radio"
        
        // If a station has been selected, create "Now Playing" button to get back to current station
        if !firstTime {
            createNowPlayingBarButton()
        }
        
        // If a track is playing, display title & artist information and animation
        if currentTrack != nil && currentTrack!.isPlaying {
            let title = currentStation!.stationName + ": " + currentTrack!.title + " - " + currentTrack!.artist + "..."
            stationNowPlayingButton.setTitle(title, forState: .Normal)
            nowPlayingAnimationImageView.startAnimating()
        } else {
            nowPlayingAnimationImageView.stopAnimating()
            nowPlayingAnimationImageView.image = UIImage(named: "NowPlayingBars")
        }
        
    }

    //*****************************************************************
    // MARK: - Setup UI Elements
    //*****************************************************************
    
    func setupPullToRefresh() {
        self.refreshControl = UIRefreshControl()
        self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        self.refreshControl.backgroundColor = UIColor.blackColor()
        self.refreshControl.tintColor = UIColor.whiteColor()
        self.refreshControl.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        self.tableView.addSubview(refreshControl)
    }
    
    func createNowPlayingAnimation() {
        nowPlayingAnimationImageView.animationImages = AnimationFrames.createFrames()
        nowPlayingAnimationImageView.animationDuration = 0.7
    }
    
    func createNowPlayingBarButton() {
        if self.navigationItem.rightBarButtonItem == nil {
            let btn = UIBarButtonItem(title: "", style: UIBarButtonItemStyle.Plain, target: self, action:"nowPlayingBarButtonPressed")
            btn.image = UIImage(named: "btn-nowPlaying")
            self.navigationItem.rightBarButtonItem = btn
        }
    }
    
    //*****************************************************************
    // MARK: - Actions
    //*****************************************************************
    
    func nowPlayingBarButtonPressed() {
        performSegueWithIdentifier("NowPlaying", sender: self)
    }
    
    @IBAction func nowPlayingPressed(sender: UIButton) {
        performSegueWithIdentifier("NowPlaying", sender: self)
    }
    
    func refresh(sender: AnyObject) {
        // Pull to Refresh
        stations.removeAll(keepCapacity: false)
        loadStationsFromJSON()
        
        // Wait 2 seconds then refresh screen
        let popTime = dispatch_time(DISPATCH_TIME_NOW, Int64(2 * Double(NSEC_PER_SEC)));
        dispatch_after(popTime, dispatch_get_main_queue()) { () -> Void in
            self.refreshControl.endRefreshing()
            self.view.setNeedsDisplay()
        }
    }
    
    //*****************************************************************
    // MARK: - Load Station Data
    //*****************************************************************
    
    func loadStationsFromJSON() {
        
        // Turn on network indicator in status bar
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        
        // Get the Radio Stations
        DataManager.getStationDataWithSuccess() { (data) in
            
            if DEBUG_LOG { print("Stations JSON Found") }
            
            let json = JSON(data: data)
            
            if let stationArray = json["station"].array {
                
                for stationJSON in stationArray {
                    let station = RadioStation.parseStation(stationJSON)
                    self.stations.append(station)
                }
                
                // stations array populated, update table on main queue
                dispatch_async(dispatch_get_main_queue()) {
                    self.tableView.reloadData()
                    self.view.setNeedsDisplay()
                }
                
            } else {
                if DEBUG_LOG { print("JSON Station Loading Error") }
            }
            
            // Turn off network indicator in status bar
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        }
    }
    
    //*****************************************************************
    // MARK: - Segue
    //*****************************************************************
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "NowPlaying" {
            
            self.title = ""
            firstTime = false
            
            let nowPlayingVC = segue.destinationViewController as! NowPlayingViewController
            nowPlayingVC.delegate = self
            
            if let indexPath = (sender as? NSIndexPath) {
                // User clicked on row, load/reset station
                currentStation = stations[indexPath.row]
                nowPlayingVC.currentStation = currentStation
                nowPlayingVC.newStation = true
            
            } else {
                // User clicked on a now playing button
                if let currentTrack = currentTrack {
                    // Return to NowPlaying controller without reloading station
                    nowPlayingVC.track = currentTrack
                    nowPlayingVC.currentStation = currentStation
                    nowPlayingVC.newStation = false
                } else {
                    // Issue with track, reload station
                    nowPlayingVC.currentStation = currentStation
                    nowPlayingVC.newStation = true
                }
            }
        }
    }
}

//*****************************************************************
// MARK: - TableViewDataSource
//*****************************************************************

extension StationsViewController: UITableViewDataSource {
    
    // MARK: - Table view data source
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 88
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if stations.count == 0 {
            return 1
        } else {
            return stations.count
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        if stations.isEmpty {
            let cell = tableView.dequeueReusableCellWithIdentifier("NothingFound", forIndexPath: indexPath) 
            cell.backgroundColor = UIColor.clearColor()
            cell.selectionStyle = UITableViewCellSelectionStyle.None
            return cell
            
        } else {
            let cell = tableView.dequeueReusableCellWithIdentifier("StationCell", forIndexPath: indexPath) as! StationTableViewCell
            
            // alternate background color
            if indexPath.row % 2 == 0 {
                cell.backgroundColor = UIColor.clearColor()
            } else {
                cell.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.2)
            }
            
            // Configure the cell...
            let station = stations[indexPath.row]
            cell.configureStationCell(station)
            
            return cell
        }
    }
}

//*****************************************************************
// MARK: - TableViewDelegate
//*****************************************************************

extension StationsViewController: UITableViewDelegate {
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        if !stations.isEmpty {
            
            // Set Now Playing Buttons
            let title = stations[indexPath.row].stationName + " - Now Playing..."
            stationNowPlayingButton.setTitle(title, forState: .Normal)
            stationNowPlayingButton.enabled = true
            
            performSegueWithIdentifier("NowPlaying", sender: indexPath)
        }
    }
}

//*****************************************************************
// MARK: - NowPlayingViewControllerDelegate
//*****************************************************************

extension StationsViewController: NowPlayingViewControllerDelegate {
    
    func artworkDidUpdate(track: Track) {
        currentTrack?.artworkURL = track.artworkURL
        currentTrack?.artworkImage = track.artworkImage
    }
    
    func songMetaDataDidUpdate(track: Track) {
        currentTrack = track
        let title = currentStation!.stationName + ": " + currentTrack!.title + " - " + currentTrack!.artist + "..."
        stationNowPlayingButton.setTitle(title, forState: .Normal)
    }
    
    func trackPlayingToggled(track: Track) {
        currentTrack?.isPlaying = track.isPlaying
    }

}
