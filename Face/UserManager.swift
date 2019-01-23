//
//  UserManager.swift
//  Face
//
//  Created by Alexandre Ménielle on 22/01/2019.
//  Copyright © 2019 Ali Hashim. All rights reserved.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class UserManager: NSObject {
    
    static let shared = UserManager()
    
    lazy var db = Firestore.firestore()
    
    var userId : String?
    var email : String {
        get{
            return UserDefaults.standard.string(forKey: "user_email") ?? ""
        }
        set{
            UserDefaults.standard.set(newValue, forKey: "user_email")
        }
    }
    
    var personalData : Bool {
        get{
            return UserDefaults.standard.bool(forKey: "personalData")
        }
        set{
            UserDefaults.standard.set(newValue, forKey: "personalData")
        }
    }
    
    func initUser(){
        self.userId = Auth.auth().currentUser?.uid
    }
    
    func createUser(){
        guard let id = self.userId else { return }
        let data : [String:Any] =  ["email" : email,
                                    "id" : id]
        db.collection("users").document(id).setData(data)
    }
}
