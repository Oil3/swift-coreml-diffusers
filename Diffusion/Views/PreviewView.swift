//
//  PreviewView.swift
//  Diffusion
//
//  Created by Fahim Farook on 15/12/2022.
//

import SwiftUI
import UniformTypeIdentifiers

struct PreviewView: View {
	var image: Binding<CGImage?>
	var state: Binding<GenerationState>
		
	var body: some View {
		switch state.wrappedValue {
		case .startup: return AnyView(Image("placeholder").resizable())
		case .running(let progress):
			guard let progress = progress, progress.stepCount > 0 else {
				// The first time it takes a little bit before generation starts
				return AnyView(ProgressView())
			}
			let step = Int(progress.step) + 1
			let fraction = Double(step) / Double(progress.stepCount)
			let label = "Step \(step) of \(progress.stepCount)"
			return AnyView(ProgressView(label, value: fraction, total: 1).padding())
			
		case .idle(let lastPrompt):
			guard let theImage = image.wrappedValue else {
				return AnyView(Image(systemName: "exclamationmark.triangle").resizable())
			}
							  
			let imageView = Image(theImage, scale: 1, label: Text("generated"))
			return AnyView(
				VStack {
				imageView.resizable().clipShape(RoundedRectangle(cornerRadius: 20))
					HStack {
						ShareLink(item: imageView, preview: SharePreview(lastPrompt, image: imageView))
						Button("Save", action: {
							saveImage(cgi: theImage)
						})
					}
			})
		}
	}
	
	private func saveImage(cgi: CGImage) {
		let panel = NSSavePanel()
		panel.allowedContentTypes = [.png, .jpeg]
		panel.canCreateDirectories = true
		panel.isExtensionHidden = false
		panel.title = "Save your image"
		panel.message = "Choose a folder and a name to store the image."
		panel.nameFieldLabel = "Image file name:"
		let resp = panel.runModal()
		if resp != .OK {
			return
		}
		guard let url = panel.url else { return }
		let ext = url.pathExtension.lowercased()
		if ext == "png" {
			guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
			CGImageDestinationAddImage(dest, cgi, nil)
			CGImageDestinationFinalize(dest)
		} else if ext == "jpg" {
			guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return }
			CGImageDestinationAddImage(dest, cgi, nil)
			CGImageDestinationFinalize(dest)
		} else {
			NSLog("*** Unknown image extension: \(ext)")
		}
	}
}


struct PreviewView_Previews: PreviewProvider {
    static var previews: some View {
		PreviewView(image: .constant(nil), state: .constant(.startup))
    }
}
