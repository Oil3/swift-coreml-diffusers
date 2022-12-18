//
//  PreviewView.swift
//  Diffusion
//
//  Created by Fahim Farook on 15/12/2022.
//

import SwiftUI

struct PreviewView: View {
	var image: Binding<SDImage?>
		
	var body: some View {
		if let sdi = image.wrappedValue, let img = sdi.image {
			let imageView = Image(img, scale: 1, label: Text("generated"))
			return AnyView(
				VStack {
				imageView.resizable().clipShape(RoundedRectangle(cornerRadius: 20))
					HStack {
						ShareLink(item: imageView, preview: SharePreview(sdi.prompt, image: imageView))
						Button("Save", action: {
							sdi.save()
						})
					}
			})
		}
		return AnyView(Image("placeholder").resizable())
	}
}


struct PreviewView_Previews: PreviewProvider {
    static var previews: some View {
		var sd = SDImage()
		sd.prompt = "Test Prompt"
		return PreviewView(image: .constant(sd))
    }
}
