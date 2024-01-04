//
//  PreviewView.swift
//  Diffusion
//
//  Created by Fahim Farook on 15/12/2022.
//

import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct PreviewView: View {
	var image: Binding<SDImage?>
		
	var body: some View {
		if let sdi = image.wrappedValue, let img = sdi.image {
			let imageView = Image(img, scale: 1, label: Text("generated"))
			return AnyView(
				VStack {
				imageView.resizable().clipShape(RoundedRectangle(cornerRadius: 20))
					HStack {
						Text("Seed: \(sdi.seedStr)")
							.help("The seed for this image. Tap to copy to clipboard.")
							.onTapGesture {
#if os(macOS)
								let pb = NSPasteboard.general
								pb.declareTypes([.string], owner: nil)
								pb.setString(sdi.seedStr, forType: .string)
#else
								UIPasteboard.general.setValue(sdi.seedStr, forPasteboardType: UTType.plainText.identifier)
#endif
							}
						Spacer()
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
