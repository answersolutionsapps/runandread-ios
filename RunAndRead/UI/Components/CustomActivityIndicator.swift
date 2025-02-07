//
//  CustomActivityIndicator.swift
//  TalkWise
//
//  Created by Serge Nes on 4/4/23.
//

import SwiftUI

struct CustomCardView: View {
    let contentView: AnyView
    var backgroundColor: Color = .surface
    var showShadow: Bool = true
    var hasMargin: Bool = true
    var cardMargins: CGFloat = UIConfig.normalSpace
    var topPadding: CGFloat = UIConfig.noSpace
    var bottomPadding: CGFloat = UIConfig.normalSpace
    
    var body: some View {
        HStack {
            VStack(spacing: UIConfig.normalSpace) {
                contentView
            }
            .if(hasMargin, transform: { view in
                view.padding(cardMargins)
            }
            )
        }
        .cornerRadius(UIConfig.normalRadius)
        .background(RoundedRectangle(cornerRadius: UIConfig.normalRadius)
        .fill(backgroundColor)
        .if(showShadow) { view in
                view.shadow(color: Color.black.opacity(0.2), radius: 10, x: 10, y: 10)
            }
        )
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
    }
}

struct ActivityIndicatorRepresentable: UIViewRepresentable {
    let style: UIActivityIndicatorView.Style
    
    func makeUIView(context: Context) -> UIActivityIndicatorView {
        UIActivityIndicatorView(style: style)
    }
    
    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
        uiView.color = UIColor(.primary)
        uiView.startAnimating()
    }
}


struct CustomActivityIndicator: View {
    var progressMessge = ""
    var body: some View {
        ZStack {
            Color.white
                .opacity(0.3)
            .edgesIgnoringSafeArea(.all)
            CustomCardView(
                contentView: AnyView(VStack(alignment: .center) {
                VStack(alignment: .center, spacing: UIConfig.largeSpace) {
                    ActivityIndicatorRepresentable(style: UIActivityIndicatorView.Style.large)
                    Text("Working..")
                    .font(.headline)
                }
                .frame(width: 72, height: 72)
            }.padding(UIConfig.largeSpace)))
        }
    }
}
struct CustomActivityIndicator_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ZStack{
                VStack (alignment: .center){
                    Text("Background Text")
                        .font(.title2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(.red)
                CustomActivityIndicator()
            }
        }
    }
}

struct CustomActivityIndicatorDark_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ZStack{
                VStack (alignment: .center){
                    Text("Background Text")
                        .font(.title2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(.red)
                CustomActivityIndicator()
            }
        }
        .colorScheme(.dark)
    }
}
