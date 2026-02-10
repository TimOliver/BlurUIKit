//
//  SwiftUIExampleView.swift
//  BlurUIKitExample
//
//  Created by Tim Oliver on 10/2/2026.
//

import SwiftUI

struct SwiftUIExampleView: View {

    private let atlasImageSize = CGSize(width: 0.499, height: 0.249)

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(0..<8, id: \.self) { index in
                        atlasImage(index: index, width: geometry.size.width - 32)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, geometry.safeAreaInsets.top + 8)
                .padding(.bottom, 16)
            }
            .ignoresSafeArea(edges: .top)
            .overlay(alignment: .top) {
                VariableBlur()
                    .frame(height: geometry.safeAreaInsets.top)
                    .ignoresSafeArea(edges: .top)
            }
        }
    }

    @ViewBuilder
    private func atlasImage(index: Int, width: CGFloat) -> some View {
        let height = width / 1.777
        let fullWidth = width / atlasImageSize.width
        let fullHeight = height / atlasImageSize.height
        let originX = CGFloat(index % 2) * 0.5 * fullWidth
        let originY = CGFloat(index / 2) * 0.25 * fullHeight

        Image("AppleParkAtlas")
            .resizable()
            .frame(width: fullWidth, height: fullHeight)
            .offset(x: -originX, y: -originY)
            .frame(width: width, height: height, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: width * 0.1, style: .continuous))
    }
}

#Preview {
    SwiftUIExampleView()
}
