//
//  ErrorPopover.swift
//  Diffusion
//
//  Created by Fahim Farook on 17/12/2022.
//

import SwiftUI

struct ErrorBanner: View {
	var errorMessage: String

	var body: some View {
		Text(errorMessage)
			.frame(maxWidth: .infinity)
			.font(.headline)
			.padding(8)
			.foregroundColor(.red)
			.background(Color.white)
			.cornerRadius(8)
			.shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
	}
}

struct ErrorBanner_Previews: PreviewProvider {
    static var previews: some View {
        ErrorBanner(errorMessage: "This is an error!")
    }
}
