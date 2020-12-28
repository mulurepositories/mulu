//
//  PostSignUpController.swift
//  Mulu Party
//
//  Created by Grant Brooks Goodman on 18/12/2020.
//  Copyright © 2013-2020 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import MessageUI
import UIKit

/* Third-party Frameworks */
import FirebaseAnalytics
import PKHUD

class PostSignUpController: UIViewController, MFMailComposeViewControllerDelegate
{
    //==================================================//
    
    /* Interface Builder UI Elements */
    
    //UIButtons
    @IBOutlet weak var contactUsButton:         UIButton!
    @IBOutlet weak var goButton:                UIButton!
    @IBOutlet weak var inviteYourFriendsButton: UIButton!
    
    //Other Elements
    @IBOutlet weak var teamCodeTextField: UITextField!
    
    //==================================================//
    
    /* Class-level Variable Declarations */
    
    var buildInstance: Build!
    var userIdentifier: String?
    
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
        
        contactUsButton.layer.cornerRadius = 5
        inviteYourFriendsButton.layer.cornerRadius = 5
        
        for view in view.subviews
        {
            view.alpha = 0
        }
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        currentFile = #file
        buildInfoController?.view.isHidden = false
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        teamCodeTextField.addGreyUnderline()
        
        UIView.animate(withDuration: 0.15) {
            for view in self.view.subviews
            {
                view.alpha = 1
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        
    }
    
    //==================================================//
    
    /* Interface Builder Actions */
    
    @IBAction func goButton(_ sender: Any)
    {
        teamCodeTextField.resignFirstResponder()
        
        guard teamCodeTextField.text!.trimmingBorderedWhitespace.components(separatedBy: " ").count == 2 else
        {
            let message = "Join codes consist of 2 words. Please try again."
            
            AlertKit().errorAlertController(title:                       "Invalid Code",
                                            message:                     message,
                                            dismissButtonTitle:          "OK",
                                            additionalSelectors:         nil,
                                            preferredAdditionalSelector: nil,
                                            canFileReport:               false,
                                            extraInfo:                   nil,
                                            metadata:                    [#file, #function, #line],
                                            networkDependent:            false)
            
            report(message, errorCode: nil, isFatal: false, metadata: [#file, #function, #line]); return
        }
        
        guard let userIdentifier = userIdentifier else
        {
            AlertKit().errorAlertController(title:                       nil,
                                            message:                     nil,
                                            dismissButtonTitle:          "OK",
                                            additionalSelectors:         nil,
                                            preferredAdditionalSelector: nil,
                                            canFileReport:               false,
                                            extraInfo:                   nil,
                                            metadata:                    [#file, #function, #line],
                                            networkDependent:            false)
            
            report("No User identifier passed!", errorCode: nil, isFatal: false, metadata: [#file, #function, #line]); return
        }
        
        TeamSerialiser().getTeam(byJoinCode: teamCodeTextField.text!.trimmingBorderedWhitespace) { (returnedIdentifier, errorDescriptor) in
            if let identifier = returnedIdentifier
            {
                TeamSerialiser().addUser(userIdentifier, toTeam: identifier) { (errorDescriptor) in
                    if let error = errorDescriptor
                    {
                        AlertKit().errorAlertController(title:                       "Couldn't Add To Team",
                                                        message:                     error,
                                                        dismissButtonTitle:          "OK",
                                                        additionalSelectors:         nil,
                                                        preferredAdditionalSelector: nil,
                                                        canFileReport:               false,
                                                        extraInfo:                   nil,
                                                        metadata:                    [#file, #function, #line],
                                                        networkDependent:            false)
                        
                        report(error, errorCode: nil, isFatal: false, metadata: [#file, #function, #line])
                    }
                    else
                    {
                        HUD.flash(.success, delay: 1) { (_) in
                            self.performSegue(withIdentifier: "SignInFromPostSignUpSegue", sender: self)
                        }
                    }
                }
            }
            else if let error = errorDescriptor
            {
                AlertKit().errorAlertController(title:                       "Couldn't Find Team",
                                                message:                     error,
                                                dismissButtonTitle:          "OK",
                                                additionalSelectors:         nil,
                                                preferredAdditionalSelector: nil,
                                                canFileReport:               false,
                                                extraInfo:                   nil,
                                                metadata:                    [#file, #function, #line],
                                                networkDependent:            false)
                
                report(error, errorCode: nil, isFatal: false, metadata: [#file, #function, #line])
            }
        }
    }
    
    @IBAction func contactUsButton(_ sender: Any)
    {
        Analytics.logEvent("contact_us", parameters: nil)
        
        let url = URL(string: "mailto:hello@getmulu.com")!
        
        UIApplication.shared.open(url, options: [:]) { _ in }
    }
    
    @IBAction func inviteYourFriendsButton(_ sender: Any)
    {
        Analytics.logEvent("invite_your_friends", parameters: nil)
    }
    
    @IBAction func linkButton(_ sender: Any)
    {
        guard let button = sender as? UIButton else
        { report("Invalid link sender.", errorCode: nil, isFatal: false, metadata: [#file, #function, #line]); return }
        
        if button.titleLabel!.text == "www.getmulu.com"
        {
            let url = URL(string: "https://www.getmulu.com/")!
            
            UIApplication.shared.open(url, options: [:]) { _ in }
        }
        else
        {
            AlertKit().optionAlertController(title:                "Visit us on...",
                                             message:              "",
                                             cancelButtonTitle:    nil,
                                             additionalButtons:    [("Instagram", false), ("Twitter", false)],
                                             preferredActionIndex: nil,
                                             networkDependent:     true) { (selectedIndex) in
                if let index = selectedIndex, index != -1
                {
                    let urlString = index == 0 ? "https://www.instagram.com/mulufitness/" : "https://twitter.com/mulufitness"
                    let url = URL(string: urlString)!
                    
                    UIApplication.shared.open(url, options: [:]) { _ in }
                }
            }
        }
    }
    
    //==================================================//
    
    /* Other Functions */
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?)
    {
        buildInstance.handleMailComposition(withController: controller, withResult: result, withError: error)
    }
}
