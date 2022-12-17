//
//  AppState.swift
//  Diffusion
//
//  Created by Fahim Farook on 17/12/2022.
//

import Foundation
import CoreML
import Combine

class AppState: ObservableObject {
	static let shared = AppState()
	
	@Published var pipeline: Pipeline? = nil
	@Published var modelDir = URL(string: "http://google.com")!
	@Published var models = [String]()

	private(set) lazy var statePublisher: CurrentValueSubject<MainViewState, Never> = CurrentValueSubject(state)

	var state: MainViewState = .loading {
		didSet {
			statePublisher.value = state
		}
	}

	private init() {
		NSLog("*** AppState initialized")
		// Does the model path exist?
		guard var dir = docDir else {
			state = .error("Could not get user document directory")
			return
		}
		dir.append(path: "Diffusion/models", directoryHint: .isDirectory)
		let fm = FileManager.default
		if !fm.fileExists(atPath: dir.path) {
			NSLog("Models directory does not exist at: \(dir.path). Creating ...")
			try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
		}
		modelDir = dir
		// Find models in model dir
		do {
			let subs = try dir.subDirectories()
			subs.forEach {sub in
				models.append(sub.lastPathComponent)
			}
		} catch {
			state = .error("Could not get sub-folders under model directory: \(dir.path)")
			return
		}
		// Use first model for now
		guard let model = models.first else {
			state = .error("No models found under model directory: \(dir.path)")
			return
		}
		Task {
			do {
				try await load(model: model)
			} catch {
				NSLog("Error loading model: \(error)")
				DispatchQueue.main.async {
					self.state = .error(error.localizedDescription)
				}
			}
		}
	}
	
	func load(model: String) async throws {
		NSLog("*** Loading model: \(model)")
		let dir = modelDir.appending(component: model, directoryHint: .isDirectory)
		let fm = FileManager.default
		if !fm.fileExists(atPath: dir.path) {
			let msg = "Model directory: \(model) does not exist at: \(dir.path). Cannot proceed."
			NSLog(msg)
			state = .error(msg)
			return
		}
		let beginDate = Date()
		let configuration = MLModelConfiguration()
		// .all works for v1.4, but not for v1.5
		configuration.computeUnits = .cpuAndGPU
		// TODO: measure performance on different devices
		let pipeline = try StableDiffusionPipeline(resourcesAt: dir, configuration: configuration, disableSafety: true)
		NSLog("Pipeline loaded in \(Date().timeIntervalSince(beginDate))")
		DispatchQueue.main.async {
			self.pipeline = Pipeline(pipeline)
			self.state = .ready("Ready")
		}
	}
}
