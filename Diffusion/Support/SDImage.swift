//
//  SDImage.swift
//  Diffusion
//
//  Created by Fahim Farook on 18/12/2022.
//

import Foundation
import CoreGraphics
import UniformTypeIdentifiers
//import CoreGraphics
//import ImageIO
#if os(macOS)
import AppKit
#endif

struct SDImage {
	var image: CGImage?
	var prompt = ""
	var negPrompt = ""
	var model = ""
	var scheduler = ""
	var seed = -1
	var numSteps = 25
	var guidance = 7.5
	var imageIndex = 0
	
	// Save image with metadata
	func save() {
		guard let img = image else {
			NSLog("*** Image was not valid!")
			return
		}
#if os(macOS)
		let panel = NSSavePanel()
		panel.allowedContentTypes = [.jpeg]
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
		let meta = ["Author": meta(), "Title": title(), "Seed": "\(seed)"]
		NSLog("Saving with meta: \(meta)")
		guard let data = CFDataCreateMutable(nil, 0) else { return }
		guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return }
		CGImageDestinationAddImage(destination, img, meta as CFDictionary)
		guard CGImageDestinationFinalize(destination) else { return }
		// Save image that now has metadata
		do {
			try (data as Data).write(to: url)
		} catch {
			NSLog("*** Error saving image file: \(error)")
		}
#endif
	}
	
	private func meta() -> String {
		return title() + " Seed: \(seed), Model: \(model), Scheduler: \(scheduler), Seed: \(seed), Steps: \(numSteps), Guidance: \(guidance), Index: \(imageIndex)"
	}
	
	private func title() -> String {
		return "Prompt: \(prompt) + Negative: \(negPrompt)"
	}
}
