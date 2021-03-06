//
//  TeamSerializer.swift
//  Mulu Party
//
//  Created by Grant Brooks Goodman on 06/12/2020.
//  Copyright © 2013-2020 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import UIKit

/* Third-party Frameworks */
import FirebaseDatabase

class TeamSerializer
{
    //==================================================//

    /* MARK: Adding Functions */

    /**
     Adds an array of completed **Challenges** to a **Team** on the server.

     - Parameter withBundle: The completed **Challenges** to add to or populate this **Team** with.
     - Parameter toTeam: The identifier of the **Team** to add these **Challenges** to.
     - Parameter overwrite: A Boolean describing whether to add these **Challenges** to the **Team** with or without overwriting the previous data.

     - Parameter completion: Upon failure, returns with a string describing the error(s) encountered.

     ~~~
     completion(errorDescriptor)
     ~~~
     */
    func addCompletedChallenges(_ withBundle: [(Challenge, [(User, Date)])], toTeam: String, overwrite: Bool, completion: @escaping (_ errorDescriptor: String?) -> Void)
    {
        let serializedChallenges = serializeCompletedChallenges(withBundle)

        let key = overwrite ? "/allTeams/\(toTeam)" : "/allTeams/\(toTeam)/completedChallenges"
        let data: [String: Any] = overwrite ? ["completedChallenges": serializedChallenges] : serializedChallenges

        GenericSerializer().updateValue(onKey: key, withData: data) { returnedError in
            if let error = returnedError
            {
                completion(errorInfo(error))
            }
            else { completion(nil) }
        }
    }

    /**
     Adds an array of **Users** to a **Team.**

     - Parameter users: The **Users** to add to this **Team.**
     - Parameter toTeam: The **Team** to add these **Users** to.

     - Parameter completion: Upon failure, returns with a string describing the error(s) encountered.

     ~~~
     completion(errorDescriptor)
     ~~~
     */
    func addUsers(_ users: [User], toTeam: Team, completion: @escaping (_ errorDescriptor: String?) -> Void)
    {
        let group = DispatchGroup()

        var errors = [String]()

        for user in users
        {
            group.enter()

            var newAssociatedTeams = user.associatedTeams ?? []
            newAssociatedTeams.append(toTeam.associatedIdentifier)

            GenericSerializer().updateValue(onKey: "/allUsers/\(user.associatedIdentifier!)", withData: ["associatedTeams": newAssociatedTeams]) { returnedError in
                if let error = returnedError
                {
                    errors.append(errorInfo(error))
                    group.leave()
                }
                else { group.leave() }
            }
        }

        group.notify(queue: .main) {
            var newParticipantIdentifiers = toTeam.participantIdentifiers!
            newParticipantIdentifiers = newParticipantIdentifiers.merge(with: users.instantiateIdentifierDictionary())

            GenericSerializer().updateValue(onKey: "/allTeams/\(toTeam.associatedIdentifier!)", withData: ["participantIdentifiers": newParticipantIdentifiers.delimitedArray()]) { returnedError in
                if let error = returnedError
                {
                    completion(!errors.isEmpty ? "\(errors.unique().joined(separator: "\n"))\n\(errorInfo(error))" : nil)
                }
                else
                { completion(!errors.isEmpty ? errors.unique().joined(separator: "\n") : nil) }
            }
        }
    }

    /**
     Adds an array of **Team** identifiers to a **Tournament** with a specified identifier.

     - Parameter withIdentifiers: The identifiers of the **Teams** to be added to this **Tournament.**
     - Parameter toTournament: The identifier of the **Tournament** to add these **Teams** to.

     - Parameter completion: Upon failure, returns with a string describing the error(s) encountered.

     ~~~
     completion(errorDescriptor)
     ~~~
     */
    func addTeams(_ withIdentifiers: [String], toTournament: String, completion: @escaping (_ errorDescriptor: String?) -> Void)
    {
        for (index, identifier) in withIdentifiers.enumerated()
        {
            addTeam(identifier, toTournament: toTournament) { errorDescriptor in
                if let error = errorDescriptor
                {
                    completion(error)
                }
                else
                {
                    if index == withIdentifiers.count - 1
                    {
                        completion(nil)
                    }
                }
            }
        }
    }

