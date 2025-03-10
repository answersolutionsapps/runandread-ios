//
//  Extensions.swift
//  TalkWise
//
//  Created by Serge Nes on 4/3/23.
//

import Foundation
import SwiftUI

extension Double {
    private static var timeHMSFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()

    private static var timeMSFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()

    func formatSecondsToHMS(_ seconds: Double) -> String {
        if seconds.isNaN {
            return "00:00"
        }
        if seconds < 3600 {
            return Double.timeMSFormatter.string(from: seconds)!
        } else {
            return Double.timeHMSFormatter.string(from: seconds)!
        }
    }
}

extension Float {
    func playbackRateToString() -> String {
        let roundedValue = (self * 100).rounded() / 100 // Rounds to nearest 0.01
        switch roundedValue {
        case 0.7:
            return "2.00"
        case 0.65:
            return "1.75"
        case 0.60:
            return "1.50"
        case 0.55:
            return "1.25"
        case 0.45:
            return "0.75"
        case 0.40:
            return "0.50"
        case 0.35:
            return "0.25"
        default:
            return "1.0"
        }
    }

    func playbackRateToSpeed() -> Float {
        let roundedValue = (self * 100).rounded() / 100 // Rounds to nearest 0.01
        switch roundedValue {
        case 0.7:
            return 2.0
        case 0.65:
            return 1.75
        case 0.60:
            return 1.50
        case 0.55:
            return 1.25
        case 0.45:
            return 0.75
        case 0.40:
            return 0.50
        case 0.35:
            return 0.25
        default:
            return 1.0
        }
    }

    func speedToPlaybackRate() -> Float {
        let roundedValue = (self * 100).rounded() / 100 // Rounds to nearest 0.01
        switch roundedValue {
        case 2.00:
            return 0.7
        case 1.75:
            return 0.65
        case 1.50:
            return 0.60
        case 1.25:
            return 0.55
        case 0.75:
            return 0.45
        case 0.50:
            return 0.40
        case 0.25:
            return 0.35
        default:
            return 0.5
        }
    }
}

extension Locale {
    func localizedString(forKey key: String) -> String {
        // Get the language code from the locale
        guard let languageCode = self.language.languageCode?.identifier else {
            return NSLocalizedString(key, comment: "")
        }

        // Get the path of the appropriate .lproj folder based on the language code
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj") else {
            return NSLocalizedString(key, comment: "")
        }

        // Get the bundle for the specific language
        guard let languageBundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }

        // Get the localized string from the language bundle
        return NSLocalizedString(key, tableName: nil, bundle: languageBundle, value: "", comment: "")
    }
}

extension Text {
    func highlighter() -> Text {
        return self.fontWeight(.bold)
    }
}

struct AttributedText: UIViewRepresentable {
    var attributedString: NSAttributedString

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.backgroundColor = .clear
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributedString
    }
}

extension String {
    func substring(with nsRange: NSRange) -> String? {
        guard let range = Range(nsRange, in: self) else {
            return nil
        }
        return String(self[range])
    }

    func substring(upTo nsRange: NSRange) -> String? {
        guard let range = Range(nsRange, in: self) else {
            return nil
        }
        return String(self[..<range.lowerBound])
    }

    func substring(after nsRange: NSRange) -> String? {
        guard let range = Range(nsRange, in: self) else {
            return nil
        }
        return String(self[range.upperBound...])
    }

    func substringTwoSentences() -> String {
        var spaceCount = 0
        for (index, char) in self.enumerated() {
            if char == "." {
                spaceCount += 1
                if spaceCount == 2 {
                    return String(self.prefix(index)) + "!"
                }
            }
        }
        return self // Return full text if less than 5 spaces
    }
}

struct ListSeparatorNone: ViewModifier {

    var backgroundColor: Color = Color(.systemBackground)

    func body(content: Content) -> some View {
        content
                .listRowInsets(EdgeInsets(top: -1, leading: 0, bottom: 0, trailing: 0))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(backgroundColor)
    }
}

extension View {
    func listSeparatorNone(backgroundColor: Color = Color(.systemBackground)) -> some View {
        self.modifier(ListSeparatorNone(backgroundColor: backgroundColor))
    }
}

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

