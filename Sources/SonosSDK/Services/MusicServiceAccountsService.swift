//
//  MusicServiceAccountsService.swift
//  SonosSDK
//
//  Created on 2025-01-22.
//

import Foundation
import SwiftyJSON
import SonosNetworking

struct MusicServiceAccountsService {

    func matchAccount(authenticationToken: AuthenticationToken, householdId: String, serviceId: String, userIdHashCode: String, nickname: String, linkCode: String? = nil, linkDeviceId: String? = nil, success: @escaping (MusicServiceAccount) -> (), failure: @escaping (Error?) -> ()) {
        MusicServiceAccountsMatchNetwork(accessToken: authenticationToken.access_token, householdId: householdId, userIdHashCode: userIdHashCode, nickname: nickname, serviceId: serviceId, linkCode: linkCode, linkDeviceId: linkDeviceId, success: { data in
            guard let data = data,
                  let account = MusicServiceAccount(data) else {
                let error = NSError.errorWithMessage(message: "Could not create MusicServiceAccount object.")
                failure(error)
                return
            }
            success(account)
        }, failure: { error in
            failure(error)
        }).performRequest()
    }
}
