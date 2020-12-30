//
//  TournamentSerialiser.swift
//  Mulu Party
//
//  Created by Grant Brooks Goodman on 14/12/2020.
//  Copyright © 2013-2020 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import UIKit

/* Third-party Frameworks */
import FirebaseDatabase

class TournamentSerialiser
{
    //==================================================//
    
    /* MARK: Public Functions */
    
    /**
     Creates a **Tournament** on the server.
     
     - Parameter name: The name of this **Tournament.**
     - Parameter startDate: The **Tournament's** start date.
     - Parameter endDate: The **Tournament's** end date.
     - Parameter teamIdentifiers: An array containing the identifiers of the **Teams** participating in this **Tournament.**
     
     - Parameter completion: Upon success, returns with the identifier of the newly created **Tournament.** Upon failure, a string describing the error encountered.
     
     - Note: Completion variables are *mutually exclusive.*
     
     ~~~
     completion(returnedIdentifier, errorDescriptor)
     ~~~
     */
    func createTournament(name: String,
                          startDate: Date,
                          endDate: Date,
                          teamIdentifiers: [String],
                          completion: @escaping(_ returnedIdentifier: String?, _ errorDescriptor: String?) -> Void)
    {
        var dataBundle: [String:Any] = [:]
        
        dataBundle["name"] = name
        dataBundle["startDate"] = secondaryDateFormatter.string(from: startDate)
        dataBundle["endDate"] = secondaryDateFormatter.string(from: endDate)
        dataBundle["teamIdentifiers"] = teamIdentifiers.unique()
        
        //Generate a key for the new Challenge.
        if let generatedKey = Database.database().reference().child("/allTournaments/").childByAutoId().key
        {
            GenericSerialiser().updateValue(onKey: "/allTournaments/\(generatedKey)", withData: dataBundle) { (returnedError) in
                if let error = returnedError
                {
                    completion(nil, errorInfo(error))
                }
                else
                {
                    TeamSerialiser().addTeams(teamIdentifiers.unique(), toTournament: generatedKey) { (errorDescriptor) in
                        if let error = errorDescriptor
                        {
                            completion(nil, error)
                        }
                        else { completion(generatedKey, nil) }
                    }
                }
            }
        }
        else { completion(nil, "Unable to create key in database.") }
    }
    
    /**
     Gets and deserialises a **Tournament** from a given identifier string.
     
     - Parameter withIdentifier: The identifier of the requested **Tournament.**
     - Parameter completion: Upon success, returns a deserialised **Tournament** object. Upon failure, a string describing the error encountered.
     
     - Note: Completion variables are *mutually exclusive.*
     
     ~~~
     completion(returnedTournament, errorDescriptor)
     ~~~
     */
    func getTournament(withIdentifier: String, completion: @escaping(_ returnedTournament: Tournament?, _ errorDescriptor: String?) -> Void)
    {
        Database.database().reference().child("allTournaments").child(withIdentifier).observeSingleEvent(of: .value, with: { (returnedSnapshot) in
            if let returnedSnapshotAsDictionary = returnedSnapshot.value as? NSDictionary, let asDataBundle = returnedSnapshotAsDictionary as? [String:Any]
            {
                var mutableDataBundle = asDataBundle
                
                mutableDataBundle["associatedIdentifier"] = withIdentifier
                
                self.deSerialiseTournament(from: mutableDataBundle) { (returnedTournament, errorDescriptor) in
                    if let tournament = returnedTournament
                    {
                        completion(tournament, nil)
                    }
                    else { completion(nil, errorDescriptor!) }
                }
            }
            else { completion(nil, "No Tournament exists with the identifier \"\(withIdentifier)\".") }
        })
        { (returnedError) in
            
            completion(nil, "Unable to retrieve the specified data. (\(returnedError.localizedDescription))")
        }
    }
    
    /**
     Gets and deserialises multiple **Tournament** objects from a given array of identifier strings.
     
     - Parameter withIdentifiers: The identifiers to query for.
     - Parameter completion: Upon success, returns an array of deserialised **Tournament** objects. Upon failure, an array of strings describing the error(s) encountered.
     
     - Note: Completion variables are *mutually exclusive.*
     
     ~~~
     completion(returnedTournaments, errorDescriptors)
     ~~~
     */
    func getTournaments(withIdentifiers: [String], completion: @escaping(_ returnedTournaments: [Tournament]?, _ errorDescriptors: [String]?) -> Void)
    {
        var tournamentArray: [Tournament]! = []
        var errorDescriptorArray: [String]! = []
        
        if withIdentifiers.count > 0
        {
            let dispatchGroup = DispatchGroup()
            
            for individualIdentifier in withIdentifiers
            {
                if verboseFunctionExposure { print("entered group") }
                dispatchGroup.enter()
                
                getTournament(withIdentifier: individualIdentifier) { (returnedTournament, errorDescriptor) in
                    if let tournament = returnedTournament
                    {
                        tournamentArray.append(tournament)
                        
                        if verboseFunctionExposure { print("left group") }
                        dispatchGroup.leave()
                    }
                    else
                    {
                        errorDescriptorArray.append(errorDescriptor!)
                        
                        if verboseFunctionExposure { print("left group") }
                        dispatchGroup.leave()
                    }
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                if tournamentArray.count + errorDescriptorArray.count == withIdentifiers.count
                {
                    completion(tournamentArray.count == 0 ? nil : tournamentArray, errorDescriptorArray.count == 0 ? nil : errorDescriptorArray)
                }
            }
        }
        else
        {
            completion(nil, ["No identifiers passed!"])
        }
    }
    
    //==================================================//
    
    /* MARK: Private Functions */
    
    /**
     Deserialises a **Tournament** from a given data bundle.
     
     - Parameter from: The data bundle from which to deserialise the **Tournament.**
     - Parameter completion: Upon success, returns a deserialised **Tournament** object. Upon failure, a string describing the error encountered.
     
     - Note: Completion variables are *mutually exclusive.*
     - Requires: A well-formed bundle of **Tournament** metadata.
     
     ~~~
     completion(deSerialisedTournament, errorDescriptor)
     ~~~
     */
    private func deSerialiseTournament(from dataBundle: [String:Any], completion: @escaping(_ deSerialisedTournament: Tournament?, _ errorDescriptor: String?) -> Void)
    {
        guard let associatedIdentifier = dataBundle["associatedIdentifier"] as? String else
        { completion(nil, "Unable to deserialise «associatedIdentifier»."); return }
        
        guard let name = dataBundle["name"] as? String else
        { completion(nil, "Unable to deserialise «name»."); return }
        
        guard let startDateString = dataBundle["startDate"] as? String,
              let startDate = secondaryDateFormatter.date(from: startDateString) else
        { completion(nil, "Unable to deserialise «startDate»."); return }
        
        guard let endDateString = dataBundle["endDate"] as? String,
              let endDate = secondaryDateFormatter.date(from: endDateString) else
        { completion(nil, "Unable to deserialise «endDate»."); return }
        
        guard let teamIdentifiers = dataBundle["teamIdentifiers"] as? [String] else
        { completion(nil, "Unable to deserialise «teamIdentifiers»."); return }
        
        let deSerialisedTournament = Tournament(associatedIdentifier: associatedIdentifier,
                                                name:                 name,
                                                startDate:            startDate,
                                                endDate:              endDate,
                                                teamIdentifiers:      teamIdentifiers)
        
        completion(deSerialisedTournament, nil)
    }
}