    /**
     Adds a **Team** with a specified identifier to a **Tournament** with a specified identifier.

     - Parameter withIdentifier: The identifier of the **Team** to add to this **Tournament.**
     - Parameter toTournament: The identifier of the **Tournament** to add this **Team** to.

     - Parameter completion: Upon failure, returns with a string describing the error(s) encountered.

     ~~~
     completion(errorDescriptor)
     ~~~
     */
    func addTeam(_ withIdentifier: String, toTournament: String, completion: @escaping (_ errorDescriptor: String?) -> Void)
    {
        let group = DispatchGroup()

        group.enter()

        var newAssociatedTournament: String?
        var newTeamIdentifiers: [String]?

        Database.database().reference().child("allTeams").child(withIdentifier).observeSingleEvent(of: .value, with: { returnedSnapshot in
            if let returnedSnapshotAsDictionary = returnedSnapshot.value as? NSDictionary,
               let asDataBundle =                 returnedSnapshotAsDictionary as? [String: Any]
            {
                var mutableDataBundle = asDataBundle
                mutableDataBundle["associatedIdentifier"] = withIdentifier

                guard self.validateTeamMetadata(mutableDataBundle) == true else
                { completion("Improperly formatted metadata."); return }

                let associatedTournament = mutableDataBundle["associatedTournament"] as! String

                if associatedTournament != "!"
                {
                    group.leave()

                    completion("The specified Team is already participating in a Tournament.")
                }
                else
                {
                    newAssociatedTournament = toTournament

                    group.leave()
                }
            }
        })
        { returnedError in
            group.leave()

            completion("Unable to retrieve the specified data. (\(returnedError.localizedDescription))")
        }

        group.notify(queue: .main) {
            guard newAssociatedTournament != nil else
            { completion("Couldn't get new associated Tournament."); return }

            group.enter()

            Database.database().reference().child("allTournaments").child(toTournament).observeSingleEvent(of: .value, with: { returnedSnapshot in
                if let returnedSnapshotAsDictionary = returnedSnapshot.value as? NSDictionary,
                   let asDataBundle =                 returnedSnapshotAsDictionary as? [String: Any]
                {
                    guard var teamIdentifiers = asDataBundle["teamIdentifiers"] as? [String] else
                    { completion("This Tournament has corrupted «teamIdentifiers»."); return }

                    teamIdentifiers = teamIdentifiers.filter { $0 != "!" }

                    teamIdentifiers.append(withIdentifier)
                    newTeamIdentifiers = teamIdentifiers

                    group.leave()
                }
            })
            { returnedError in
                group.leave()

                completion("Unable to retrieve the specified data. (\(returnedError.localizedDescription))")
            }

            group.notify(queue: .main) {
                guard let newAssociatedTournament = newAssociatedTournament else
                { completion("Couldn't get new associated Tournament."); return }

                guard let newTeamIdentifiers = newTeamIdentifiers?.unique() else
                { completion("Couldn't get new associated Teams."); return }

                //                guard newAssociatedTournaments.unique() == newAssociatedTournaments && newTeamIdentifiers.unique() == newTeamIdentifiers else
                //                { completion("This Team is already participating in that Tournament."); return }

                group.enter()

                GenericSerializer().updateValue(onKey: "/allTeams/\(withIdentifier)", withData: ["associatedTournament": newAssociatedTournament]) { returnedError in

                    if let error = returnedError
                    {
                        group.leave()

                        completion(errorInfo(error))
                    }
                    else
                    {
                        GenericSerializer().updateValue(onKey: "/allTournaments/\(toTournament)", withData: ["teamIdentifiers": newTeamIdentifiers]) { returnedError in
                            if let error = returnedError
                            {
                                group.leave()

                                completion(errorInfo(error))
                            }
                            else
                            {
                                group.leave()
                            }
                        }
                    }
                }

                group.notify(queue: .main) {
                    completion(nil)
                }
            }
        }
    }

