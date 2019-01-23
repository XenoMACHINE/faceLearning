//
//  ConnectionViewController.swift
//  iOScape
//
//  Created by Alexandre Ménielle on 16/12/2018.
//  Copyright © 2018 Alexandre Ménielle. All rights reserved.
//

import UIKit
import FirebaseAuth

class ConnectionViewController: UIViewController {
    
    @IBOutlet weak var stackTextfield: UIStackView!
    @IBOutlet weak var closeBtn: UIButton!
    @IBOutlet weak var connectBtn: GlobalButton!
    @IBOutlet weak var emailTf: UITextField!
    @IBOutlet weak var passwordTf: UITextField!
    @IBOutlet weak var secondPasswordTf: UITextField!
    @IBOutlet weak var buttonsViewConstraintBottom: NSLayoutConstraint!
    
    private var buttonsViewDefaultConstraint : CGFloat = 0
    
    enum ConnectionMode {
        case signIn
        case signUp
    }
    
    var mode : ConnectionMode = .signIn
    var showCloseBtn = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.closeBtn.isHidden = !showCloseBtn
        
        emailTf.text = UserManager.shared.email
        secondPasswordTf.isHidden = true
        addDelegateTextfieldsInStackview()
        
        addKeyboardEvents()
        selectTextfield()
    }
    
    func selectTextfield(){
        if (emailTf.text?.count ?? 0) > 0 {
            passwordTf.becomeFirstResponder()
            return
        }
        emailTf.becomeFirstResponder()
    }
    
    func addKeyboardEvents(){
        NotificationCenter.default.addObserver(self, selector: #selector(keyBoardWillShow(notification:)), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyBoardWillHide(notification:)), name: .UIKeyboardWillHide, object: nil)
        self.buttonsViewDefaultConstraint = self.buttonsViewConstraintBottom.constant
    }
    
    @objc func keyBoardWillShow(notification: NSNotification) {
        guard let keyboardFrame: NSValue = notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue else { return }
        self.buttonsViewConstraintBottom.constant = keyboardFrame.cgRectValue.height - 20
    }
    
    @objc func keyBoardWillHide(notification: NSNotification) {
        self.buttonsViewConstraintBottom.constant = buttonsViewDefaultConstraint
    }
    
    func addDelegateTextfieldsInStackview() {
        var count = 0
        for view in stackTextfield.subviews{
            if let textfield = view as? UITextField{
                textfield.delegate = self
                textfield.tag = count
                count += 1
            }
        }
    }
    
    func signIn(){
        UserManager.shared.email = emailTf.text ?? ""
        self.connectBtn.setAnimating(animated: true)
        Auth.auth().signIn(withEmail: emailTf.text ?? "", password: passwordTf.text ?? "") { (result, error) in
            self.connectBtn.setAnimating(animated: false)
            if let err = error{
                self.showAlert(title: "Un problème est survenu", message: err.localizedDescription)
                return
            }
            UserManager.shared.initUser()
            self.dismiss(animated: true)
        }
    }
    
    func signUp(){
        UserManager.shared.email = emailTf.text ?? ""
        if passwordTf.text == secondPasswordTf.text {
            self.connectBtn.setAnimating(animated: true)
            Auth.auth().createUser(withEmail: emailTf.text ?? "", password: passwordTf.text ?? "", completion: { (result, error) in
                self.connectBtn.setAnimating(animated: false)
                if let err = error{
                    self.showAlert(title: "Un problème est survenu", message: err.localizedDescription)
                    return
                }
                UserManager.shared.initUser()
                UserManager.shared.createUser()
                self.dismiss(animated: true)
            })
            
        }else{
            self.showAlert(title: "Champs mauvais", message: "Les mots de passe ne correspondent pas")
        }
    }
    
    @IBAction func onClose(_ sender: Any) {
        self.dismiss(animated: true)
    }
    
    @IBAction func onSignInSignUp(_ sender: Any) {
        switch mode {
        case .signIn:
            signIn()
        case .signUp:
            signUp()
        }
    }
    
    @IBAction func onChangeMode(_ sender: UIButton) {
        if mode == .signIn{
            mode = .signUp
            connectBtn.setTitle("S'INSCRIRE", for: .normal)
            sender.setTitle("SE CONNECTER", for: .normal)
            secondPasswordTf.isHidden = false
        }else{
            mode = .signIn
            connectBtn.setTitle("SE CONNECTER", for: .normal)
            sender.setTitle("S'INSCRIRE", for: .normal)
            secondPasswordTf.isHidden = true
        }
    }
}

extension ConnectionViewController : UITextFieldDelegate{
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.tag + 1 < stackTextfield.subviews.count,
            let mTextField = stackTextfield.subviews[textField.tag + 1] as? UITextField,
            mTextField.isHidden == false{
            
            mTextField.becomeFirstResponder()
        }else{
            self.view.endEditing(true)
        }
        return true
    }
}