extension View {
    @ViewBuilder
    func `ifElse`<V: View, T: View>(_ condition: Bool, _ then: @escaping (Self) -> V, `else`: @escaping ((Self) -> T)) -> some View {
        if condition {
            then(self)
        } else {
            `else`(self)
        }
    }
}

extension View {
    //fix for warning: 'Publishing changes from within view updates is not allowed, this will cause undefined behaviour'
    func sync(_ published: Binding<Bool>, with binding: Binding<Bool>) -> some View {
        self
                .onChange(of: published.wrappedValue) { published in
                    binding.wrappedValue = published
                }
                .onChange(of: binding.wrappedValue) { binding in
                    published.wrappedValue = binding
                }
    }

    func aSolBadge(count: Int) -> some View {
        overlay(
                ZStack {
                    if count != 0 {
                        Text("\(count)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(4)
                                .background(RoundedRectangle(cornerRadius: 44)
                                        .fill(Color.red)
                                )
                                .foregroundColor(.white)
                                .opacity(0.9)
                    }
                }
                        .offset(x: 28, y: -10)
                        .frame(width: 36, height: 24)
                , alignment: .topTrailing)
    }
}

extension UIFont {
    class func preferredFont(from font: Font) -> UIFont {
        let style: UIFont.TextStyle
        switch font {
        case .largeTitle:  style = .largeTitle
        case .title:       style = .title1
        case .title2:      style = .title2
        case .title3:      style = .title3
        case .headline:    style = .headline
        case .subheadline: style = .subheadline
        case .callout:     style = .callout
        case .caption:     style = .caption1
        case .caption2:    style = .caption2
        case .footnote:    style = .footnote
        case .body: fallthrough
        default:           style = .body
        }
        return UIFont.preferredFont(forTextStyle: style)
    }
}

func nprint(_ items: Any...) {
    #if DEBUG
    print("\(#function):", items)
    #endif
}

func nprint(_ message: String, function: String = #function) {
    #if DEBUG
    print("\(function): \(message)")
    #endif
}

func BG(_ block: @escaping () -> Void) {
    DispatchQueue.global(qos: .default).async(execute: block)
}

func UI(_ block: @escaping () -> Void) {
    DispatchQueue.main.async(execute: block)
}

extension UINavigationController {

    ///Get previous view controller of the navigation stack
    func previousViewController() -> UIViewController? {

        let lenght = self.viewControllers.count

        let previousViewController: UIViewController? = lenght >= 2 ? self.viewControllers[lenght - 2] : nil

        return previousViewController
    }

}

extension UIView {
    class func fromNib<T: UIView>() -> T {
        return Bundle.main.loadNibNamed(String(describing: T.self), owner: nil, options: nil)![0] as! T
    }

    func roundCorners(cornerRadius: Double) {
        self.layer.cornerRadius = CGFloat(cornerRadius)
        self.clipsToBounds = true
    }
}

extension CGRect {
    init(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) {
        self.init(x: x, y: y, width: width, height: height)
    }

}

extension CGSize {
    init(_ width: CGFloat, _ height: CGFloat) {
        self.init(width: width, height: height)
    }
}

extension CGPoint {
    init(_ x: CGFloat, _ y: CGFloat) {
        self.init(x: x, y: y)
    }
}


func CGRectMake(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
    return CGRect(x: x, y: y, width: width, height: height)
}

extension UIViewController {
    // Helper for showing an alert
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(
                title: title,
                message: message,
                preferredStyle: .alert
        )
        let ok = UIAlertAction(
                title: "OK",
                style: .default,
                handler: nil
        )
        alert.addAction(ok)
        present(alert, animated: true, completion: nil)
    }

    func showDialog(title: String, message: String, action1: UIAlertAction, action2: UIAlertAction) {
        let alert = UIAlertController(
                title: title,
                message: message,
                preferredStyle: .alert
        )
        alert.addAction(action1)
        alert.addAction(action2)
        present(alert, animated: true, completion: nil)
    }
}

extension UIColor {
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")

        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }

    convenience init(netHex: Int) {
        self.init(red: (netHex >> 16) & 0xff, green: (netHex >> 8) & 0xff, blue: netHex & 0xff)
    }
}

extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).uppercased() + self.lowercased().dropFirst()
    }

    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }
}

