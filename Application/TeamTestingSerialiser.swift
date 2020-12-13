//
//  TeamTestingSerialiser.swift
//  Mulu Party
//
//  Created by Grant Brooks Goodman on 12/12/2020.
//  Copyright © 2013-2020 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import UIKit

class TeamTestingSerialiser
{
    //==================================================//
    
    /* Public Functions */
    
    func createRandomTeam(with users: [User], completedChallenges: [(challenge: Challenge, metadata: [(user: User, dateCompleted: Date)])], completion: @escaping(_ returnedIdentifier: String?, _ errorDescriptor: String?) -> Void)
    {
        let universityNames = ["Princeton", "Harvard", "Columbia", "MIT", "Yale", "Stanford", "UChicago", "UPenn", "Caltech", "Johns Hopkins", "Northwestern", "Duke", "Dartmouth", "Brown", "Vanderbilt", "Rice", "WashU St. Louis", "Cornell", "Notre Dame", "UCLA", "Emory", "UC Berkeley", "Georgetown", "UMich", "USC", "UVA", "UNC Chapel Hill", "Wake Forest", "NYU", "Tufts", "UCSB"]
        
        TeamSerialiser().createTeam(name: "Team \(universityNames.randomElement()!)", participantIdentifiers: users.identifiers()) { (returnedIdentifier, errorDescriptor) in
            if let error = errorDescriptor
            {
                completion(nil, error)
            }
            else if let identifier = returnedIdentifier
            {
                TeamSerialiser().addCompletedChallenges(completedChallenges, toTeam: identifier, overwrite: true) { (errorDescriptor) in
                    if let error = errorDescriptor
                    {
                        completion(nil, error)
                    }
                    else
                    {
                        completion(identifier, nil)
                    }
                }
            }
        }
    }
}