//
//  AnnouncementsController.swift
//  Mulu Party
//
//  Created by Grant Brooks Goodman on 21/12/2020.
//  Copyright © 2013-2020 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import MessageUI
import UIKit

class AnnouncementsController: UIViewController, MFMailComposeViewControllerDelegate
{
    //==================================================//
    
    /* Interface Builder UI Elements */
    
    @IBOutlet weak var textView: UITextView!
    
    //==================================================//
    
    /* Class-level Variable Declarations */
    
    var buildInstance: Build!
    
    //==================================================//
    
    /* Initialiser Function */
    
    func initialiseController()
    {
        lastInitialisedController = self
        buildInstance = Build(self)
    }
    
    //==================================================//
    
    /* Overridden Functions */
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        initialiseController()
        
        view.setBackground(withImageNamed: "Gradient.png")
        
        let titleAttributes: [NSAttributedString.Key: Any] = [.font: UIFont(name: "Gotham-Black", size: 19)!]
        let suibtitleAttributes: [NSAttributedString.Key: Any] = [.font: UIFont(name: "Montserrat-SemiBold", size: 18)!]
        
        let schedule = NSMutableAttributedString(string: "SCHEDULE\n\n", attributes: titleAttributes)
        let scheduleSubtitle = NSAttributedString(string: "– THURSDAY 1/7 12PM PT\n– THURSDAY 1/14 12PM PT\n– THURSDAY 1/21 12PM PT\n– THURSDAY 1/28 12PM PT\n\n", attributes: suibtitleAttributes)
        
        let howItWorks = NSAttributedString(string: "HOW IT WORKS\n\n", attributes: titleAttributes)
        let howItWorksSubtitle = NSAttributedString(string: "– INSERT HOW IT WORKS\n– INSERT HOW IT WORKS\n– INSERT HOW IT WORKS\n\nQUESTIONS?\nHELLO@GETMULU.COM", attributes: suibtitleAttributes)
        
        schedule.append(scheduleSubtitle)
        schedule.append(howItWorks)
        schedule.append(howItWorksSubtitle)
        
        textView.attributedText = schedule
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        currentFile = #file
        buildInfoController?.view.isHidden = false
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        
    }
    
    //==================================================//
    
    /* Interface Builder Actions */
    
    //==================================================//
    
    /* Other Functions */
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?)
    {
        buildInstance.handleMailComposition(withController: controller, withResult: result, withError: error)
    }
}