class VerticallyCenteredTextView: UITextView {
    override var contentSize: CGSize {
        didSet {
            var topCorrection = (bounds.size.height - contentSize.height * zoomScale) / 2.0
            topCorrection = max(0, topCorrection)
            contentInset = UIEdgeInsets(top: topCorrection, left: 0, bottom: 0, right: 0)
        }
    }
}


extension String {
    var htmlStripped: String {
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
    }
}

extension String {
    func applyPatternOnNumbers(pattern: String, replacementCharacter: Character) -> String {
        var pureNumber = self.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        for index in 0..<pattern.count {
            guard index < pureNumber.count else {
                return pureNumber
            }
            let stringIndex = String.Index(utf16Offset: index, in: pattern)
            let patternCharacter = pattern[stringIndex]
            guard patternCharacter != replacementCharacter else {
                continue
            }
            pureNumber.insert(patternCharacter, at: stringIndex)
        }
        return pureNumber
    }

    func toFormattedPhone() -> String {
        return self.applyPatternOnNumbers(pattern: "+# (###) ###-####", replacementCharacter: "#")
    }

    func digitsOnly() -> String {
        return self.replacingOccurrences(of: "[-( )+]", with: "", options: .regularExpression)
    }

    func isPhoneNumber() -> Bool {
        return self.digitsOnly().count > 9
    }

    func validPhoneNumber() -> Bool {
        return self.digitsOnly().count == 11 && self.digitsOnly().starts(with: "1")
    }

    func epochStringToDateTimeString() -> String {
        let dateFormatter = DateFormatter()

        let date = Date(timeIntervalSince1970: TimeInterval(Int(self) ?? 0))

        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        return dateFormatter.string(from: date)
    }

    func epochStringToDateString() -> String {
        let dateFormatter = DateFormatter()

        let date = Date(timeIntervalSince1970: TimeInterval(Int(self) ?? 0))
        dateFormatter.dateStyle = .short

        dateFormatter.timeStyle = .none
        return dateFormatter.string(from: date)
    }

    func epochStringToTimeString() -> String {
        let dateFormatter = DateFormatter()

        let date = Date(timeIntervalSince1970: TimeInterval(Int(self) ?? 0))
        dateFormatter.dateStyle = .none

        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: date)
    }

    func toInt() -> Int {
        return Int(self) ?? 0
    }

    func toInt16() -> Int16 {
        return Int16(self) ?? 0
    }

    func toKiloInt32() -> Int32 {
        let number = self.replacingOccurrences(of: "K", with: "")
        return 1000 * (Int32(number) ?? 0)
    }

    func toInt32() -> Int32 {
        return Int32(self) ?? 0
    }

    func fromBase64() -> String? {
        guard let data = Data(base64Encoded: self) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func toBase64() -> String {
        return Data(self.utf8).base64EncodedString()
    }
}

extension View {

    public func textFieldAlert(
            isPresented: Binding<Bool>,
            title: String,
            message: String = "",
            text: String = "",
            placeholder: String = "",
            action: @escaping (String?) -> Void
    ) -> some View {
        self.modifier(TextFieldAlertModifier(isPresented: isPresented, title: title, message: message, text: text, placeholder: placeholder, action: action))
    }

}

public struct TextFieldAlertModifier: ViewModifier {

    @State private var alertController: UIAlertController?

    @Binding var isPresented: Bool

    let title: String
    let message: String
    let text: String
    let placeholder: String
    let action: (String?) -> Void

    public func body(content: Content) -> some View {
        content.onChange(of: isPresented) { isPresented in
            if isPresented, alertController == nil {
                let alertController = makeAlertController()
                self.alertController = alertController
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                    return
                }
                scene.windows.first?.rootViewController?.present(alertController, animated: true)
            } else if !isPresented, let alertController = alertController {
                alertController.dismiss(animated: true)
                self.alertController = nil
            }
        }
    }

    private func makeAlertController() -> UIAlertController {
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addTextField {
            $0.placeholder = self.placeholder
            $0.text = self.text
        }
        controller.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.action(nil)
            shutdown()
        })
        controller.addAction(UIAlertAction(title: "DELETE", style: .destructive) { _ in
            self.action(controller.textFields?.first?.text)
            shutdown()
        })
        return controller
    }

    private func shutdown() {
        isPresented = false
        alertController = nil
    }

}
