//
//  AboutScreenView.swift
//  RunAndRead
//
//  Created by Serge Nes on 2/3/25.
//

import SwiftUI

struct AboutScreenView: View {
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Main Description
                    Text("""
Run & Read is a free, user-friendly text-to-speech app designed to bring your digital content to life. Using Apple's powerful embedded text-to-speech engine, our app converts PDFs, EPUBs, TXT files, or any copied text into engaging audio—so you can enjoy your favorite books and articles anytime, anywhere.
""")
                    
                    // Our Mission Section
                    Text("Our Mission")
                        .font(.title2)
                        .bold()
                    Text("""
We believe that great literature and valuable information should be accessible to everyone. Run & Read makes it easy to listen to your digital content while you’re on the go—whether you’re exercising, commuting, or simply relaxing.
""")
                    
                    // Curated Library Section
                    Text("Curated Public Domain Library")
                        .font(.title2)
                        .bold()
                    Text("""
To help you get started, we’ve preloaded a selection of classic books from public domain sources, including titles from Project Gutenberg. These timeless works are legally free to use and share, allowing you to explore classic literature without any copyright concerns. We encourage you to support authors and publishers by enjoying content that you have legally acquired.
""")
                    VStack(alignment: .leading) {
                        Text("Visit Project Gutenberg website:")
                        Link(destination: URL(string: "https://gutenberg.org")!) {
                            Text("www.gutenberg.org")
                                .underline()
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Legal Notice Section
                    Text("Legal & Copyright Notice")
                        .font(.title2)
                        .bold()
                    Text("""
Run & Read is committed to respecting intellectual property rights. Please use this app only for your personally purchased digital content or for works that are in the public domain. For preloaded books from Project Gutenberg and other sources, we adhere strictly to their guidelines and terms of use.
""")
                    
                    Text("Thank you for choosing Run & Read. We hope our app enriches your daily routine by making reading more accessible and enjoyable!")
                    
                    // Website Link
                    VStack(alignment: .leading) {
                        Text("Visit our website:")
                        Link(destination: URL(string: "https://answersolutions.net")!) {
                            Text("www.answersolutions.net")
                                .underline()
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // App Version
                    Text("App Version: \(Bundle.main.fullVersion)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    VStack {
                        // Support Button
                        Button(action: {
                            let messageToSend = """
        Run & Read Support/Feedback Report
        <br><br>
        ==Report Begins==========<br>
        Input here your feedback or the details of the issues you have.
        <br>==Report Ends============
        <br><br>
        OS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)
        <br>
        Model: \(UIDevice.current.model)
        <br>
        App Version: \(Bundle.main.fullVersion)
        <br>
        """
                            EmailService.shared.sendEmail(
                                subject: "Run & Read Support/Feedback Report",
                                body: messageToSend,
                                to: "support@answersolutions.net") { (canSend, sent) in
                                if !sent {
                                    print("email is not sent")

                                } else {
                                    print("email sent")

                                }
                            }
                        }) {
                            
                            LongButtonView(title: "Report an Issue", backgroundColor: .primary)
                                .frame(maxWidth: .infinity)
                        }
                        Text("Have an issue, feedback, or suggestion? Send us an email.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    

                    .padding(.horizontal)
                    
                    Divider()
                    VStack {
                    Button(action: {
                        askForAppRating()
                    }) {
                        LongButtonView(title: "Rate the App", backgroundColor: .primary)
                            .frame(maxWidth: .infinity)
                    }
                    Text("If you enjoy listening to text with our app, please give us a rating in the App Store.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                    .padding()
                    
                }
                .padding()
            }
            .navigationTitle("About")
        }
    }
}

#Preview {
    AboutScreenView()
}