    /**
     Adds a **User** to a **Team.**

     - Parameter withIdentifier: The identifier of the **User** to add to this **Team.**
     - Parameter toTeam: The identifier of the **Team** to add this **User** to.

     - Parameter completion: Upon failure, returns with a string describing the error(s) encountered.

     ~~~
     completion(errorDescriptor)
     ~~~
     */
    func addUser(_ withIdentifier: String, toTeam: String, completion: @escaping (_ errorDescriptor: String?) -> Void)
    {
        let group = DispatchGroup()

        group.enter()

        var newUserList: [String]?
        var newAssociatedTeams: [String]?

        Database.database().reference().child("allTeams").child(toTeam).observeSingleEvent(of: .value, with: { returnedSnapshot in
            if let returnedSnapshotAsDictionary = returnedSnapshot.value as? NSDictionary,
               let asDataBundle =                 returnedSnapshotAsDictionary as? [String: Any]
            {
                var mutableDataBundle = asDataBundle
                mutableDataBundle["associatedIdentifier"] = withIdentifier

                guard self.validateTeamMetadata(mutableDataBundle) == true else
                { completion("Improperly formatted metadata."); return }

                newUserList = (mutableDataBundle["participantIdentifiers"] as! [String])

                if newUserList! == ["! – 0"]
                {
                    newUserList = ["\(withIdentifier) – 0"]
                }
                else { newUserList!.append("\(withIdentifier) – 0") }

                group.leave()
            }
        })
        { returnedError in

            completion("Unable to retrieve the specified data. (\(returnedError.localizedDescription))")
        }

        group.notify(queue: .main) {
            guard newUserList != nil else
            { completion("Couldn't get new User list."); return }

            group.enter()

            Database.database().reference().child("allUsers").child(withIdentifier).observeSingleEvent(of: .value, with: { returnedSnapshot in
                if let returnedSnapshotAsDictionary = returnedSnapshot.value as? NSDictionary,
                   let asDataBundle =                 returnedSnapshotAsDictionary as? [String: Any]
                {
                    guard var associatedTeams = asDataBundle["associatedTeams"] as? [String] else
                    { completion("This user has corrupted «associatedTeams»."); return }

                    if associatedTeams == ["!"]
                    {
                        associatedTeams = [toTeam]
                    }
                    else { associatedTeams.append(toTeam) }

                    newAssociatedTeams = associatedTeams

                    group.leave()
                }
            })
            { returnedError in

                completion("Unable to retrieve the specified data. (\(returnedError.localizedDescription))")
            }

            group.notify(queue: .main) {
                guard let newUserList = newUserList?.unique() else
                { completion("Couldn't get new User list."); return }

                guard let newAssociatedTeams = newAssociatedTeams?.unique() else
                { completion("Couldn't get new associated Teams."); return }

                group.enter()

                GenericSerializer().updateValue(onKey: "/allTeams/\(toTeam)", withData: ["participantIdentifiers": newUserList]) { returnedError in
                    if let error = returnedError
                    {
                        group.leave()

                        completion(errorInfo(error))
                    }
                    else
                    {
                        GenericSerializer().updateValue(onKey: "/allUsers/\(withIdentifier)", withData: ["associatedTeams": newAssociatedTeams]) { returnedError in
                            if let error = returnedError
                            {
                                group.leave()

                                completion(errorInfo(error))
                            }
                            else
                            {
                                if verboseFunctionExposure { report("Successfully added User to Team.", errorCode: nil, isFatal: false, metadata: [#file, #function, #line]) }

                                group.leave()

                                completion(nil)
                            }
                        }
                    }
                }
            }
        }
    }

    /**
     Adds a **User** to multiple **Teams.**

     - Parameter withIdentifier: The identifier of the **User** to add to this **Team.**
     - Parameter toTeams: The array of **Team** identifiers to add this **User** to.

     - Parameter completion: Upon failure, returns with a string describing the error(s) encountered.

     ~~~
     completion(errorDescriptor)
     ~~~
     */
    func addUser(_ withIdentifier: String, toTeams: [String], completion: @escaping (_ errorDescriptor: String?) -> Void)
    {
        var errors = [String]()

        for (index, team) in toTeams.enumerated()
        {
            addUser(withIdentifier, toTeam: team) { errorDescriptor in
                if let error = errorDescriptor
                {
                    errors.append(error)

                    if index == toTeams.count - 1
                    {
                        completion(errors.unique().joined(separator: "\n"))
                    }
                }
                else
                {
                    if index == toTeams.count - 1
                    {
                        completion(errors.isEmpty ? nil : errors.unique().joined(separator: "\n"))
                    }
                }
            }
        }
    }

    //==================================================//

    /* MARK: Creation Functions */

    /**
     Creates a new **Team** on the server.

     - Parameter name: The name of this **Team.**
     - Parameter participantIdentifiers: A dictionary where the keys represent identifiers of the **Users** on this **Team,** and the values represent any additional points associated with that **User.**

     - Parameter completion: Upon success, returns with a tuple containing the identifier of the newly created **Team** and its join code. May also return with a string describing the error(s) encountered.

     - Note: Completion variables are **NOT** *mutually exclusive.*

     ~~~
     completion(returnedMetadata, errorDescriptor)
     ~~~
     */
    func createTeam(name: String, participantIdentifiers: [String: Int], completion: @escaping (_ returnedMetadata: (identifier: String, joinCode: String)?, _ errorDescriptor: String?) -> Void)
    {
        var dataBundle: [String: Any] = [:]

        dataBundle["associatedTournament"]   = "!"
        dataBundle["additionalPoints"]       = 0
        dataBundle["completedChallenges"]    = ["!": ["!"]]
        dataBundle["name"]                   = name
        dataBundle["participantIdentifiers"] = participantIdentifiers.delimitedArray()

        generateJoinCode { returnedCode, returnedError in
            if let code = returnedCode
            {
                dataBundle["joinCode"] = code

                //Generate a key for the new Team.
                if let generatedKey = Database.database().reference().child("/allTeams/").childByAutoId().key
                {
                    GenericSerializer().updateValue(onKey: "/allTeams/\(generatedKey)", withData: dataBundle) { returnedError in
                        if let error = returnedError
                        {
                            completion(nil, errorInfo(error))
                        }
                        else
                        {
                            var errors = [String]()

                            for (index, user) in Array(participantIdentifiers.keys).enumerated()
                            {
                                TeamSerializer().addUser(user, toTeam: generatedKey) { errorDescriptor in
                                    if let error = errorDescriptor
                                    {
                                        errors.append(error)

                                        if index == participantIdentifiers.count - 1
                                        {
                                            completion(nil, errors.unique().joined(separator: "\n"))
                                        }
                                    }
                                    else
                                    {
                                        if index == participantIdentifiers.count - 1
                                        {
                                            completion((generatedKey, code), errors.isEmpty ? nil : errors.unique().joined(separator: "\n"))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                else { completion(nil, "Unable to create key in database.") }
            }
            else { completion(nil, errorInfo(returnedError!)) }
        }
    }

    //==================================================//

    /* MARK: Getter Functions */

    /**
     Retrieves and deserializes all existing **Teams** on the server.

     - Parameter completion: Upon success, returns an array of deserialized **Team** objects. Upon failure, a string describing the error(s) encountered. May return both if only a select number of **Teams** could be deserialized.

     - Note: Completion variables are **NOT** *mutually exclusive.*

     ~~~
     completion(returnedTeams, errorDescriptor)
     ~~~
     */
    func getAllTeams(completion: @escaping (_ returnedTeams: [Team]?, _ errorDescriptor: String?) -> Void)
    {
        Database.database().reference().child("allTeams").observeSingleEvent(of: .value) { returnedSnapshot in
            if let returnedSnapshotAsDictionary = returnedSnapshot.value as? NSDictionary,
               let teamIdentifiers = returnedSnapshotAsDictionary.allKeys as? [String]
            {
                self.getTeams(withIdentifiers: teamIdentifiers) { returnedTeams, errorDescriptors in
                    if let teams = returnedTeams
                    {
                        completion(teams, errorDescriptors == nil ? nil : errorDescriptors!.joined(separator: "\n"))
                    }
                    else
                    { completion(nil, errorDescriptors == nil ? "An unknown error occurred." : errorDescriptors!.joined(separator: "\n")) }
                }
            }
            else { completion(nil, "Unable to deserialize snapshot.") }
        }
    }

    /**
     Gets random **Team** identifiers from the server.

     - Parameter amountToGet: An optional integer specifying the amount of random **Team** identifiers to get. *Defaults to all.*
     - Parameter completion: Upon success, returns an array of **Team** identifier strings. May also return a string describing an event or error encountered.

     - Note: Completion variables are **NOT** *mutually exclusive.*

     ~~~
     completion(returnedIdentifiers, noticeDescriptor)
     ~~~
     */
    func getRandomTeams(amountToGet: Int?, completion: @escaping (_ returnedIdentifiers: [String]?, _ noticeDescriptor: String?) -> Void)
    {
        Database.database().reference().child("allTeams").observeSingleEvent(of: .value) { returnedSnapshot in
            if let returnedSnapshotAsDictionary = returnedSnapshot.value as? NSDictionary,
               let teamIdentifiers = returnedSnapshotAsDictionary.allKeys as? [String]
            {
                if amountToGet == nil
                {
                    completion(teamIdentifiers.shuffledValue, nil)
                }
                else
                {
                    if amountToGet! > teamIdentifiers.count
                    {
                        completion(teamIdentifiers.shuffledValue, "Requested amount was larger than database size.")
                    }
                    else if amountToGet! == teamIdentifiers.count
                    {
                        completion(teamIdentifiers.shuffledValue, nil)
                    }
                    else if amountToGet! < teamIdentifiers.count
                    {
                        completion(Array(teamIdentifiers.shuffledValue[0 ... amountToGet!]), nil)
                    }
                }
            }
            else { completion(nil, "Unable to deserialize snapshot.") }
        }
    }

    /**
     Finds the **Team** with the specified join code.

     - Parameter byJoinCode: The join code of the **Team** to get.
     - Parameter completion: Upon success, returns with the identifier of the **Team** with the corresponding join code. Upon failure, a string describing the error(s) encountered.

     - Note: Completion variables are *mutually exclusive.*

     ~~~
     completion(returnedIdentifier, errorDescriptor)
     ~~~
     */
    func getTeam(byJoinCode: String, completion: @escaping (_ returnedIdentifier: String?, _ errorDescriptor: String?) -> Void)
    {
        Database.database().reference().child("allTeams").observeSingleEvent(of: .value) { returnedSnapshot in
            if let returnedSnapshotAsDictionary = returnedSnapshot.value as? NSDictionary,
               let asDataBundle = returnedSnapshotAsDictionary as? [String: Any]
            {
                for (index, identifier) in Array(asDataBundle.keys).enumerated()
                {
                    if let data = asDataBundle[identifier] as? [String: Any],
                       let joinCode = data["joinCode"] as? String
                    {
                        if joinCode == byJoinCode
                        {
                            completion(identifier, nil)
                            break
                        }
                    }

                    if index == asDataBundle.keys.count - 1
                    {
                        completion(nil, "No Team exists with join code \(byJoinCode).")
                    }
                }
            }
            else { completion(nil, "Unable to deserialize snapshot.") }
        }
    }

    /**
     Gets and deserializes a **Team** from a given identifier string.

     - Parameter withIdentifier: The identifier of the requested **Team.**
     - Parameter completion: Upon success, returns a deserialized **Team** object. Upon failure, a string describing the error(s) encountered.

     - Note: Completion variables are *mutually exclusive.*

     ~~~
     completion(returnedTeam, errorDescriptor)
     ~~~
     */
    func getTeam(withIdentifier: String, completion: @escaping (_ returnedTeam: Team?, _ errorDescriptor: String?) -> Void)
    {
        if verboseFunctionExposure { print("getting team") }

        Database.database().reference().child("allTeams").child(withIdentifier).observeSingleEvent(of: .value, with: { returnedSnapshot in
            if let returnedSnapshotAsDictionary = returnedSnapshot.value as? NSDictionary, let asDataBundle = returnedSnapshotAsDictionary as? [String: Any]
            {
                if verboseFunctionExposure { print("returned snapshot") }

                var mutableDataBundle = asDataBundle

                mutableDataBundle["associatedIdentifier"] = withIdentifier

                self.deSerializeTeam(from: mutableDataBundle) { returnedTeam, errorDescriptor in
                    if let error = errorDescriptor
                    {
                        if verboseFunctionExposure { print("failed to deserialize team") }

                        completion(nil, error)
                    }
                    else if let team = returnedTeam
                    {
                        if verboseFunctionExposure { print("deserialized team") }

                        completion(team, nil)
                    }
                    else { completion(nil, "An unknown error occurred.") }
                }
            }
            else { completion(nil, "No Team exists with the identifier \"\(withIdentifier)\".") }
        })
        { returnedError in

            completion(nil, "Unable to retrieve the specified data. (\(returnedError.localizedDescription))")
        }
    }

    /**
     Gets and deserializes multiple **Team** objects from a given array of identifier strings.

     - Parameter withIdentifiers: The identifiers to query for.
     - Parameter completion: Upon success, returns an array of deserialized **Team** objects. Upon failure, an array of strings describing the error(s) encountered.

     - Note: Completion variables are **NOT** *mutually exclusive.*

     ~~~
     completion(returnedTeams, errorDescriptors)
     ~~~
     */
    func getTeams(withIdentifiers: [String], completion: @escaping (_ returnedTeams: [Team]?, _ errorDescriptors: [String]?) -> Void)
    {
        var teamArray = [Team]()
        var errorDescriptorArray = [String]()

        if !withIdentifiers.isEmpty
        {
            for identifier in withIdentifiers
            {
                getTeam(withIdentifier: identifier) { returnedTeam, errorDescriptor in
                    if let team = returnedTeam
                    {
                        teamArray.append(team)

                        if teamArray.count + errorDescriptorArray.count == withIdentifiers.count
                        {
                            completion(teamArray, errorDescriptorArray.isEmpty ? nil : errorDescriptorArray.unique())
                        }
                    }
                    else
                    {
                        errorDescriptorArray.append(errorDescriptor!)

                        if teamArray.count + errorDescriptorArray.count == withIdentifiers.count
                        {
                            completion(teamArray.isEmpty ? nil : teamArray, errorDescriptorArray.unique())
                        }
                    }
                }
            }
        }
        else { completion(nil, ["No identifiers passed!"]) }
    }

    //==================================================//

    /* MARK: Removal Functions */

    /**
     Deletes the **Team** with the specified identifier from the server.

     - Parameter identifier: The identifier of the **Team** to be deleted.
     - Parameter completion: Upon failure, returns with a string describing the error(s) encountered.

     - Requires: The **Team's** associated **Tournament** (if applicable) to have more than just the specified **Team** in its list of *teamIdentifiers.*

     ~~~
     completion(errorDescriptor)
     ~~~
     */
    func deleteTeam(_ identifier: String, completion: @escaping (_ errorDescriptor: String?) -> Void)
    {
        getTeam(withIdentifier: identifier) { returnedTeam, errorDescriptor in
            if let team = returnedTeam
            {
                if let tournament = team.associatedTournament,
                   tournament.teamIdentifiers.filter({ $0 != identifier }).isEmpty
                {
                    completion("Deleting this Team would leave its associated Tournament with no participating Teams. Delete the Tournament first.")
                }
                else
                {
                    if let tournament = team.associatedTournament
                    {
                        TournamentSerializer().removeTeam(identifier, fromTournament: tournament.associatedIdentifier, deleting: false) { errorDescriptor in
                            if let error = errorDescriptor
                            {
                                completion(error)
                            }
                            else
                            {
                                self.finishDeletingTeam(identifier, withParticipants: Array(team.participantIdentifiers.keys)) { errorDescriptor in
                                    if let error = errorDescriptor
                                    {
                                        completion(error)
                                    }
                                    else { completion(nil) }
                                }
                            }
                        }
                    }
                    else
                    {
                        self.finishDeletingTeam(identifier, withParticipants: Array(team.participantIdentifiers.keys)) { errorDescriptor in
                            if let error = errorDescriptor
                            {
                                completion(error)
                            }
                            else { completion(nil) }
                        }
                    }
                }
            }
            else { completion(errorDescriptor!) }
        }
    }

    /**
     Removes the **User** with the specified identifier from all completed **Challenges** on the specified **Team.**

     - Parameter forUser: The identifier of the **User** to remove from the completed **Challenges.**
     - Parameter onTeam: The **Team** whose completed **Challenges** will be filtered.

     - Parameter completion: Upon failure, returns with a string describing the error(s) encountered.

     ~~~
     completion(errorDescriptor)
     ~~~
     */
    func removeUserFromCompletedChallenges(_ forUser: String, onTeam: Team, completion: @escaping (_ errorDescriptor: String?) -> Void)
    {
        if let completedChallenges = onTeam.completedChallenges
        {
            var filteredChallenges = [(Challenge, [(User, Date)])]()

            for challengeTuple in completedChallenges
            {
                let filteredMetadata = challengeTuple.metadata.filteringOut(user: forUser)

                if !filteredMetadata.isEmpty
                {
                    filteredChallenges.append((challengeTuple.challenge, filteredMetadata))
                }
            }

            if filteredChallenges.isEmpty
            {
                GenericSerializer().setValue(onKey: "/allTeams/\(onTeam.associatedIdentifier!)/completedChallenges", withData: ["!": ["!"]]) { returnedError in
                    if let error = returnedError
                    {
                        completion(errorInfo(error))
                    }
                    else { completion(nil) }
                }
            }
            else
            {
                addCompletedChallenges(filteredChallenges, toTeam: onTeam.associatedIdentifier, overwrite: true) { errorDescriptor in
                    if let error = errorDescriptor
                    {
                        completion(error)
                    }
                    else { completion(nil) }
                }
            }
        }
        else { completion(nil) }
    }

    /**
     Removes the **User** with the specified identifier from the *participantIdentifiers* array of the provided **Team.**

     - Parameter withIdentifier: The identifier of the **User** to remove from the **Team's** *participantIdentifiers.*
     - Parameter fromParticipantsOn: The **Team** whose *participantIdentifiers* array will be modified.

     - Parameter completion: Upon failure, returns with a string describing the error(s) encountered.

     ~~~
     completion(errorDescriptor)
     ~~~
     */
    func removeUser(withIdentifier: String, fromParticipantsOn team: Team, completion: @escaping (_ errorDescriptor: String?) -> Void)
    {
        team.participantIdentifiers = team.participantIdentifiers.filter { $0.key != withIdentifier }

        let newParticipants = team.participantIdentifiers.count == 0 ? ["!": 0] : team.participantIdentifiers

        GenericSerializer().setValue(onKey: "/allTeams/\(team.associatedIdentifier!)/participantIdentifiers", withData: newParticipants!.delimitedArray()) { returnedError in
            if let error = returnedError
            {
                completion(errorInfo(error))
            }
            else { completion(nil) }
        }
    }

    /**
     Removes a **User** from a **Team.**

     - Parameter withIdentifier: The identifier of the **User** to remove from the **Team.**
     - Parameter fromTeam: The identifier of the **Team** to remove the **User** from.
     - Parameter deleting: A Boolean describing whether the **Team** is being deleted or not.

     - Parameter completion: Upon failure, returns with a string describing the error(s) encountered.

     - Requires: If the **Team** is not being deleted, for the **Team** to have more participants than just the specified **User.**

     ~~~
     completion(errorDescriptor)
     ~~~
     */
    func removeUser(_ withIdentifier: String, fromTeam: String, deleting: Bool, completion: @escaping (_ errorDescriptor: String?) -> Void)
    {
        getTeam(withIdentifier: fromTeam) { returnedTeam, errorDescriptor in
            if let team = returnedTeam
            {
                if team.participantIdentifiers.filter({ $0.key != withIdentifier }).isEmpty && !deleting
                {
                    completion("Removing this User leaves the Team with no participants; delete the Team.")
                }
                else
                {
                    UserSerializer().removeTeam(withIdentifier: fromTeam, fromUser: withIdentifier) { errorDescriptor in
                        if let error = errorDescriptor
                        {
                            completion(error)
                        }
                        else
                        {
                            self.removeUserFromCompletedChallenges(withIdentifier, onTeam: team) { errorDescriptor in
                                if let error = errorDescriptor
                                {
                                    completion(error)
                                }
                                else
                                {
                                    self.removeUser(withIdentifier: withIdentifier, fromParticipantsOn: team) { errorDescriptor in
                                        if let error = errorDescriptor
                                        {
                                            completion(error)
                                        }
                                        else { completion(nil) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            else { completion(errorDescriptor!) }
        }
    }

    //==================================================//

    /* MARK: Private Functions */

    /**
     Deserializes an array of completed **Challenges** from a given data bundle.

     - Parameter challenges: The serialized **Challenges** to convert.
     - Parameter completion: Upon success, returns an array of `(Challenge, [(User, Date)]` tuples. Upon failure, a string describing the error(s) encountered.

     - Note: Completion variables are *mutually exclusive.*

     ~~~
     completion(completedChallenges, errorDescriptor)
     ~~~
     */
    private func deSerializeCompletedChallenges(with challenges: [String: [String]], completion: @escaping (_ completedChallenges: [(Challenge, [(user: User, dateCompleted: Date)])]?, _ errorDescriptor: String?) -> Void)
    {
        if verboseFunctionExposure { print("deserialising completed challenges") }
        var deSerializedCompletedChallenges = [(Challenge, [(user: User, dateCompleted: Date)])]()

        //serialized completed challenges = ["challengeId":["userId – dateString"]]

        for challengeIdentifier in Array(challenges.keys)
        {
            if verboseFunctionExposure { print("processing \(challengeIdentifier)") }

            ChallengeSerializer().getChallenge(withIdentifier: challengeIdentifier) { returnedChallenge, errorDescriptor in
                if let error = errorDescriptor
                {
                    completion(nil, "While getting Challenges: \(error)")
                }
                else if let challenge = returnedChallenge, let metadata = challenges[challengeIdentifier]
                {
                    var deSerializedMetadata = [(User, Date)]()

                    for string in metadata
                    {
                        var components = string.components(separatedBy: "–")

                        if components.count == 1
                        {
                            components = string.components(separatedBy: "\u{2014}")
                        }

                        guard components.count == 2 else
                        { completion(nil, "A Challenge's metadata array was improperly formatted."); return }

                        guard let completionDate = secondaryDateFormatter.date(from: components[1].leadingWhitespaceRemoved) else
                        { completion(nil, "Unable to convert a Challenge's completion date string to a Date."); return }

                        let userIdentifier = components[0].trailingWhitespaceRemoved

                        UserSerializer().getUser(withIdentifier: userIdentifier) { returnedUser, errorDescriptor  in
                            if let error = errorDescriptor
                            {
                                completion(nil, "While getting a User for a Challenge: \(error)")
                            }
                            else if let user = returnedUser
                            {
                                deSerializedMetadata.append((user, completionDate))

                                //This used to be "index == metadata.count - 1" and the metadata array was enumerated.
                                if deSerializedMetadata.count == metadata.count
                                {
                                    deSerializedCompletedChallenges.append((challenge, deSerializedMetadata))

                                    if deSerializedCompletedChallenges.count == challenges.count
                                    {
                                        completion(deSerializedCompletedChallenges, nil)
                                    }
                                }
                            }
                            else { completion(nil, "An unknown error occurred while getting a User for a Challenge.") }
                        }
                    }
                }
                else { completion(nil, "An unknown error occurred while getting a Challenge.") }
            }
        }
    }

    /**
     Deserializes a **Team** from a given data bundle.

     - Parameter from: The data bundle from which to deserialize the **Team.**
     - Parameter completion: Upon success, returns a deserialized **Team** object. Upon failure, a string describing the error(s) encountered.

     - Note: Completion variables are *mutually exclusive.*
     - Requires: A well-formed bundle of **Team** metadata.

     ~~~
     completion(deSerializedTeam, errorDescriptor)
     ~~~
     */
    private func deSerializeTeam(from dataBundle: [String: Any], completion: @escaping (_ deSerializedTeam: Team?, _ errorDescriptor: String?) -> Void)
    {
        if verboseFunctionExposure { print("deserialising team") }

        guard validateTeamMetadata(dataBundle) == true else
        { completion(nil, "Improperly formatted metadata."); return }

        let associatedIdentifier       = dataBundle["associatedIdentifier"] as! String
        let additionalPoints           = dataBundle["additionalPoints"] as! Int
        let associatedTournament       = dataBundle["associatedTournament"] as! String
        let completedChallenges        = dataBundle["completedChallenges"] as! [String: [String]]
        let joinCode                   = dataBundle["joinCode"] as! String
        let name                       = dataBundle["name"] as! String
        let participantIdentifierArray = dataBundle["participantIdentifiers"] as! [String]

        let participantIdentifiers = participantIdentifierArray.dictionary()

        var deSerializedCompletedChallenges: [(Challenge, [(user: User, dateCompleted: Date)])]?

        let group = DispatchGroup()

        group.enter()

        if completedChallenges.keys.first != "!"
        {
            deSerializeCompletedChallenges(with: completedChallenges) { completedChallenges, errorDescriptor in
                if let error = errorDescriptor
                {
                    if verboseFunctionExposure { print("failed to deserialize completed challenges") }

                    group.leave()

                    completion(nil, error)
                }
                else if let challenges = completedChallenges
                {
                    deSerializedCompletedChallenges = challenges

                    group.leave()
                }
                else
                {
                    group.leave()

                    completion(nil, "An unknown error occurred.")
                }
            }
        }
        else
        {
            deSerializedCompletedChallenges = []

            group.leave()
        }

        group.notify(queue: .main) {
            guard let completedChallenges = deSerializedCompletedChallenges else
            { completion(nil, "Couldn't get completed Challenges."); return }

            if associatedTournament != "!"
            {
                group.enter()

                TournamentSerializer().getTournament(withIdentifier: associatedTournament) { returnedTournament, errorDescriptor in
                    if let tournament = returnedTournament
                    {
                        let deSerializedTeam = Team(associatedIdentifier:   associatedIdentifier,
                                                    additionalPoints:       additionalPoints,
                                                    associatedTournament:   tournament,
                                                    completedChallenges:    completedChallenges,
                                                    joinCode:               joinCode,
                                                    name:                   name,
                                                    participantIdentifiers: participantIdentifiers)

                        group.leave()

                        completion(deSerializedTeam, nil)
                    }
                    else
                    {
                        group.leave()

                        completion(nil, errorDescriptor)
                    }
                }
            }
            else
            {
                let deSerializedTeam = Team(associatedIdentifier:   associatedIdentifier,
                                            additionalPoints:       additionalPoints,
                                            associatedTournament:   nil,
                                            completedChallenges:    completedChallenges,
                                            joinCode:               joinCode,
                                            name:                   name,
                                            participantIdentifiers: participantIdentifiers)

                completion(deSerializedTeam, nil)
            }
        }
    }

    /**
     Finalises **Team** deletion by removing all **Users** from the **Team** and clearing the **Team's** data on the server.

     - Parameter identifier: The identifier of the **Team** being deleted.
     - Parameter withParticipants: An array of **User** identifiers to be removed from the specified **Team.**

     - Parameter completion: Upon failure, returns with a string describing the error(s) encountered.

     ~~~
     completion(errorDescriptor)
     ~~~
     */
    private func finishDeletingTeam(_ identifier: String, withParticipants: [String], completion: @escaping (_ errorDescriptor: String?) -> Void)
    {
        removeUsers(withParticipants, fromTeam: identifier) { errorDescriptor in
            if let error = errorDescriptor
            {
                completion(error)
            }
            else
            {
                GenericSerializer().setValue(onKey: "/allTeams/\(identifier)", withData: NSNull()) { returnedError in
                    if let error = returnedError
                    {
                        completion(errorInfo(error))
                    }
                    else { completion(nil) }
                }
            }
        }
    }

    /**
     Generates a 2-word join code for the **Team.**

     - Parameter completion: Upon success, returns with the randomly generated join code. Upon failure, an error.

     - Note: Completion variables are *mutually exclusive.*

     ~~~
     completion(returnedCode, returnedError)
     ~~~
     */
    private func generateJoinCode(completion: @escaping (_ returnedCode: String?, _ returnedError: Error?) -> Void)
    {
        if let wordsFilePath = Bundle.main.path(forResource: "words", ofType: "txt")
        {
            do {
                let wordsString = try String(contentsOfFile: wordsFilePath)
                let wordLines = wordsString.components(separatedBy: .newlines)

                var joinCodeArray = [String]()

                while joinCodeArray.count < 2
                {
                    var randomWord = wordLines[numericCast(arc4random_uniform(numericCast(wordLines.count)))]

                    while randomWord.count > 6 || randomWord.lowercased() != randomWord
                    {
                        randomWord = wordLines[numericCast(arc4random_uniform(numericCast(wordLines.count)))]
                    }

                    joinCodeArray.append(randomWord)
                }

                completion(joinCodeArray.joined(separator: " "), nil)
            }
            catch
            {
                completion(nil, error)
            }
        }
    }

    /**
     Removes an array of **Users** from a **Team.**

     - Parameter users: An array of **User** identifiers to be removed from the specified **Team.**
     - Parameter fromTeam: The identifier of the **Team** from which to remove the specified **Users.**

     - Parameter completion: Upon failure, returns with a string describing the error(s) encountered.

     ~~~
     completion(errorDescriptor)
     ~~~
     */
    private func removeUsers(_ users: [String], fromTeam: String, completion: @escaping (_ errorDescriptor: String?) -> Void)
    {
        var errors = [String]()

        for (index, user) in users.enumerated()
        {
            removeUser(user, fromTeam: fromTeam, deleting: true) { errorDescriptor in
                if let error = errorDescriptor
                {
                    errors.append(error)

                    if index == users.count - 1
                    {
                        completion(errors.unique().joined(separator: "\n"))
                    }
                }
                else
                {
                    if index == users.count - 1
                    {
                        completion(errors.isEmpty ? nil : errors.unique().joined(separator: "\n"))
                    }
                }
            }
        }
    }

    /**
     Serialises an array of completed **Challenges** for the server.

     - Parameter with: The array of completed **Challenges** to serialize.

     - Returns: A dictionary of serialized completed **Challenges.**
     */
    private func serializeCompletedChallenges(_ with: [(challenge: Challenge, metadata: [(user: User, dateCompleted: Date)])]) -> [String: [String]]
    {
        var dataBundle: [String: [String]] = [:]

        for bundle in with
        {
            //["challengeId":["userId – dateString"]]
            var serializedMetadata = [String]()

            for datum in bundle.metadata
            {
                let metadataString = "\(datum.user.associatedIdentifier!) – \(secondaryDateFormatter.string(from: datum.dateCompleted))"
                serializedMetadata.append(metadataString)
            }

            dataBundle["\(bundle.challenge.associatedIdentifier!)"] = serializedMetadata
        }

        if dataBundle == [:]
        {
            dataBundle = ["!": ["!"]]
        }

        return dataBundle
    }

    /**
     Validates the contents of a serialized **Team.**

     - Parameter withDataBundle: The serialized **Team** whose structural integrity will be verified.

     - Returns: A Boolean describing whether or not the data is well-formed.
     - Warning: Dumps errors to console.
     */
    private func validateTeamMetadata(_ withDataBundle: [String: Any]) -> Bool
    {
        guard withDataBundle["associatedIdentifier"] as? String != nil else
        { report("Malformed «associatedIdentifier».", errorCode: nil, isFatal: false, metadata: [#file, #function, #line]); return false }

        guard withDataBundle["additionalPoints"] as? Int != nil else
        { report("Malformed «additionalPoints».", errorCode: nil, isFatal: false, metadata: [#file, #function, #line]); return false }

        guard withDataBundle["associatedTournament"] as? String != nil else
        { report("Malformed «associatedTournament».", errorCode: nil, isFatal: false, metadata: [#file, #function, #line]); return false }

        guard withDataBundle["completedChallenges"] as? [String: [String]] != nil else
        { report("Malformed «completedChallenges».", errorCode: nil, isFatal: false, metadata: [#file, #function, #line]); return false }

        guard withDataBundle["joinCode"] as? String != nil else
        { report("Malformed «joinCode».", errorCode: nil, isFatal: false, metadata: [#file, #function, #line]); return false }

        guard withDataBundle["name"] as? String != nil else
        { report("Malformed «name».", errorCode: nil, isFatal: false, metadata: [#file, #function, #line]); return false }

        guard let participantIdentifierArray = withDataBundle["participantIdentifiers"] as? [String] else
        { report("Malformed «participantIdentifierArray».", errorCode: nil, isFatal: false, metadata: [#file, #function, #line]); return false }

        guard !participantIdentifierArray.dictionary().isEmpty else
        { report("Malformed «participantIdentifiers».", errorCode: nil, isFatal: false, metadata: [#file, #function, #line]); return false  }

        return true
    }
}

//==================================================//

/* MARK: Extensions */

extension Array where Element == String
{
    func dictionary() -> [String: Int]
    {
        var dictionary = [String: Int]()

        for element in self
        {
            var components = element.components(separatedBy: "–")

            if components.count == 1
            {
                components = element.components(separatedBy: "\u{2014}")
            }

            guard components.count == 2 else
            { return dictionary }

            let teamIdentifier = components[0].trailingWhitespaceRemoved

            guard let manuallyAddedPoints = Int(components[1].leadingWhitespaceRemoved) else
            { return dictionary }

            dictionary[teamIdentifier] = manuallyAddedPoints
        }

        return dictionary
    }
}

extension Array where Element == (user: User, dateCompleted: Date)
{
    func filteringOut(user: String) -> [(user: User, dateCompleted: Date)]
    {
        var filteredMetadata = [(user: User, dateCompleted: Date)]()

        for datum in self
        {
            if datum.user.associatedIdentifier != user
            {
                filteredMetadata.append(datum)
            }
        }

        return filteredMetadata
    }
}

extension Dictionary where Key == String, Value == Int
{
    func delimitedArray() -> [String]
    {
        var array = [String]()

        for key in Array(keys)
        {
            array.append("\(key) – \(self[key]!)")
        }

        return array.sorted()
    }

    func merge(with: [String: Int]) -> [String: Int]
    {
        var merged = self

        for key in Array(with.keys)
        {
            merged[key] = with[key]
        }

        return merged
    }
}
