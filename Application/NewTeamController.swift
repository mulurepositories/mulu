//
//  NewTeamController.swift
//  Mulu Party
//
//  Created by Grant Brooks Goodman on 30/12/2020.
//  Copyright © 2013-2020 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import MessageUI
import UIKit

/* Third-party Frameworks */
import FirebaseAuth

class NewTeamController: UIViewController, MFMailComposeViewControllerDelegate
{
    //==================================================//

    /* MARK: Interface Builder UI Elements */

    //UIBarButtonItems
    @IBOutlet var backButton:   UIBarButtonItem!
    @IBOutlet var cancelButton: UIBarButtonItem!
    @IBOutlet var nextButton:   UIBarButtonItem!

    //UILabels
    @IBOutlet var promptLabel: UILabel!
    @IBOutlet var titleLabel:  UILabel!

    //Other Elements
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var largeTextField: UITextField!
    @IBOutlet var progressView: UIProgressView!
    @IBOutlet var stepTextView: UITextView!
    @IBOutlet var tableView: UITableView!

    //==================================================//

    /* MARK: Class-level Variable Declarations */

    //Arrays
    var selectedUsers =      [String]()
    var userArray:           [User]?
    var tournamentArray:     [Tournament]?

    //Booleans
    var isGoingBack = false
    var isWorking   = false

    //Strings
    var teamName:           String?
    var selectedTournament: String?
    var stepText = "🔴 Set name\n🔴 Add users\n🔴 Add to a tournament"

    //Other Declarations
    var buildInstance: Build!
    var controllerReference: CreateController!
    var currentStep = Step.name
    var stepAttributes: [NSAttributedString.Key: Any]!

    //==================================================//

    /* MARK: Enumerated Type Declarations */

    enum Step
    {
        case name
        case users
        case tournament
    }

    //==================================================//

    /* MARK: Initializer Function */

    func initializeController()
    {
        lastInitializedController = self
        buildInstance = Build(self)
    }

    //==================================================//

    /* MARK: Overridden Functions */

