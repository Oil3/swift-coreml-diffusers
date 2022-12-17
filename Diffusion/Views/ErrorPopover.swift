//
//  ErrorPopover.swift
//  Diffusion
//
//  Created by Fahim Farook on 17/12/2022.
//

import SwiftUI

struct ErrorPopover: View {
	var errorMessage: String

	var body: some View {
		Text(errorMessage)
			.font(.headline)
			.padding()
			.foregroundColor(.red)
			.background(Color.white)
			.cornerRadius(8)
			.shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
	}
}

struct ErrorPopover_Previews: PreviewProvider {
    static var previews: some View {
        ErrorPopover(errorMessage: "This is an error!")
    }
}
