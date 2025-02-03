//
//  EmailService.swift
//  RunAndRead
//
//  Created by Serge Nes on 2/3/25.
//

import Foundation
import MessageUI


class EmailService: NSObject, MFMailComposeViewControllerDelegate {
    public static let shared = EmailService()
    

    private var completion: (Bool, Bool) -> Void = {_, _ in}
    
    func loadFileFromLocalPath(_ localFilePath: String) ->Data? {
       return try? Data(contentsOf: URL(fileURLWithPath: localFilePath))
    }
    
    func loadFileFromLocalPath(_ localFilePath: URL) ->Data? {
       return try? Data(contentsOf: localFilePath)
    }

    func sendEmail(subject:String, body:String, to:String, attachment: URL? = nil, completion: @escaping (Bool, Bool) -> Void){
        if MFMailComposeViewController.canSendMail() {
            self.completion = completion
            let picker = MFMailComposeViewController()
            picker.setSubject(subject)
            picker.setMessageBody(body, isHTML: true)
            picker.setToRecipients([to])
            if let path = attachment {
                if let data = loadFileFromLocalPath(path) {
                    picker.addAttachmentData(data, mimeType: "audio/flac", fileName: "recorded_call.flac")
                }
            }
    
            picker.mailComposeDelegate = self
     
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first as? UIWindowScene
            if let window = windowScene?.windows.first {
                window.rootViewController?.present(picker,  animated: true, completion: nil)
            }
        } else {
            self.completion = {_, _ in}
            completion(false, false)
        }
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        switch result {
        case .sent:
            completion(true,  true)
        default:
            completion(true,  false)
        }
        controller.dismiss(animated: true) {
            self.completion = {_, _ in}
        }
     }
}