    override func viewDidLoad()
    {
        super.viewDidLoad()

        navigationController?.presentationController?.delegate = self

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 8

        stepAttributes = [.font: UIFont(name: "SFUIText-Medium", size: 11)!,
                          .paragraphStyle: paragraphStyle]

        stepTextView.attributedText = NSAttributedString(string: stepText, attributes: stepAttributes)

        let navigationButtonAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 17)]

        backButton.setTitleTextAttributes(navigationButtonAttributes, for: .normal)
        backButton.setTitleTextAttributes(navigationButtonAttributes, for: .highlighted)
        backButton.setTitleTextAttributes(navigationButtonAttributes, for: .disabled)

        nextButton.setTitleTextAttributes(navigationButtonAttributes, for: .normal)
        nextButton.setTitleTextAttributes(navigationButtonAttributes, for: .highlighted)
        nextButton.setTitleTextAttributes(navigationButtonAttributes, for: .disabled)

        largeTextField.delegate = self
        tableView.backgroundColor = .black

        forwardToName()
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)

        initializeController()

        currentFile = #file
        buildInfoController?.view.isHidden = true
    }

    override func prepare(for _: UIStoryboardSegue, sender _: Any?)
    {}

    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)

        lastInitializedController = controllerReference
        buildInstance = Build(controllerReference)
        buildInfoController?.view.isHidden = !preReleaseApplication
    }

    //==================================================//

    /* MARK: Interface Builder Actions */

    @IBAction func backButton(_: Any)
    {
        switch currentStep
        {
        case .users:
            goBack()
            forwardToName()
        case .tournament:
            goBack()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { self.forwardToUsers() }
        default:
            goBack()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { self.forwardToTournament() }
        }
    }

    @IBAction func cancelButton(_: Any)
    {
        confirmCancellation()
    }

    @IBAction func nextButton(_: Any)
    {
        nextButton.isEnabled = false
        backButton.isEnabled = false

        switch currentStep
        {
        case .name:
            if largeTextField.text!.lowercasedTrimmingWhitespace != ""
            {
                teamName = largeTextField.text!
                forwardToUsers()
            }
            else
            {
                AlertKit().errorAlertController(title:                       "Nothing Entered",
                                                message:                     "No text was entered. Please try again.",
                                                dismissButtonTitle:          "OK",
                                                additionalSelectors:         nil,
                                                preferredAdditionalSelector: nil,
                                                canFileReport:               false,
                                                extraInfo:                   nil,
                                                metadata:                    [#file, #function, #line],
                                                networkDependent:            false)
                nextButton.isEnabled = true
            }
        case .users:
            if selectedUsers.isEmpty
            {
                AlertKit().errorAlertController(title: "Add Users",
                                                message: "You must add at least one user to this team.",
                                                dismissButtonTitle: "OK",
                                                additionalSelectors: nil,
                                                preferredAdditionalSelector: nil,
                                                canFileReport: false,
                                                extraInfo: nil,
                                                metadata: [#file, #function, #line],
                                                networkDependent: true) {
                    self.backButton.isEnabled = true
                    self.nextButton.isEnabled = true
                }
            }
            else { forwardToTournament() }
        default:
            forwardToFinish()
        }
    }

    //==================================================//

    /* MARK: Other Functions */

    func deselectAllCells()
    {
        for cell in tableView.visibleCells
        {
            if let cell = cell as? SelectionCell
            {
                cell.radioButton.isSelected = false
            }
        }
    }

    func animateTournamentTableViewAppearance()
    {
        deselectAllCells()

        tableView.dataSource = self
        tableView.delegate   = self
        tableView.reloadData()

        tableView.layer.cornerRadius = 10

        UIView.animate(withDuration: 0.2) {
            self.tableView.alpha = 0.6
            self.promptLabel.alpha = 1
        } completion: { _ in
            self.nextButton.isEnabled = true
            self.backButton.isEnabled = true
        }

        nextButton.title = "Finish"
    }

    func animateUserTableViewAppearance()
    {
        UIView.animate(withDuration: 0.2) { self.largeTextField.alpha = 0 } completion: { _ in
            self.deselectAllCells()

            self.tableView.dataSource = self
            self.tableView.delegate   = self
            self.tableView.reloadData()

            self.tableView.layer.cornerRadius = 10

            UIView.animate(withDuration: 0.2) {
                self.tableView.alpha = 0.6
                self.promptLabel.alpha = 1
            } completion: { _ in
                self.nextButton.isEnabled = true
                self.backButton.isEnabled = true
            }
        }

        nextButton.title = "Next"
    }

    func confirmCancellation()
    {
        AlertKit().confirmationAlertController(title:                   "Are You Sure?",
                                               message:                 "Would you really like to cancel?",
                                               cancelConfirmTitles:     ["cancel": "No", "confirm": "Yes"],
                                               confirmationDestructive: true,
                                               confirmationPreferred:   false,
                                               networkDepedent:         false) { didConfirm in
            if didConfirm!
            {
                self.navigationController?.dismiss(animated: true, completion: nil)
            }
        }
    }

    func createTeam()
    {
        guard let teamName = teamName else
        { report("Team name was not set!", errorCode: nil, isFatal: true, metadata: [#file, #function, #line]); return }

        var selectedUserDictionary = [String: Int]()

        for user in selectedUsers
        {
            selectedUserDictionary[user] = 0
        }

        TeamSerializer().createTeam(name: teamName, participantIdentifiers: selectedUserDictionary) { returnedMetadata, errorDescriptor in
            if let metadata = returnedMetadata
            {
                if let tournament = self.selectedTournament
                {
                    TeamSerializer().addTeam(metadata.identifier, toTournament: tournament) { errorDescriptor in
                        if let error = errorDescriptor
                        {
                            AlertKit().errorAlertController(title: "Succeeded with Errors",
                                                            message: "The team was created, but couldn't be added to the specified tournament. File a report for more information.",
                                                            dismissButtonTitle: nil,
                                                            additionalSelectors: nil,
                                                            preferredAdditionalSelector: nil,
                                                            canFileReport: true,
                                                            extraInfo: error,
                                                            metadata: [#file, #function, #line],
                                                            networkDependent: true) {
                                self.navigationController?.dismiss(animated: true, completion: nil)
                            }
                        }
                        else
                        {
                            AlertKit().optionAlertController(title: "Successfully Created Team",
                                                             message: "\(teamName) was successfully created. Its join code is:\n\n«\(metadata.joinCode)»",
                                                             cancelButtonTitle: "Dismiss",
                                                             additionalButtons: nil,
                                                             preferredActionIndex: nil,
                                                             networkDependent: false) { _ in
                                self.navigationController?.dismiss(animated: true, completion: nil)
                            }
                        }
                    }
                }
                else
                {
                    AlertKit().optionAlertController(title: "Successfully Created Team",
                                                     message: "\(teamName) was successfully created. Its join code is:\n\n«\(metadata.joinCode)»",
                                                     cancelButtonTitle: "Dismiss",
                                                     additionalButtons: nil,
                                                     preferredActionIndex: nil,
                                                     networkDependent: false) { _ in
                        self.navigationController?.dismiss(animated: true, completion: nil)
                    }
                }
            }
            else
            {
                AlertKit().errorAlertController(title: "Couldn't Create Team",
                                                message: errorDescriptor!,
                                                dismissButtonTitle: nil,
                                                additionalSelectors: nil,
                                                preferredAdditionalSelector: nil,
                                                canFileReport: true,
                                                extraInfo: errorDescriptor!,
                                                metadata: [#file, #function, #line],
                                                networkDependent: true) {
                    self.navigationController?.dismiss(animated: true, completion: nil)
                }
            }
        }
    }

    func forwardToName()
    {
        findAndResignFirstResponder()
        largeTextField.autocapitalizationType = .words
        largeTextField.keyboardType           = .default
        largeTextField.textContentType        = .name

        if isGoingBack
        {
            stepProgress(forwardDirection: false)
            isGoingBack = false
        }

        stepText = "🟡 Set name\n🔴 Add users\n🔴 Add to a tournament"
        UIView.transition(with: stepTextView, duration: 0.35, options: .transitionCrossDissolve, animations: {
            self.stepTextView.attributedText = NSAttributedString(string: self.stepText, attributes: self.stepAttributes)
        })

        UIView.transition(with: largeTextField, duration: 0.35, options: .transitionCrossDissolve) {
            self.largeTextField.placeholder = "Enter a name for the team"
            self.largeTextField.text = self.teamName ?? nil
        } completion: { _ in
            UIView.animate(withDuration: 0.2) { self.largeTextField.alpha = 1 } completion: { _ in
                self.largeTextField.becomeFirstResponder()

                self.nextButton.isEnabled = true
            }
        }

        currentStep = .name
    }

    func forwardToUsers()
    {
        findAndResignFirstResponder()
        stepProgress(forwardDirection: !isGoingBack)

        isGoingBack = false

        stepText = "🟢 Set name\n🟡 Add users\n🔴 Add to a tournament"
        UIView.transition(with: stepTextView, duration: 0.35, options: .transitionCrossDissolve, animations: {
            self.stepTextView.attributedText = NSAttributedString(string: self.stepText, attributes: self.stepAttributes)
        })

        promptLabel.textAlignment = .left
        promptLabel.text = "SELECT USERS TO ADD TO THIS TEAM:"

        currentStep = .users

        if userArray != nil
        {
            animateUserTableViewAppearance()
        }
        else
        {
            UserSerializer().getAllUsers { returnedUsers, errorDescriptor in
                if let users = returnedUsers
                {
                    self.userArray = users.sorted(by: { $0.firstName < $1.firstName })

                    self.animateUserTableViewAppearance()
                }
                else if let error = errorDescriptor
                {
                    report(error, errorCode: nil, isFatal: true, metadata: [#file, #function, #line])
                }
            }
        }
    }

    func forwardToTournament()
    {
        findAndResignFirstResponder()
        stepProgress(forwardDirection: !isGoingBack)

        isGoingBack = false

        stepText = "🟢 Set name\n🟢 Add users\n🟡 Add to a tournament"
        UIView.transition(with: stepTextView, duration: 0.35, options: .transitionCrossDissolve, animations: {
            self.stepTextView.attributedText = NSAttributedString(string: self.stepText, attributes: self.stepAttributes)
        })

        UIView.animate(withDuration: 0.2) {
            self.promptLabel.alpha = 0
            self.tableView.alpha   = 0
        } completion: { _ in
            self.promptLabel.textAlignment = .left
            self.promptLabel.text          = "SELECT A TOURNAMENT TO ADD THIS TEAM TO:"

            self.currentStep = .tournament

            if self.tournamentArray != nil
            {
                self.animateTournamentTableViewAppearance()
            }
            else
            {
                TournamentSerializer().getAllTournaments { returnedTournaments, errorDescriptor in
                    if let tournaments = returnedTournaments
                    {
                        self.tournamentArray = tournaments.sorted(by: { $0.name < $1.name })

                        self.animateTournamentTableViewAppearance()
                    }
                    else if let error = errorDescriptor
                    {
                        report(error, errorCode: nil, isFatal: true, metadata: [#file, #function, #line])
                    }
                }
            }
        }
    }

    func forwardToFinish()
    {
        nextButton.isEnabled = false
        backButton.isEnabled = false
        cancelButton.isEnabled = false

        stepProgress(forwardDirection: true)

        stepText = "🟢 Set name\n🟢 Add users\n🟢 Add to a tournament"
        UIView.transition(with: stepTextView, duration: 0.35, options: .transitionCrossDissolve, animations: {
            self.stepTextView.attributedText = NSAttributedString(string: self.stepText, attributes: self.stepAttributes)
        })

        UIView.animate(withDuration: 0.2) {
            self.tableView.alpha = 0
            self.promptLabel.alpha = 0
        } completion: { _ in
            self.promptLabel.textAlignment = .center
            self.promptLabel.text = "WORKING..."
            self.isWorking = true

            UIView.animate(withDuration: 0.2, delay: 0.5) {
                self.promptLabel.alpha = 1
                self.activityIndicator.alpha = 1
            } completion: { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(2500)) { self.createTeam() }
            }
        }
    }

    func goBack()
    {
        isWorking = false
        isGoingBack = true

        nextButton.isEnabled = false
        backButton.isEnabled = false

        UIView.animate(withDuration: 0.2) {
            for subview in self.view.subviews
            {
                if subview.tag != aTagFor("titleLabel") && subview.tag != aTagFor("progressView") && subview.tag != aTagFor("stepTextView")
                {
                    subview.alpha = 0
                }
            }
        }
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?)
    {
        buildInstance.handleMailComposition(withController: controller, withResult: result, withError: error)
    }

    func stepProgress(forwardDirection: Bool)
    {
        UIView.animate(withDuration: 0.2) { self.progressView.setProgress(self.progressView.progress + (forwardDirection ? 1 / 3 : -(1 / 3)), animated: true) }
    }
}

//==================================================//

/* MARK: Extensions */

/**/

/* MARK: UIAdaptivePresentationControllerDelegate */
extension NewTeamController: UIAdaptivePresentationControllerDelegate
{
    func presentationControllerDidAttemptToDismiss(_: UIPresentationController)
    {
        if !isWorking
        {
            confirmCancellation()
        }
    }

    func presentationControllerShouldDismiss(_: UIPresentationController) -> Bool
    {
        return false
    }
}

//--------------------------------------------------//

/* MARK: UITableViewDataSource, UITableViewDelegate */
extension NewTeamController: UITableViewDataSource, UITableViewDelegate
{
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let currentCell = tableView.dequeueReusableCell(withIdentifier: "SelectionCell") as! SelectionCell

        if currentStep == .users
        {
            currentCell.titleLabel.text = "\(userArray![indexPath.row].firstName!) \(userArray![indexPath.row].lastName!)"

            if let teams = userArray![indexPath.row].associatedTeams
            {
                currentCell.subtitleLabel.text = "on \(teams.count) team\(teams.count == 1 ? "" : "s")"
            }
            else { currentCell.subtitleLabel.text = "on 0 teams" }

            if selectedUsers.contains(userArray![indexPath.row].associatedIdentifier)
            {
                currentCell.radioButton.isSelected = true
            }
        }
        else
        {
            currentCell.titleLabel.text = tournamentArray![indexPath.row].name!
            currentCell.subtitleLabel.text = "\(tournamentArray![indexPath.row].teamIdentifiers.count) teams"

            if selectedTournament == tournamentArray![indexPath.row].associatedIdentifier
            {
                currentCell.radioButton.isSelected = true
            }

            currentCell.tag = indexPath.row
        }

        currentCell.selectionStyle = .none

        return currentCell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        if let currentCell = tableView.cellForRow(at: indexPath) as? SelectionCell
        {
            if currentStep == .users
            {
                if currentCell.radioButton.isSelected,
                   let index = selectedUsers.firstIndex(of: userArray![indexPath.row].associatedIdentifier)
                {
                    selectedUsers.remove(at: index)
                }
                else if !currentCell.radioButton.isSelected
                {
                    selectedUsers.append(userArray![indexPath.row].associatedIdentifier)
                }

                currentCell.radioButton.isSelected = !currentCell.radioButton.isSelected
            }
            else
            {
                if currentCell.radioButton.isSelected,
                   let tournament = selectedTournament,
                   tournament == tournamentArray![indexPath.row].associatedIdentifier
                {
                    selectedTournament = nil
                    currentCell.radioButton.isSelected = false
                }
                else if !currentCell.radioButton.isSelected
                {
                    selectedTournament = tournamentArray![indexPath.row].associatedIdentifier
                    currentCell.radioButton.isSelected = true
                }

                for cell in tableView.visibleCells
                {
                    if let cell = cell as? SelectionCell, cell.tag != indexPath.row
                    {
                        cell.radioButton.isSelected = false
                    }
                }
            }
        }
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int
    {
        if currentStep == .users
        {
            return userArray!.count
        }

        return tournamentArray!.count
    }
}

//--------------------------------------------------//

/* MARK: UITextFieldDelegate */
extension NewTeamController: UITextFieldDelegate
{
    func textFieldShouldReturn(_: UITextField) -> Bool
    {
        nextButton(nextButton!)
        return true
    }
}
